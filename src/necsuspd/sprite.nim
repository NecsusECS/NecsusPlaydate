import playdate/api, positioned, necsus, vmath, time, viewport, util, vec_tools
import std/[options, strformat, macros, sequtils]

type
  ZIndexValue = SomeInteger or enum ## A value that can be used as a zindex

  AnchorLock* = enum
    AnchorTopLeft
    AnchorTopMiddle
    AnchorTopRight
    AnchorMiddle
    AnchorBottomLeft
    AnchorBottomMiddle
    AnchorBottomRight

  Anchor* = tuple[lock: AnchorLock, offset: IVec2]

  AnchorPosition* = Anchor | AnchorLock

  AssetTable*[A] =
    concept table
        table.asset(A) is LCDBitmap

  SheetTable*[S] =
    concept table
        table.sheet(S) is LCDBitmapTable

  Keyframe*[S: enum] {.byref.} = object
    ## An event that is triggered when an animation reaches a specific frame
    keyframeValue: int32
    keyframeTypeId: int32
    sheet*: S
    entityId*: EntityId

  Frame* = object
    time: float32
    cellId: int32
    case isKeyframe: bool
    of true:
      keyframeValue: int32
      keyframeTypeId: int32
    of false:
      discard

  AnimationDefObj[S: enum] = object ## A specific animation within a sprite sheet
    sheet: S
    frames: seq[Frame]
    anchor: Anchor
    loop: bool

  AnimationDef*[S: enum] = ref AnimationDefObj[S]
    ## A specific animation within a sprite sheet

  AnimationObj[S] = object
    def: AnimationDef[S]
    sprite*: LCDSprite
    table: LCDBitmapTable
    frameCache: seq[LCDBitmap]
    frame: int32
    nextFrameTime: float32
    anchorOffset, manualOffset: IVec2
    absolutePos: bool
    paused: bool

  Animation*[S] = ref AnimationObj[S]

  Unpausable* {.accessory.} = object

  SpriteObj* = object
    image: LCDBitmap
    sprite: LCDSprite
    anchorOffset, manualOffset: IVec2
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

proc modify*[S](
    def: AnimationDef[S], cellOffset: int32 = 0, anchor: Anchor = def.anchor
): AnimationDef[S] =
  ## Creates a copy of an AnimationDef with all the cellIds offset by a given amount
  result = new(AnimationDef[S])
  result[] = def[]
  result.frames = def.frames.mapIt(it.offsetCellId(cellOffset))
  result.anchor = anchor

proc keyframe*(keyframe: Keyframe, typ: typedesc[enum]): Option[typ] =
  ## Extracts the keyframe as an enum
  if keyframe.keyframeTypeId == typ.getTypeId:
    return some(typ(keyframe.keyframeValue))

proc offsetFix(sprite: LCDSprite, anchor: Anchor): IVec2 =
  ## Returns the offset necessary to align a position to the 0, 0 position of a sprite
  result = anchor.offset

  case anchor.lock
  of AnchorTopLeft, AnchorBottomLeft:
    result.x += sprite.getImage.getSize.width.int32 div 2
  of AnchorTopMiddle, AnchorMiddle, AnchorBottomMiddle:
    discard
  of AnchorTopRight, AnchorBottomRight:
    result.x -= sprite.getImage.getSize.width.int32 div 2

  case anchor.lock
  of AnchorTopLeft, AnchorTopMiddle, AnchorTopRight:
    result.y += sprite.getImage.getSize.height.int32 div 2
  of AnchorMiddle:
    discard
  of AnchorBottomLeft, AnchorBottomMiddle, AnchorBottomRight:
    result.y -= sprite.getImage.getSize.height.int32 div 2

proc toAnchor(anchor: AnchorPosition): Anchor {.inline.} =
  when anchor is AnchorLock:
    return (anchor, ivec2(0, 0))
  else:
    return anchor

proc `=copy`(x: var SpriteObj, y: SpriteObj) {.error.}

proc `=sink`(x: var SpriteObj, y: SpriteObj) {.error.}

proc `=destroy`(sprite: SpriteObj) {.warning[Effect]: off.} =
  if sprite.sprite != nil:
    playdate.sprite.removeSprites(@[sprite.sprite])
    `=destroy`(sprite.sprite)

proc `=copy`[S](x: var AnimationObj[S], y: AnimationObj[S]) {.error.}

proc `=destroy`[S](sprite: AnimationObj[S]) =
  if sprite.sprite != nil:
    playdate.sprite.removeSprites(@[sprite.sprite])

proc width*(sprite: Sprite | Animation): auto =
  sprite.sprite.getImage.getSize.width

proc height*(sprite: Sprite | Animation): auto =
  sprite.sprite.getImage.getSize.height

proc def*[S](animation: Animation[S]): AnimationDef[S] =
  animation.def

proc frame*(cellId: int32, time: float32): Frame =
  ## Build a frame
  Frame(cellId: cellId, time: time, isKeyframe: false)

proc frame*(cellId: int32, time: float32, keyframe: enum): Frame =
  ## Build a frame with a keyframe
  Frame(
    cellId: cellId,
    time: time,
    isKeyframe: true,
    keyframeValue: ord(keyframe).int32,
    keyframeTypeId: keyframe.type.getTypeId,
  )

proc animation*[S: enum](
    sheet: S, frames: openarray[Frame], anchor: AnchorPosition, loop: bool = true
): AnimationDef[S] =
  assert(frames.len > 0)
  AnimationDef[S](
    sheet: sheet, frames: frames.toSeq, anchor: anchor.toAnchor, loop: loop
  )

proc animation*[S: enum](
    sheet: S,
    timePerFrame: float32,
    frames: Slice[int32],
    anchor: AnchorPosition,
    loop: bool = true,
): AnimationDef[S] =
  var frameSeq: seq[Frame]
  for i in frames:
    frameSeq.add(frame(i.int32, timePerFrame))
  return animation[S](sheet, frameSeq, anchor, loop)

proc `$`*[S: enum](def: AnimationDef[S] | AnimationDefObj[S]): string =
  fmt"AnimationDef({def.sheet}, frames={def.frames}, tpf={def.timePerFrame}, {def.anchor}, loop={def.loop})"

proc `$`*[S: enum](anim: ptr Animation[S]): string =
  fmt"Animation({$S}, {anim.def}, frame={anim.frame}, nextFrameAt={anim.nextFrameTime}, " &
    fmt"absolutePos={anim.absolutePos}, paused={anim.paused})"

proc newBitmapSprite*(
    img: LCDBitmap,
    zIndex: ZIndexValue,
    anchor: AnchorPosition,
    absolutePos: bool = false,
): Sprite =
  result.new()
  result.sprite = playdate.sprite.newSprite()
  result.sprite.setImage(img, kBitmapUnflipped)
  result.sprite.zIndex = ord(zIndex).int16
  result.sprite.add()
  result.anchorOffset = result.sprite.offsetFix(anchor.toAnchor)
  result.absolutePos = absolutePos
  result.sprite.setOpaque(false)

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

iterator linked*[S](sprite: Animation[S]): Animation[S] =
  yield sprite

iterator linked*(sprite: Sprite): Sprite =
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

proc softChange*[S](animation: ptr Animation[S] | Animation[S], def: AnimationDef[S]) =
  ## Changes the animation currently runnig while trying not to modify the frame number
  assert(animation.def.sheet == def.sheet)
  animation.def = def
  animation.frame = animation.frame.clamp(0'i32, def.frames.len.int32 - 1)
  animation.anchorOffset = animation.sprite.offsetFix(def.anchor.toAnchor)

proc change*[S](animation: ptr Animation[S] | Animation[S], def: AnimationDef[S]) =
  ## Changes the animation currently runnig for a sprite
  assert(animation.def.sheet == def.sheet)
  animation.def = def
  animation.frame = 0
  animation.nextFrameTime = 0
  animation.anchorOffset = animation.sprite.offsetFix(def.anchor.toAnchor)

proc `paused=`*[S](animation: ptr Animation[S], pause: bool) =
  ## Pauses this animation
  animation.paused = pause

proc `[]`[S](anim: Animation[S], frame: int32): LCDBitmap =
  ## Return a frame from an animation
  assert(anim.frameCache.len > frame)
  assert(not anim.frameCache[frame].isNil)
  return anim.frameCache[frame]

proc newSheet*[S: enum](
    frames: seq[LCDBitmap],
    def: AnimationDef[S],
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): Animation[S] =
  when compileOption("assertions"):
    for frame in frames:
      assert(not frame.isNil)

  result = Animation[S](
    def: def,
    sprite: playdate.sprite.newSprite(),
    absolutePos: absolutePos,
    frameCache: frames.toSeq,
  )

  result.sprite.setImage(result[result.frame], kBitmapUnflipped)
  `zIndex=`(result.sprite, ord(zIndex).int16)
  result.sprite.add()
  change(addr result, def)

proc newSheet*[S: enum](
    assets: SharedOrT[SheetTable[S]],
    def: AnimationDef[S],
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): Animation[S] =
  let table = assets.unwrap.sheet(def.sheet)
  let frameCount = table.getBitmapTableInfo.count
  var frames = newSeq[LCDBitmap](frameCount)
  for i in 0 ..< frameCount:
    frames[i] = table.getBitmap(i)
  newSheet[S](frames, def, zIndex, absolutePos)

template move(movable, viewport) =
  let viewportOffset = ivec2(viewport.x, viewport.y)
  let noViewport = ivec2(0, 0)
  for (parent, pos) in movable:
    for sprite in parent.linked:
      let viewportOffset = if sprite.absolutePos: noViewport else: viewportOffset
      let absolutePos =
        pos.toIVec2 + sprite.anchorOffset + sprite.manualOffset - viewportOffset
      sprite.sprite.moveTo(absolutePos.x.cfloat, absolutePos.y.cfloat)

proc buidSpriteMover*[S](): auto =
  ## Builds a system that moves sprites so they match their position
  return proc(
      sprites: Query[(Sprite, Positioned)],
      animated: Query[(Animation[S], Positioned)],
      viewport: Shared[ViewPort],
      viewportTweaks: Query[(ViewPortTweak,)],
  ) =
    var vp = viewport.get()
    for (tweak) in viewportTweaks:
      vp += tweak

    move(sprites, vp)
    move(animated, vp)

proc buildSpriteAdvancer*[S](): auto =
  ## Moves ahead any sprite animations that need to be updated
  return proc(
      time: GameTime,
      elements: FullQuery[(Animation[S], Option[Unpausable])],
      events: Outbox[Keyframe[S]],
  ) =
    let now = time.get.float32
    for eid, (parent, unpausable) in elements:
      for anim in parent.linked:
        if anim.sprite.visible and (not anim.paused or unpausable.isSome) and
            anim.nextFrameTime <= now:
          if anim.nextFrameTime == 0:
            anim.nextFrameTime = now
          elif anim.frame == (anim.def.frames.len - 1):
            if anim.def.loop:
              anim.frame = 0
          else:
            anim.frame += 1

          let frame: Frame = anim.def.frames[anim.frame]
          anim.nextFrameTime = now + frame.time
          anim.sprite.setImage(anim[frame.cellId], kBitmapUnflipped)
          if frame.isKeyframe:
            events(
              Keyframe[S](
                sheet: anim.def.sheet,
                keyframeValue: frame.keyframeValue,
                keyframeTypeId: frame.keyframeTypeId,
                entityId: eid,
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

proc reset*[S](anim: Animation[S]) =
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
