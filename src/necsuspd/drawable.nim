import
  import_playdate,
  positioned,
  necsus,
  vmath,
  viewport,
  util,
  vec_tools,
  anchor,
  std/[strformat]

export anchor

type
  ZIndexValue* = SomeInteger or enum

  AssetTable*[A] = concept table
    table.asset(A) is LCDBitmap

  DrawableObj* = object
    image: LCDBitmap
    sprite: LCDSprite
    anchorOffset*: IVec2
    manualOffset: IVec2
    lastPosition: IVec2
    absolutePos: bool
    link: Drawable

  Drawable* = ref DrawableObj

proc lcdSprite*(d: Drawable | ptr Drawable): LCDSprite {.inline.} =
  d.sprite

proc offsetFix*(sprite: LCDSprite, anchor: Anchor): IVec2 =
  return
    anchor.offset +
    anchor.lock.resolveFromCenter(
      sprite.getImage.getSize.width.int32, sprite.getImage.getSize.height.int32
    )

proc `=copy`(x: var DrawableObj, y: DrawableObj) {.error.}

proc `=sink`(x: var DrawableObj, y: DrawableObj) {.error.}

proc `=destroy`(d: DrawableObj) {.warning[Effect]: off.} =
  if d.sprite != nil:
    playdate.sprite.removeSprites(@[d.sprite])
    `=destroy`(d.sprite)

proc width*(d: Drawable | ptr Drawable): auto =
  d.sprite.getImage.getSize.width

proc height*(d: Drawable | ptr Drawable): auto =
  d.sprite.getImage.getSize.height

proc visible*(d: Drawable | ptr Drawable): bool {.inline.} =
  d.sprite.visible

proc `visible=`*(d: Drawable | ptr Drawable, visible: bool) {.inline.} =
  `visible=`(d.sprite, visible)

proc zIndex*(d: Drawable | ptr Drawable): int16 {.inline.} =
  d.sprite.zIndex

proc `zIndex=`*(d: Drawable | ptr Drawable, index: auto) {.inline.} =
  d.sprite.zIndex = index.int16

proc offset*(d: Drawable | ptr Drawable): IVec2 {.inline.} =
  d.manualOffset

proc `offset=`*(d: Drawable | ptr Drawable, offset: IVec2) {.inline.} =
  d.manualOffset = offset

proc remove*(d: Drawable | ptr Drawable) =
  d.sprite.remove()

proc add*(d: Drawable | ptr Drawable) =
  d.sprite.add()

proc getImage*(d: Drawable | ptr Drawable): var LCDBitmap =
  if d.image.isNil:
    d.image = d.sprite.getImage
  return d.image

proc getBitmapMask*(d: Drawable | ptr Drawable): LCDBitmap =
  return d.getImage.getBitmapMask

proc markDirty*(d: Drawable | ptr Drawable) {.inline.} =
  d.sprite.markDirty

proc `collideRect=`*(d: Drawable, rectangle: PDRect) {.inline.} =
  `collideRect=`(d.sprite, rectangle)

proc setDrawMode*(d: Drawable, mode: LCDBitmapDrawMode) =
  d.sprite.setDrawMode(mode)

proc setBitmapMask*(
    d: Drawable,
    img: LCDBitmap =
      playdate.graphics.newBitmap(d.width, d.height, kColorWhite),
) =
  discard d.getImage.setBitmapMask(img)

proc setImage*(d: Drawable, img: LCDBitmap) {.inline.} =
  d.sprite.setImage(img, kBitmapUnflipped)

iterator linked*(d: Drawable): Drawable {.inline.} =
  var current {.cursor.} = d
  while current != nil:
    yield current
    current = current.link

proc link*(d: Drawable): Drawable {.inline.} =
  d.link

proc `link=`*(parent, child: Drawable) {.inline.} =
  assert(parent.link == nil)
  assert(child != nil)
  when compileOption("assertions"):
    for d in child.linked:
      assert(addr(d[]) != addr(parent[]))
  parent.link = child

proc toTopLeft*(d: Drawable | ptr Drawable): IVec2 {.inline.} =
  let dimens = ivec2(d.width.int32, d.height.int32)
  return -(dimens div 2) + d.anchorOffset + d.manualOffset

proc hidden*(d: Drawable): auto =
  d.sprite.visible = false
  return d

proc resetPooledValue*(d: Drawable) =
  d.sprite.remove()

proc restorePooledValue*(d: Drawable) =
  d.sprite.add()
  d.sprite.visible = true

proc `$`*(d: Drawable): string =
  {.cast(gcsafe).}:
    let isVisible = if d.sprite.visible: "visible" else: "hidden"
    return
      fmt"Drawable({d.sprite.bounds}, {isVisible}, zIndex={d.sprite.zIndex})"

proc newBitmapDrawable*(
    img: LCDBitmap,
    zIndex: ZIndexValue,
    anchor: AnchorPosition,
    absolutePos: bool = false,
): Drawable =
  var sprite = playdate.sprite.newSprite()
  sprite.setImage(img, kBitmapUnflipped)
  sprite.zIndex = ord(zIndex).int16
  sprite.setOpaque(false)
  sprite.add()

  return Drawable(
    sprite: sprite,
    anchorOffset: sprite.offsetFix(anchor.toAnchor),
    absolutePos: absolutePos,
    lastPosition: ivec2(int32.high, int32.high),
  )

proc newAssetDrawable*[A](
    assets: SharedOrT[AssetTable[A]],
    asset: A,
    anchor: AnchorPosition,
    zIndex: ZIndexValue,
    absolutePos: bool = false,
): Drawable =
  newBitmapDrawable(
    assets.unwrap.asset(asset).copy,
    anchor = anchor,
    zIndex = zIndex,
    absolutePos = absolutePos,
  )

proc newBlankDrawable*(
    width, height: int32,
    zIndex: ZIndexValue,
    anchor: AnchorPosition,
    color: LCDColor = kColorWhite,
    absolutePos: bool = false,
): Drawable =
  return newBitmapDrawable(
    playdate.graphics.newBitmap(width, height, color), zIndex, anchor, absolutePos
  )

template newBlankDrawable*(
    width, height: int,
    zIndex: ZIndexValue,
    anchor: AnchorPosition,
    color: LCDColor = kColorWhite,
    absolutePos: bool = false,
): Drawable =
  newBlankDrawable(width.int32, height.int32, zIndex, anchor, color, absolutePos)

when defined(simulator):
  var debugCallbacks: seq[proc(debug: LCDBitmap)]

proc debugDraw*(callback: proc(debug: LCDBitmap)) {.inline.} =
  when defined(simulator):
    debugCallbacks.add(callback)

proc drawSprites*() =
  playdate.sprite.drawSprites()

  if defined(showFPS):
    playdate.system.drawFPS(LCD_COLUMNS - 18, 4)

  when defined(simulator):
    var img = playdate.graphics.getDebugBitmap()
    if img != nil:
      for debug in debugCallbacks:
        debug(img)

proc moveDrawables*(
    drawables: Query[(ptr Drawable, Positioned)],
    viewport: Shared[ViewPort],
    viewportTweaks: Query[(ViewPortTweak,)],
) =
  var vp = viewport.get()
  for (tweak) in viewportTweaks:
    vp += tweak

  let viewportOffset = ivec2(vp.x, vp.y)
  let noViewport = ivec2(0, 0)
  for (parent, pos) in drawables:
    for d in parent[].linked:
      let vpOff = if d.absolutePos: noViewport else: viewportOffset
      let absolutePos =
        pos.toIVec2 + d.anchorOffset + d.manualOffset - vpOff
      if absolutePos != d.lastPosition:
        d.sprite.moveTo(absolutePos.x.cfloat, absolutePos.y.cfloat)
        d.lastPosition = absolutePos
