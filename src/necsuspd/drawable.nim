import
  import_playdate,
  positioned,
  necsus,
  vmath,
  viewport,
  util,
  vec_tools,
  anchor,
  drawlayer,
  std/[strformat]

export drawlayer

export anchor

type
  ZIndexValue* = SomeInteger or enum

  AssetTable*[A] = concept table
    table.asset(A) is LCDBitmap

  DrawableObj* = object
    anchorOffset*: IVec2
    manualOffset: IVec2
    absolutePos: bool
    link: Drawable
    drawItem*: DrawItem

  Drawable* = ref DrawableObj

proc offsetFix*(img: LCDBitmap, anchor: Anchor): IVec2 =
  return
    anchor.offset +
    anchor.lock.resolveFromCenter(
      img.getSize.width.int32, img.getSize.height.int32
    )

proc `=copy`(x: var DrawableObj, y: DrawableObj) {.error.}

proc `=sink`(x: var DrawableObj, y: DrawableObj) {.error.}

proc `=destroy`(d: DrawableObj) {.warning[Effect]: off.} =
  unregister(d.drawItem)

proc width*(d: Drawable | ptr Drawable): auto =
  d.drawItem.dimens.x

proc height*(d: Drawable | ptr Drawable): auto =
  d.drawItem.dimens.y

proc visible*(d: Drawable | ptr Drawable): bool {.inline.} =
  d.drawItem.visible

proc `visible=`*(d: Drawable | ptr Drawable, visible: bool) {.inline.} =
  d.drawItem.visible = visible

proc zIndex*(d: Drawable | ptr Drawable): int16 {.inline.} =
  d.drawItem.zIndex

proc `zIndex=`*(d: Drawable | ptr Drawable, index: auto) {.inline.} =
  if d.drawItem != nil:
    unregister(d.drawItem)
    d.drawItem.zIndex = index.int16
    register(d.drawItem)

proc offset*(d: Drawable | ptr Drawable): IVec2 {.inline.} =
  d.manualOffset

proc `offset=`*(d: Drawable | ptr Drawable, offset: IVec2) {.inline.} =
  d.manualOffset = offset

proc remove*(d: Drawable | ptr Drawable) =
  unregister(d.drawItem)

proc add*(d: Drawable | ptr Drawable) =
  register(d.drawItem)

proc getImage*(d: Drawable | ptr Drawable): var LCDBitmap =
  return d.drawItem.img

proc getBitmapMask*(d: Drawable | ptr Drawable): LCDBitmap =
  return d.getImage.getBitmapMask

proc markDirty*(d: Drawable | ptr Drawable) {.inline.} =
  discard

proc setBitmapMask*(
    d: Drawable,
    img: LCDBitmap =
      playdate.graphics.newBitmap(d.width, d.height, kColorWhite),
) =
  discard d.getImage.setBitmapMask(img)

proc setImage*(d: Drawable, img: LCDBitmap) {.inline.} =
  d.drawItem.img = img

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

proc dimens*(d: Drawable | ptr Drawable): IVec2 {.inline.} =
  return ivec2(d.width.int32, d.height.int32)

proc toTopLeft*(d: Drawable | ptr Drawable): IVec2 {.inline.} =
  return -(d.dimens div 2) + d.anchorOffset + d.manualOffset

proc hidden*(d: Drawable): auto =
  d.drawItem.visible = false
  return d

proc resetPooledValue*(d: Drawable) =
  unregister(d.drawItem)

proc restorePooledValue*(d: Drawable) =
  register(d.drawItem)
  d.drawItem.visible = true

proc `$`*(d: Drawable): string =
  {.cast(gcsafe).}:
    let isVisible = if d.drawItem.visible: "visible" else: "hidden"
    let pos = d.drawItem.pos
    return fmt"Drawable(({pos.x}, {pos.y}), {isVisible}, zIndex={d.drawItem.zIndex})"

proc newBitmapDrawable*(
    img: LCDBitmap,
    zIndex: ZIndexValue,
    anchor: AnchorPosition,
    absolutePos: bool = false,
): Drawable =
  result = Drawable(
    anchorOffset: offsetFix(img, anchor.toAnchor),
    absolutePos: absolutePos,
    drawItem: newDrawItem(img, zIndex)
  )
  register(result.drawItem)

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
      d.drawItem.moveTo(absolutePos - d.drawItem.dimens div 2)
