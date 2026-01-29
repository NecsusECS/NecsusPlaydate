import
  import_playdate,
  positioned,
  necsus,
  vmath,
  time,
  viewport,
  util,
  vec_tools,
  anchor,
  types,
  std/[options, strformat, macros, sequtils],
  fungus

importPlaydateApi()

adtEnum(LoopMode):
  InfiniteLoop
  FiniteLoop:
    uint32

export anchor, LoopMode, InfiniteLoop, FiniteLoop

type
  ZIndexValue = SomeInteger or enum ## A value that can be used as a zindex

  AssetTable*[A] =
    concept table
        table.asset(A) is LCDBitmap

  SheetTable*[S] =
    concept table
        table.sheet(S) is LCDBitmapTable

  Keyframe* {.byref.} = object
    ## An event that is triggered when an animation reaches a specific frame
    keyframeValue: EnumValue
    sheet*: EnumValue
    entityId*: EntityId

  Frame* = object
    time: float32
    cellId: int32
    case isKeyframe: bool
    of true:
      keyframeValue: EnumValue
    of false:
      discard

  AnimationDefObj = object ## A specific animation within a sprite sheet
    sheet: EnumValue
    frames: seq[Frame]
    anchor: Anchor
    loop: LoopMode

  AnimationDef* = ref AnimationDefObj ## A specific animation within a sprite sheet

  AnimationObj = object
    def: AnimationDef
    sprite*: LCDSprite
    table: LCDBitmapTable
    frameCache: seq[LCDBitmap]
    frame: int32
    nextFrameTime: float32
    anchorOffset, manualOffset, lastPosition: IVec2
    absolutePos: bool
    paused: bool
    loops: uint32

  Animation* = ref AnimationObj

  Unpausable* {.accessory.} = object

  SpriteObj* = object
    image: LCDBitmap
    sprite: LCDSprite
    anchorOffset, manualOffset, lastPosition: IVec2
    absolutePos: bool
    link: Sprite

  Sprite* = ref SpriteObj

proc offsetCellId*(frame: Frame, offset: int32): Frame =
  ## Creates a copy of this frame with the cellId offset by a specific amount
  result = frame
  result.cellId = frame.cellId + offset

proc scale*(anchor: Anchor, factor: float32): Anchor =
  ## Scales an anchor by a given amount
  result = anchor
  result.offset = (anchor.offset.vec2 * factor).toIVec2

proc modify*(
    def: AnimationDef, cellOffset: int32 = 0, anchor: Anchor = def.anchor
): AnimationDef =
  ## Creates a copy of an AnimationDef with all the cellIds offset by a given amount
  result = new(AnimationDef)
  result[] = def[]
  result.frames = def.frames.mapIt(it.offsetCellId(cellOffset))
  result.anchor = anchor

proc keyframe*(keyframe: Keyframe, typ: typedesc[enum]): Option[typ] =
  ## Extracts the keyframe as an enum
  return keyframe.keyframeValue.getAs(typ)

proc offsetFix(sprite: LCDSprite, anchor: Anchor): IVec2 =
  ## Returns the offset necessary to align a position to the 0, 0 position of a sprite
  return
    anchor.offset +
    anchor.lock.resolveFromCenter(
      sprite.getImage.getSize.width.int32, sprite.getImage.getSize.height.int32
    )

proc `=copy`(x: var SpriteObj, y: SpriteObj) {.error.}

proc `=sink`(x: var SpriteObj, y: SpriteObj) {.error.}

proc `=destroy`(sprite: SpriteObj) {.warning[Effect]: off.} =
  if sprite.sprite != nil:
    playdate.sprite.removeSprites(@[sprite.sprite])
    `=destroy`(sprite.sprite)

proc `=copy`(x: var AnimationObj, y: AnimationObj) {.error.}

proc `=destroy`(sprite: AnimationObj) =
  if sprite.sprite != nil:
    playdate.sprite.removeSprites(@[sprite.sprite])

proc width*(sprite: Sprite | Animation): auto =
  sprite.sprite.getImage.getSize.width

proc height*(sprite: Sprite | Animation): auto =
  sprite.sprite.getImage.getSize.height

proc def*(animation: Animation): AnimationDef =
  animation.def

proc frame*(cellId: int32, time: float32): Frame =
  ## Build a frame
  Frame(cellId: cellId, time: time, isKeyframe: false)

proc frame*(cellId: int32, time: float32, keyframe: enum): Frame =
  ## Build a frame with a keyframe
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

proc `$`*(def: AnimationDef | AnimationDefObj): string =
  fmt"AnimationDef({def.sheet}, frames={def.frames}, {def.anchor}, loop={def.loop})"

proc `$`*(anim: ptr Animation): string =
  fmt"Animation({anim.def}, frame={anim.frame}, nextFrameAt={anim.nextFrameTime}, " &
    fmt"absolutePos={anim.absolutePos}, paused={anim.paused})"

proc newBitmapSprite*(
    img: LCDBitmap,
    zIndex: ZIndexValue,
    anchor: AnchorPosition,
    absolutePos: bool = false,
): Sprite =
  var sprite = playdate.sprite.newSprite()
  sprite.setImage(img, kBitmapUnflipped)
  sprite.zIndex = ord(zIndex).int16
  sprite.setOpaque(false)
  sprite.add()

  return Sprite(
    sprite: sprite,
    anchorOffset: sprite.offsetFix(anchor.toAnchor),
    absolutePos: absolutePos,
    lastPosition: ivec2(int32.high, int32.high),
  )

proc newAssetSprite*[A](
    assets: SharedOrT[AssetTable[A]],
    asset: A,
    anchor: AnchorPosition,
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): Sprite =
  newBitmapSprite(
    assets.unwrap.asset(asset).copy,
    anchor = anchor,
    zIndex = zIndex,
    absolutePos = absolutePos,
  )

proc newBlankSprite*(
    width, height: int32,
    zIndex: ZIndexValue,
    anchor: AnchorPosition,
    color: LCDColor = kColorWhite,
    absolutePos: bool = false,
): Sprite =
  return newBitmapSprite(
    playdate.graphics.newBitmap(width, height, color), zIndex, anchor, absolutePos
  )

template newBlankSprite*(
    width, height: int,
    zIndex: ZIndexValue,
    anchor: AnchorPosition,
    color: LCDColor = kColorWhite,
    absolutePos: bool = false,
): Sprite =
  newBlankSprite(width.int32, height.int32, zIndex, anchor, color, absolutePos)

iterator linked*(sprite: Animation): Animation =
  yield sprite

iterator linked*(sprite: Sprite): Sprite {.inline.} =
  var current = sprite
  while current != nil:
    yield current
    current = current.link

proc link*(sprite: Sprite): Sprite {.inline.} =
  sprite.link

proc `link=`*(parent, child: Sprite) {.inline.} =
  assert(parent.link == nil)
  assert(child != nil)
  when compileOption("assertions"):
    for sprite in child.linked:
      assert(addr(sprite) != addr(parent))
  parent.link = child

proc offset*(sprite: Sprite | Animation): IVec2 {.inline.} =
  sprite.manualOffset

proc `offset=`*(sprite: Sprite | Animation, offset: IVec2) {.inline.} =
  sprite.manualOffset = offset

proc softChange*(animation: ptr Animation | Animation, def: AnimationDef) =
  ## Changes the animation currently runnig while trying not to modify the frame number
  assert(animation.def.sheet == def.sheet)
  animation.def = def
  animation.frame = animation.frame.clamp(0'i32, def.frames.len.int32 - 1)
  animation.anchorOffset = animation.sprite.offsetFix(def.anchor.toAnchor)
  animation.loops = 0

proc change*(animation: ptr Animation | Animation, def: AnimationDef) =
  ## Changes the animation currently runnig for a sprite
  assert(animation.def.sheet == def.sheet)
  animation.def = def
  animation.frame = 0
  animation.nextFrameTime = 0
  animation.anchorOffset = animation.sprite.offsetFix(def.anchor.toAnchor)
  animation.loops = 0

proc `paused=`*(animation: ptr Animation, pause: bool) =
  ## Pauses this animation
  animation.paused = pause

proc `[]`(anim: Animation, frame: int32): LCDBitmap =
  ## Return a frame from an animation
  assert(anim.frameCache.len > frame)
  assert(not anim.frameCache[frame].isNil)
  return anim.frameCache[frame]

proc newSheet*(
    frames: seq[LCDBitmap],
    def: AnimationDef,
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): Animation =
  when compileOption("assertions"):
    for frame in frames:
      assert(not frame.isNil)

  result = Animation(
    def: def,
    sprite: playdate.sprite.newSprite(),
    absolutePos: absolutePos,
    frameCache: frames.toSeq,
    lastPosition: ivec2(int32.high, int32.high)
  )

  result.sprite.setImage(result[result.frame], kBitmapUnflipped)
  `zIndex=`(result.sprite, ord(zIndex).int16)
  result.sprite.add()
  change(addr result, def)

proc extract[T](sysvar: SharedOrT[T]): T =
  return when sysvar is T: sysvar else: sysvar.getOrRaise

proc newSheet*[S: enum](
    assets: SharedOrT[SheetTable[S]],
    def: AnimationDef,
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): Animation =
  let table = assets.extract.sheet(def.sheet.assertAs(S))
  let frameCount = table.getBitmapTableInfo.count
  var frames = newSeq[LCDBitmap](frameCount)
  for i in 0 ..< frameCount:
    frames[i] = table.getBitmap(i)
  newSheet(frames, def, zIndex, absolutePos)

template move(movable, viewport) =
  let viewportOffset = ivec2(viewport.x, viewport.y)
  let noViewport = ivec2(0, 0)
  for (parent, pos) in movable:
    for sprite in parent[].linked:
      let viewportOffset = if sprite.absolutePos: noViewport else: viewportOffset
      let absolutePos =
        pos.toIVec2 + sprite.anchorOffset + sprite.manualOffset - viewportOffset
      if absolutePos != sprite.lastPosition:
        sprite.sprite.moveTo(absolutePos.x.cfloat, absolutePos.y.cfloat)
        sprite.lastPosition = absolutePos

proc moveSprites*(
    sprites: Query[(ptr Sprite, Positioned)],
    animated: Query[(ptr Animation, Positioned)],
    viewport: Shared[ViewPort],
    viewportTweaks: Query[(ViewPortTweak,)],
) =
  ## Builds a system that moves sprites so they match their position
  var vp = viewport.get()
  for (tweak) in viewportTweaks:
    vp += tweak

  move(sprites, vp)
  move(animated, vp)

proc shouldLoop(anim: Animation): bool {.inline.} =
  match anim.def.loop:
  of InfiniteLoop:
    return true
  of FiniteLoop as count:
    return anim.loops + 1 < count

proc advanceSprites*(
    time: GlobalGameTime,
    elements: FullQuery[(ptr Animation, Option[Unpausable])],
    events: Outbox[Keyframe],
) =
  ## Moves ahead any sprite animations that need to be updated
  let now = time.get.float32
  for eid, (parent, unpausable) in elements:
    for anim in parent[].linked:
      if anim.sprite.visible and (not anim.paused or unpausable.isSome) and
          anim.nextFrameTime <= now:
        if anim.nextFrameTime == 0:
          anim.nextFrameTime = now
        elif anim.frame == (anim.def.frames.len - 1):
          if anim.shouldLoop():
            anim.frame = 0
            anim.loops += 1
        else:
          anim.frame += 1

        let frame: Frame = anim.def.frames[anim.frame]
        anim.nextFrameTime = now + frame.time
        anim.sprite.setImage(anim[frame.cellId], kBitmapUnflipped)
        if frame.isKeyframe:
          events(
            Keyframe(
              sheet: anim.def.sheet, keyframeValue: frame.keyframeValue, entityId: eid
            )
          )

proc getImage*(sprite: Sprite | ptr Sprite): var LCDBitmap =
  if sprite.image.isNil:
    sprite.image = sprite.sprite.getImage
  return sprite.image

proc getBitmapMask*(sprite: Sprite | ptr Sprite): LCDBitmap =
  return sprite.getImage.getBitmapMask

proc markDirty*(sprite: Sprite | ptr Sprite) {.inline.} =
  sprite.sprite.markDirty

proc `collideRect=`*(sprite: Sprite, rectangle: PDRect) {.inline.} =
  `collideRect=`(sprite.sprite, rectangle)

proc setDrawMode*(sprite: Sprite, mode: LCDBitmapDrawMode) =
  sprite.sprite.setDrawMode(mode)

proc setBitmapMask*(
    sprite: Sprite,
    img: LCDBitmap =
      playdate.graphics.newBitmap(sprite.width, sprite.height, kColorWhite),
) =
  discard sprite.getImage.setBitmapMask(img)

proc visible*(sprite: Sprite | Animation): bool {.inline.} =
  sprite.sprite.visible

proc `visible=`*(sprite: Sprite | Animation, visible: bool) {.inline.} =
  `visible=`(sprite.sprite, visible)

proc `zIndex`*(sprite: Sprite | Animation): int16 {.inline.} =
  sprite.sprite.zIndex

proc `zIndex=`*(sprite: Sprite | Animation, index: auto) {.inline.} =
  sprite.sprite.zIndex = index.int16

proc setImage*(sprite: Sprite, img: LCDBitmap) {.inline.} =
  sprite.sprite.setImage(img, kBitmapUnflipped)

when defined(simulator):
  var debugCallbacks: seq[proc(debug: LCDBitmap)]

proc debugDraw*(callback: proc(debug: LCDBitmap)) {.inline.} =
  ## Registers a callback to be called when the debug bitmap is available.
  when defined(simulator):
    debugCallbacks.add(callback)

proc drawSprites*() =
  ## draws all sprites
  playdate.sprite.drawSprites()

  if defined(showFPS):
    playdate.system.drawFPS(LCD_COLUMNS - 18, 4)

  when defined(simulator):
    var img = playdate.graphics.getDebugBitmap()
    if img != nil:
      for debug in debugCallbacks:
        debug(img)

proc remove*(sprite: Sprite | Animation) =
  sprite.sprite.remove()

proc add*(sprite: Sprite | Animation) =
  sprite.sprite.add()

proc `$`*(sprite: Sprite): string =
  {.cast(gcsafe).}:
    let isVisible = if sprite.sprite.visible: "visible" else: "hidden"
    return
      fmt"Sprite({sprite.sprite.bounds}, {isVisible}, zIndex={sprite.sprite.zIndex})"

proc reset*(anim: Animation) =
  anim.frame = 0
  anim.nextFrameTime = 0.0
  anim.manualOffset = ivec2(0, 0)
  anim.anchorOffset = ivec2(0, 0)
  anim.paused = false
  anim.visible = true

proc hidden*(sprite: Animation | Sprite): auto =
  sprite.sprite.visible = false
  return sprite

proc resetPooledValue*(sprite: Sprite) =
  sprite.sprite.remove()

proc restorePooledValue*(sprite: Sprite) =
  sprite.sprite.add()
  sprite.sprite.visible = true

proc resetPooledValue*(bitmap: LCDBitmap) =
  discard

proc restorePooledValue*(bitmap: LCDBitmap) =
  discard

proc restorePooledValue*(sprite: Animation) =
  sprite.add()
  change(addr sprite, sprite.def)

proc resetPooledValue*(sprite: Animation) =
  sprite.remove()
  sprite.reset()
