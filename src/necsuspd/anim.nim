import
  import_playdate,
  necsus,
  vmath,
  time,
  util,
  std/[options, strformat, sequtils],
  fungus,
  drawable

export drawable

adtEnum(LoopMode):
  InfiniteLoop
  FiniteLoop:
    uint32

export LoopMode, InfiniteLoop, FiniteLoop

type
  Keyframe* {.byref.} = object
    keyframeValue: EnumValue
    sheet*: EnumValue
    entityId*: EntityId

  Frame* = object
    time*: float32
    cellId*: int32
    case isKeyframe*: bool
    of true:
      keyframeValue*: EnumValue
    of false:
      discard

  AnimationDefObj* = object
    sheet*: EnumValue
    frames*: seq[Frame]
    anchor*: Anchor
    loop*: LoopMode

  AnimationDef* = ref AnimationDefObj

  SheetTable*[S] = concept table
    table.sheet(S) is LCDBitmapTable

  Unpausable* {.accessory.} = object

  AnimObj* = object
    def*: AnimationDef
    frameCache: seq[LCDBitmap]
    frame: int32
    nextFrameTime: float32
    paused: bool
    loops: uint32

  Anim* = ref AnimObj

  AnimSheet* = ref object
    ## Wraps Drawable + Anim together for single-arg pool compatibility
    drawable*: Drawable
    anim*: Anim

proc offsetCellId*(frame: Frame, offset: int32): Frame =
  result = frame
  result.cellId = frame.cellId + offset

proc keyframe*(keyframe: Keyframe, typ: typedesc[enum]): Option[typ] =
  return keyframe.keyframeValue.getAs(typ)

proc toKeyframe*(frame: Frame, sheet: EnumValue, entityId: EntityId): Option[Keyframe] =
  if frame.isKeyframe:
    some(Keyframe(sheet: sheet, keyframeValue: frame.keyframeValue, entityId: entityId))
  else:
    none(Keyframe)

proc `$`*(def: AnimationDef | AnimationDefObj): string =
  fmt"AnimationDef({def.sheet}, frames={def.frames}, {def.anchor}, loop={def.loop})"

proc frame*(cellId: int32, time: float32): Frame =
  Frame(cellId: cellId, time: time, isKeyframe: false)

proc frame*(cellId: int32, time: float32, keyframe: enum): Frame =
  Frame(
    cellId: cellId, time: time, isKeyframe: true, keyframeValue: getEnumValue(keyframe)
  )

proc asLoopMode(loop: LoopMode | bool): LoopMode {.inline.} =
  when loop is bool:
    return
      if loop:
        InfiniteLoop.init().LoopMode
      else:
        FiniteLoop.init(1).LoopMode
  else:
    return loop

proc animation*[S: enum](
    sheet: S,
    frames: openarray[Frame],
    anchor: AnchorPosition,
    loop: LoopMode | bool = InfiniteLoop.init().LoopMode,
): AnimationDef =
  assert(frames.len > 0)
  AnimationDef(
    sheet: sheet.getEnumValue,
    frames: frames.toSeq,
    anchor: anchor.toAnchor,
    loop: loop.asLoopMode(),
  )

proc animation*[S: enum](
    sheet: S,
    timePerFrame: float32,
    frames: Slice[int32],
    anchor: AnchorPosition,
    loop: LoopMode | bool = InfiniteLoop.init().LoopMode,
): AnimationDef =
  var frameSeq: seq[Frame]
  for i in frames:
    frameSeq.add(frame(i.int32, timePerFrame))
  return animation(sheet, frameSeq, anchor, loop.asLoopMode)

proc modify*(
    def: AnimationDef, cellOffset: int32 = 0, anchor: Anchor = def.anchor
): AnimationDef =
  result = new(AnimationDef)
  result[] = def[]
  result.frames = def.frames.mapIt(it.offsetCellId(cellOffset))
  result.anchor = anchor

proc def*(a: Anim | ptr Anim): AnimationDef =
  a.def

proc frame*(a: Anim | ptr Anim): int32 =
  a.frame

proc loops*(a: Anim | ptr Anim): uint32 {.inline.} =
  a.loops

proc `paused=`*(a: ptr Anim | Anim, pause: bool) =
  a.paused = pause

proc paused*(a: ptr Anim | Anim): bool {.inline.} =
  a.paused

proc shouldLoop(a: Anim): bool {.inline.} =
  match a.def.loop:
  of InfiniteLoop:
    return true
  of FiniteLoop as count:
    return a.loops + 1 < count

proc change*(
    anim: ptr Anim | Anim, drawable: Drawable | ptr Drawable, def: AnimationDef
) =
  assert(anim.def.sheet == def.sheet)
  anim.def = def
  anim.frame = 0
  anim.nextFrameTime = 0
  drawable.anchorOffset = drawable.lcdSprite.offsetFix(def.anchor.toAnchor)
  anim.loops = 0

proc softChange*(
    anim: ptr Anim | Anim, drawable: Drawable | ptr Drawable, def: AnimationDef
) =
  assert(anim.def.sheet == def.sheet)
  anim.def = def
  anim.frame = anim.frame.clamp(0'i32, def.frames.len.int32 - 1)
  drawable.anchorOffset = drawable.lcdSprite.offsetFix(def.anchor.toAnchor)
  anim.loops = 0

proc reset*(anim: Anim, drawable: Drawable) =
  anim.frame = 0
  anim.nextFrameTime = 0.0
  anim.paused = false
  anim.loops = 0
  drawable.offset = ivec2(0, 0)
  drawable.anchorOffset = ivec2(0, 0)
  drawable.visible = true

proc resetPooledValue*(anim: Anim) =
  anim.frame = 0
  anim.nextFrameTime = 0.0
  anim.paused = false
  anim.loops = 0

proc restorePooledValue*(anim: Anim, drawable: Drawable) =
  change(anim, drawable, anim.def)

proc `$`*(a: ptr Anim): string =
  fmt"Anim({a.def}, frame={a.frame}, nextFrameAt={a.nextFrameTime}, paused={a.paused})"

proc newAnim*(frames: seq[LCDBitmap], def: AnimationDef, drawable: Drawable): Anim =
  when compileOption("assertions"):
    for f in frames:
      assert(not f.isNil)
  result = Anim(def: def, frameCache: frames)
  change(result, drawable, def)

proc extract[T](sysvar: SharedOrT[T]): T =
  return when sysvar is T: sysvar else: sysvar.getOrRaise

proc newSheet*(
    frames: seq[LCDBitmap],
    def: AnimationDef,
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): (Drawable, Anim) =
  when compileOption("assertions"):
    for f in frames:
      assert(not f.isNil)
  let d = newBitmapDrawable(frames[0], zIndex, def.anchor.toAnchor, absolutePos)
  let a = newAnim(frames, def, d)
  return (d, a)

proc newSheet*[S: enum](
    assets: SharedOrT[SheetTable[S]],
    def: AnimationDef,
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): (Drawable, Anim) =
  let table = assets.extract.sheet(def.sheet.assertAs(S))
  let frameCount = table.getBitmapTableInfo.count
  var frames = newSeq[LCDBitmap](frameCount)
  for i in 0 ..< frameCount:
    frames[i] = table.getBitmap(i)
  newSheet(frames, def, zIndex, absolutePos)

proc newAnimSheet*(drawable: Drawable, anim: Anim): AnimSheet =
  AnimSheet(drawable: drawable, anim: anim)

proc newAnimSheet*[S: enum](
    assets: SharedOrT[SheetTable[S]],
    def: AnimationDef,
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): AnimSheet =
  let (d, a) = newSheet(assets, def, zIndex, absolutePos)
  AnimSheet(drawable: d, anim: a)

proc resetPooledValue*(s: AnimSheet) =
  s.drawable.resetPooledValue()
  s.anim.resetPooledValue()

proc restorePooledValue*(s: AnimSheet) =
  s.drawable.restorePooledValue()
  s.anim.restorePooledValue(s.drawable)

proc advanceDrawables*(
    time: GlobalGameTime,
    elements: FullQuery[(ptr Drawable, ptr Anim, Option[Unpausable])],
    events: Outbox[Keyframe],
) =
  let now = time.get.float32
  for eid, (drawable, parent, unpausable) in elements:
    let anim = parent[]
    if drawable.visible and (not anim.paused or unpausable.isSome) and
        anim.nextFrameTime <= now:
      if anim.nextFrameTime == 0:
        parent.nextFrameTime = now
      elif anim.frame == (anim.def.frames.len - 1):
        if anim.shouldLoop():
          parent.frame = 0
          parent.loops += 1
      else:
        parent.frame += 1

      let currentFrame: Frame = anim.def.frames[anim.frame]
      parent.nextFrameTime = now + currentFrame.time
      drawable.lcdSprite.setImage(
        anim.frameCache[currentFrame.cellId], kBitmapUnflipped
      )
      let kf = currentFrame.toKeyframe(anim.def.sheet, eid)
      if kf.isSome:
        events(kf.get)
