##
## Types generated from: https://kayahr.github.io/aseprite/aseprite.schema.json
##

import
  std/[macros, json, jsonutils, options, strformat, tables, sets, algorithm, strutils],
  vmath,
  triggerBox,
  util,
  anchor,
  import_playdate,
  sprite

export anchor

importPlaydateApi()

when LIVE_COMPILE:
  import playdate/util/initreqs

type
  AseFrame* = object
    duration*: int32
    filename*: string
    frame*: AseRectangle
    rotated*, trimmed*: bool
    sourceSize*: AseSize
    spriteSourceSize*: AseRectangle

  AseBlendMode* = enum
    normal
    darken
    multiply
    color_burn
    lighten
    screen
    color_dodge
    addition
    overlay
    soft_light
    hard_light
    difference
    exclusion
    subtract
    divide
    hsl_hue
    hsl_saturation
    hsl_color
    hsl_luminosity

  AseDirection* = enum
    forward
    reverse
    pingpong

  AseFormat* = enum
    RGBA8888
    I8

  AseFrameTag* = object
    name*: string
    `from`*: int32
    to*: int32
    direction*: AseDirection
    color*: string
    data*: string
    repeat*: string

  AseCel* = tuple[frame: int32, data: string]

  AseLayer* = object
    blendMode*: AseBlendMode
    color*: string
    data*: string
    group*: string
    name*: string
    opacity*: int32
    cels*: seq[AseCel]

  AseMeta* = object
    app*: string
    format*: AseFormat
    frameTags*: seq[AseFrameTag]
    image*: string
    layers*: seq[AseLayer]
    scale*: string
    size*: AseSize
    slices*: seq[AseSlice]
    version*: string

  AsePoint* = tuple[x, y: int32]

  AseRectangle* = tuple[h, w, x, y: int32]

  AseSize* = tuple[h, w: int32]

  AseSlice* = object
    color*: string
    data*: string
    keys*: seq[AseSliceKey]
    name*: string

  AseSliceKey* = object
    bounds*: AseRectangle
    frame*: int32

  SpriteSheet* = object
    frames*: seq[AseFrame]
    meta*: AseMeta

  KeyframeTable[K: enum] = Table[int32, K]

proc findTag*(sheet: SpriteSheet, name: string): Option[AseFrameTag] =
  let searchName = name.toLowerAscii
  for tag in sheet.meta.frameTags:
    if tag.name.toLowerAscii == searchName:
      return some(tag)

proc error(sheet: SpriteSheet, message: string) =
  let fullError = fmt"{message} for {sheet.meta.image}"
  log(fullError)
  raise newException(AssertionDefect, fullError)

proc eventFrames*(sheet: SpriteSheet, event: string): seq[int32] =
  ## Returns the frames at which an event occurs
  for layer in sheet.meta.layers:
    for cel in layer.cels:
      if cel.data == event:
        result.add(cel.frame)

iterator frames(sheet: SpriteSheet, tag: AseFrameTag): (int32, AseFrame) =
  for i in tag.`from` .. tag.to:
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
  ivec2(rect.x + (rect.w div 2), rect.y + (rect.h div 2))

proc center*(sliceKey: AseSliceKey): IVec2 =
  ## Returns the first AseSliceKey for a named slice or fails the compile
  sliceKey.bounds.center

proc readFrame(sheet: SpriteSheet, frame: SomeInteger): AseFrame {.discardable.} =
  if frame >= sheet.frames.len:
    sheet.error(fmt"Frame {frame} does not exist (Max frame is {sheet.frames.len - 1})")
    return
  return sheet.frames[frame.int32]

proc anchorLock(data: string, defaultAnchor: AnchorLock): AnchorLock =
  ## Given the 'userdata' field, extract the anchor lock information
  for item in data.splitWhitespace():
    if item.startsWith("Anchor"):
      return parseEnum[AnchorLock](item)
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
    ivec2(bounds.x, bounds.y) +
      slice.data.anchorLock(defaultAnchor).resolve(bounds.w, bounds.h)
  )

proc dimensions*(sheet: SpriteSheet): IVec2 =
  ## Returns the dimensions (width, height) of the sprite as IVec2 from the first frame's sourceSize
  if sheet.frames.len > 0:
    let sz = sheet.frames[0].sourceSize
    return ivec2(sz.w, sz.h)
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
  if tag.repeat == "":
    return InfiniteLoop.init().LoopMode
  else:
    return FiniteLoop.init(tag.repeat.parseInt().uint32).LoopMode

proc findKeyframes[K: enum](sheet: SpriteSheet, ignore: set[K]): KeyframeTable[K] =
  ## Searches the layers in a sprite sheet and creates a table of frame # to keyframe trigger
  var usedKeyframes: set[K]

  result = initTable[int32, K](ord(high(K)))

  for layer in sheet.meta.layers:
    for cel in layer.cels:
      try:
        let parsed = parseEnum[K](cel.data)
        usedKeyframes.incl(parsed)
        result[cel.frame] = parsed
      except:
        discard

  for key in K:
    if key notin usedKeyframes and key notin ignore:
      sheet.error(fmt"Keyframe '{key}' is not specified in sprite sheet")

proc strideToSpeed*(sheet: SpriteSheet, sliceName: string): float32 =
  ## Calculate the speed from the position of a slice
  let slice = sheet.slice(sliceName)
  if slice.keys.len < 2:
    sheet.error(fmt"Slice '{sliceName}' must have at least 2 keys")
    return

  let sorted = slice.keys.sortedByIt(it.bounds.x)
  let first = sorted[0]
  let last = sorted[^1]

  var totalMs = 0
  for frame in min(first.frame, last.frame) .. max(first.frame, last.frame):
    totalMs += sheet.frames[frame].duration

  result = (last.bounds.x - first.bounds.x).float32 / totalMs.float32 * 1000

proc loadAsepriteJson*(path: string): SpriteSheet {.compileTime.} =
  let json = parseJson(slurp(getProjectPath() & "/../" & path))
  result.fromJson(json, Joptions(allowMissingKeys: true, allowExtraKeys: true))

proc getTriggerBox*(sprite: SpriteSheet, sliceName: string, zIndex: enum): TriggerBox =
  ## Creates the attack trigger box from a sprite sheet
  let anchor = sprite.anchorOffset
  let slice = sprite.slice(sliceName).firstKey(sprite)
  let width = slice.bounds.w
  let height = slice.bounds.h
  let x = slice.bounds.x - anchor.x
  let y = slice.bounds.y - anchor.y
  return triggerBox(
    width = width, height = height, zIndex = zIndex, offset = ivec2(x.int32, y.int32)
  )

proc animationTime*(sheet: SpriteSheet, animation: enum): Option[int32] =
  ## Returns the length of all the frames in a specific tag
  let tag = sheet
    .findTag(removeSuffix($animation, "Anim"))
    .fallback(sheet.findTag($animation)).orElse:
      return none(int32)
  var duration: int32
  for _, frame in frames(sheet, tag):
    duration += frame.duration
  return some(duration)

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

    var frames = newSeqOfCap[Frame](tag.to - tag.`from` + 1)
    for frameId in (tag.`from` .. tag.to):
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
