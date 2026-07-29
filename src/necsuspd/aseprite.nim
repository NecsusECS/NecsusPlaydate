##
## Types generated from: https://kayahr.github.io/aseprite/aseprite.schema.json
##
## The schema is a lightly modified copy of the upstream document. See
## `aseprite-schema.json` for what was changed and why.
##

import
  std/[macros, options, strformat, tables, sets, algorithm, strutils, streams],
  json_schema_import,
  vmath,
  triggerBox,
  util,
  anchor,
  import_playdate,
  anim

export anchor

importJsonSchema("./aseprite-schema.json", "Ase")

type
  SpriteSheet* = AseSpriteSheet

  KeyframeTable[K: enum] = Table[int32, K]

template userData(field: Option[string]): string =
  ## Aseprite omits the custom data fields entirely when they are empty
  field.get("")

proc findTag*(sheet: SpriteSheet, name: string): Option[AseFrameTag] =
  let searchName = name.toLowerAscii
  for tag in sheet.meta.frameTags:
    if tag.name.toLowerAscii == searchName:
      return some(tag)

template error(sheet: SpriteSheet, message: string) =
  block:
    let fullError = message & " for " & sheet.meta.image
    when nimvm:
      error(fullError)
    else:
      log(fullError)
    raise newException(AssertionDefect, fullError)

proc eventFrames*(sheet: SpriteSheet, event: string): seq[int32] =
  ## Returns the frames at which an event occurs
  for layer in sheet.meta.layers:
    for cel in layer.cels:
      if cel.data.userData == event:
        result.add(cel.frame.int32)

iterator frames(sheet: SpriteSheet, tag: AseFrameTag): (int32, AseFrame) =
  for i in tag.`from`.int32 .. tag.to.int32:
    yield (i, sheet.frames[i])

proc timeUntil*(sheet: SpriteSheet, tagName: string, event: string): float32 =
  ## Returns the total time elapsed until the given event is reached
  let tag = sheet.findTag(tagName).orElse:
    sheet.error(fmt"Tag {tagName} does not exist")
    return

  let eventFrames = sheet.eventFrames(event)

  var accum: float32
  for i, frame in frames(sheet, tag):
    accum += frame.duration.float32 / 1000
    if i in eventFrames:
      return accum

  sheet.error(fmt"Could not find event {event} in tag {tagName}")

proc findSlice*(sheet: SpriteSheet, name: string): Option[AseSlice] =
  ## Returns the first AseSliceKey for a named slice or fails the compile
  for slice in sheet.meta.slices:
    if slice.name == name:
      return some(slice)

proc slice*(sheet: SpriteSheet, name: string): AseSlice =
  ## Returns the first AseSliceKey for a named slice or fails the compile
  let found = sheet.findSlice(name)
  if found.isSome:
    return found.get
  else:
    sheet.error(fmt"Could not find '{name}' slice")

proc firstKey*(slice: AseSlice, sheet: SpriteSheet): AseSliceKey =
  ## Returns the first AseSliceKey for a named slice or fails the compile
  if slice.keys.len == 0:
    sheet.error(
      fmt"Slice keys for '{slice.name}' must not be empty (has {slice.keys.len})"
    )
    return
  return slice.keys[0]

const HIT_BOX_SLICE_NAME = "HitBox"

proc hitBox*(sheet: SpriteSheet): AseRectangle =
  ## Returns the dimensions of the hitbox
  sheet.slice(HIT_BOX_SLICE_NAME).firstKey(sheet).bounds

proc center*(rect: AseRectangle): IVec2 =
  ## Returns the dimensions of the hitbox
  ivec2((rect.x + (rect.w div 2)).int32, (rect.y + (rect.h div 2)).int32)

proc readFrame(sheet: SpriteSheet, frame: SomeInteger): AseFrame {.discardable.} =
  if frame >= sheet.frames.len:
    sheet.error(fmt"Frame {frame} does not exist (Max frame is {sheet.frames.len - 1})")
    return
  return sheet.frames[frame.int32]

proc anchorLock(data: string, defaultAnchor: AnchorLock): AnchorLock =
  ## Given the 'userdata' field, extract the anchor lock information
  for item in data.splitWhitespace():
    if item.startsWith("Anchor"):
      return strToEnum[AnchorLock](item)
  return defaultAnchor

proc slicePointFromTopLeft*(
    sheet: SpriteSheet,
    sliceName: string,
    defaultAnchor: AnchorLock = AnchorBottomMiddle,
): Option[IVec2] =
  ## Returns the point for a slice anchored to the top left of the sprite
  let slice = sheet.findSlice(sliceName).orElse:
    return

  let bounds = slice.firstKey(sheet).bounds
  return some(
    ivec2(bounds.x.int32, bounds.y.int32) +
      slice.data.userData.anchorLock(defaultAnchor).resolve(bounds.w.int32, bounds.h.int32)
  )

proc dimensions*(sheet: SpriteSheet): IVec2 =
  ## Returns the dimensions (width, height) of the sprite as IVec2 from the first frame's sourceSize
  if sheet.frames.len > 0:
    let sz = sheet.frames[0].sourceSize
    return ivec2(sz.w.int32, sz.h.int32)
  else:
    sheet.error("SpriteSheet has no frames to determine dimensions")

proc slicePointFromCenter*(
    sheet: SpriteSheet,
    sliceName: string,
    defaultAnchor: AnchorLock = AnchorBottomMiddle,
): Option[IVec2] =
  ## Returns the point for a slice relative to the center of the sprite
  return sheet.slicePointFromTopLeft(sliceName, defaultAnchor).mapIt:
    let dims = sheet.dimensions()
    it - ivec2(dims.x div 2, dims.y div 2)

proc anchorOffset*(sheet: SpriteSheet): IVec2 =
  ## The offset of the anchor point relative to the top left of a sprite
  return sheet
    .slicePointFromTopLeft("Anchor", AnchorBottomMiddle)
    .fallback(sheet.slicePointFromTopLeft("HitBox", AnchorBottomMiddle))
    .orElse(sheet.dimensions().div(2))

proc spriteAnchor*(sheet: SpriteSheet): Anchor =
  ## The anchor definition to use when creating a sprite from this sheet
  return (AnchorMiddle, sheet.dimensions().div(2) - sheet.anchorOffset)

proc sliceKeyAsOffset*(sheet: SpriteSheet, key: string): IVec2 =
  ## Returns the offset of the center of a slice key relative to the anchor point of a sprite
  let sliceKey = sheet.slice(key).firstKey(sheet).bounds.center
  let anchor = sheet.anchorOffset
  return sliceKey - anchor

proc loop(tag: AseFrameTag): LoopMode =
  let repeat = tag.repeat.userData
  if repeat == "":
    return InfiniteLoop.init().LoopMode
  else:
    return FiniteLoop.init(repeat.parseInt().uint32).LoopMode

proc findKeyframes[K: enum](sheet: SpriteSheet, ignore: set[K]): KeyframeTable[K] =
  ## Searches the layers in a sprite sheet and creates a table of frame # to keyframe trigger
  var usedKeyframes: set[K]

  result = initTable[int32, K](ord(high(K)))

  for layer in sheet.meta.layers:
    for cel in layer.cels:
      try:
        let parsed = strToEnum[K](cel.data.userData)
        usedKeyframes.incl(parsed)
        result[cel.frame.int32] = parsed
      except:
        discard

  for key in K:
    if key notin usedKeyframes and key notin ignore:
      sheet.error(fmt"Keyframe '{key}' is not specified in sprite sheet")

proc totalDurationMs(sheet: SpriteSheet, frameRange: Slice[int32]): float32 =
  var totalMs: BiggestInt
  for frame in frameRange:
    totalMs += sheet.frames[frame].duration
  return totalMs.float32

proc strideToSpeed*(sheet: SpriteSheet, sliceName: string): float32 =
  ## Calculate the speed from the position of a slice.
  ## If the slice has only one key, the distance is derived from max(width, height)
  ## of the slice bounds, and the user data field is parsed as the frame count for timing.
  let slice = sheet.slice(sliceName)
  if slice.keys.len == 0:
    sheet.error(fmt"Slice '{sliceName}' must have at least 1 key")
    return

  if slice.keys.len == 1:
    let key = slice.keys[0]
    let distance = max(key.bounds.w, key.bounds.h).float32
    let lastFrame = key.frame.int32 + slice.data.userData.parseInt().int32
    let totalMs = sheet.totalDurationMs(key.frame.int32 ..< lastFrame)
    return distance / totalMs * 1000
  else:
    let sorted = slice.keys.sortedByIt(it.bounds.x)
    let first = sorted[0]
    let last = sorted[^1]
    let firstCoord = vec2(first.bounds.x.float32, first.bounds.y.float32)
    let lastCoord = vec2(last.bounds.x.float32, last.bounds.y.float32)
    let distance = firstCoord.dist(lastCoord) + 1
    let totalMs = sheet.totalDurationMs(
      min(first.frame, last.frame).int32 .. max(first.frame, last.frame).int32
    )
    return distance / totalMs * 1000

proc loadAsepriteJson*(path: string): SpriteSheet {.compileTime.} =
  let fullPath = getProjectPath() & "/../" & path
  SpriteSheet.fromStream(newStringStream(slurp(fullPath)), fullPath)

proc getTriggerBox*(sprite: SpriteSheet, sliceName: string, zIndex: enum): TriggerBox =
  ## Creates the attack trigger box from a sprite sheet
  let anchor = sprite.anchorOffset
  let slice = sprite.slice(sliceName).firstKey(sprite)
  let width = slice.bounds.w.int32
  let height = slice.bounds.h.int32
  let x = slice.bounds.x.int32 - anchor.x
  let y = slice.bounds.y.int32 - anchor.y
  return triggerBox(
    width = width, height = height, zIndex = zIndex, offset = ivec2(x.int32, y.int32)
  )

proc animationTime*(sheet: SpriteSheet, animation: enum): Option[int32] =
  ## Returns the length of all the frames in a specific tag
  let tag = sheet
    .findTag(removeSuffix($animation, "Anim"))
    .fallback(sheet.findTag($animation)).orElse:
      return none(int32)
  var duration: BiggestInt
  for _, frame in frames(sheet, tag):
    duration += frame.duration
  return some(duration.int32)

when LIVE_COMPILE:
  proc createFrameDef(
      sheet: SpriteSheet, keyframes: KeyframeTable[enum], frameId: int32
  ): Frame =
    let duration = sheet.frames[frameId].duration.float32 / 1000'f32
    if frameId in keyframes:
      return frame(frameId, duration, keyframes[frameId])
    else:
      return frame(frameId, duration)

proc asAnimationDef[S: enum](
    sheet: SpriteSheet, tag: AseFrameTag, sheetId: S, keyframes: KeyframeTable[enum]
): AnimationDef =
  ## Create an animation based on a aseprite tag
  when LIVE_COMPILE:
    # Read the frames to ensure they exist
    discard sheet.readFrame(tag.`from`)
    discard sheet.readFrame(tag.to)

    var frames = newSeqOfCap[Frame](tag.to.int - tag.`from`.int + 1)
    for frameId in (tag.`from`.int32 .. tag.to.int32):
      frames.add(createFrameDef(sheet, keyframes, frameId))

    return animation(sheetId, frames, sheet.spriteAnchor, tag.loop())

proc animationTable*[A, K: enum](
    sheet: SpriteSheet, sheetId: enum, ignore: set[A] = {}, ignoreKeyframes: set[K] = {}
): array[A, AnimationDef] =
  ## Creates a table of animation data based on a sprite sheet
  when LIVE_COMPILE:
    let keyframeTable = findKeyframes[K](sheet, ignoreKeyframes)
    for animation in A:
      let tag = sheet.findTag(removeSuffix($animation, "Anim")).fallback(
          sheet.findTag($animation)
        )

      let entry =
        if tag.isSome:
          sheet.asAnimationDef(tag.get, sheetId, keyframeTable)
        else:
          if animation notin ignore:
            sheet.error(fmt"FrameTag {animation} is missing")
          nil

      result[animation] = entry

type NoKeyframes = enum
  DummyKeyframe

proc basicAnimationTable*[A: enum](
    sheet: SpriteSheet, sheetId: enum, ignore: set[A] = {}
): array[A, AnimationDef] =
  ## Creates a table of animation data based on a sprite sheet
  when LIVE_COMPILE:
    result = animationTable[A, NoKeyframes](sheet, sheetId, ignore, {DummyKeyframe})

proc stateAnimationTable*[A, B: enum](
    sheet: SpriteSheet, sheetId: enum, prefix = "", suffix = ""
): array[A, array[B, AnimationDef]] =
  ## Builds a 2D animation table keyed by category (A) and state (B).
  ## Tags are located by stripping prefix/suffix from the A variant name.
  ## B's ordinal value is the frame offset within the tag (0 = first state, 1 = second, …).
  when LIVE_COMPILE:
    for category in A:
      let tagName = ($category).removePrefix(prefix).removeSuffix(suffix)
      let tag = sheet.findTag(tagName).orElse:
        sheet.error(fmt"Missing tag '{tagName}'")
        return
      for state in B:
        let frameId = tag.`from`.int32 + ord(state).int32
        let dur = sheet.frames[frameId].duration.float32 / 1000'f32
        result[category][state] =
          animation(sheetId, @[frame(frameId, dur)], sheet.spriteAnchor, tag.loop())
