import import_playdate, hebitmap, vmath, util

type
  DrawItemKind* = enum
    dikHE
    dikLCD

  DrawItemObj* = object
    visible: bool
    zIndex: int16
    pos: IVec2
    flipY: bool
    inverted: bool
      ## Colour-invert (black<->white) at draw time while preserving
      ## transparency; used to keep light-on-dark art visible on light themes
    size: IVec2
      ## Cached bitmap dimensions; querying an LCDBitmap's size goes through
      ## the Playdate C API, which is too slow to do per sprite per frame
    case kind: DrawItemKind
    of dikHE: he: HEBitmap
    of dikLCD: lcd: LCDBitmap

  DrawItem* = ref DrawItemObj

proc calcSize(lcd: LCDBitmap): IVec2 =
  let size = lcd.getSize
  return ivec2(size.width.int32, size.height.int32)

proc calcSize(he: HEBitmap): IVec2 {.inline.} =
  he.size

proc newDrawItem*(
    lcd: LCDBitmap,
    zIndex: auto,
    visible: bool = true,
    pos: IVec2 = ivec2(0, 0),
    flipY: bool = false,
    inverted: bool = false,
): DrawItem {.inline.} =
  DrawItem(
    kind: dikLCD,
    lcd: lcd,
    zIndex: ord(zIndex).int16,
    visible: visible,
    pos: pos,
    flipY: flipY,
    inverted: inverted,
    size: lcd.calcSize,
  )

proc newDrawItem*(
    he: HEBitmap,
    zIndex: auto,
    visible: bool = true,
    pos: IVec2 = ivec2(0, 0),
    flipY: bool = false,
    inverted: bool = false,
): DrawItem {.inline.} =
  DrawItem(
    kind: dikHE,
    he: he,
    zIndex: ord(zIndex).int16,
    visible: visible,
    pos: pos,
    flipY: flipY,
    inverted: inverted,
    size: he.calcSize,
  )

proc moveTo*(d: DrawItem, pos: IVec2) {.inline.} =
  d.pos = pos

proc pos*(d: DrawItem): IVec2 {.inline.} =
  d.pos

proc zIndex*(d: DrawItem): auto {.inline.} =
  d.zIndex

proc dimens*(item: DrawItem): IVec2 {.inline.} =
  item.size

proc width*(item: DrawItem): int32 {.inline.} =
  item.dimens[0]

proc height*(item: DrawItem): int32 {.inline.} =
  item.dimens[1]

proc `img=`*(d: DrawItem, img: LCDBitmap) {.inline.} =
  d.lcd = img
  d.size = img.calcSize

proc img*(d: DrawItem): var LCDBitmap {.inline.} =
  d.lcd

proc visible*(d: DrawItem): bool {.inline.} =
  d.visible

proc `visible=`*(d: DrawItem, visible: bool) {.inline.} =
  d.visible = visible

proc flipY*(d: DrawItem): bool {.inline.} =
  d.flipY

proc `flipY=`*(d: DrawItem, v: bool) {.inline.} =
  d.flipY = v

proc inverted*(d: DrawItem): bool {.inline.} =
  d.inverted

proc `inverted=`*(d: DrawItem, v: bool) {.inline.} =
  d.inverted = v

var gDrawLayer*: seq[seq[DrawItem]]

when defined(simulator):
  var debugCallbacks: seq[proc(debug: LCDBitmap)]

proc debugDraw*(callback: proc(debug: LCDBitmap)) {.inline.} =
  when defined(simulator):
    debugCallbacks.add(callback)

proc resetDrawLayer*() =
  gDrawLayer.setLen(0)

proc register*(item: DrawItem) =
  let z = item.zIndex.int
  if z >= gDrawLayer.len:
    gDrawLayer.setLen(z + 1)
  gDrawLayer[z].add(item)

proc unregister*(item: DrawItem) =
  if item == nil:
    return
  let z = item.zIndex.int
  if z < gDrawLayer.len:
    for i, e in gDrawLayer[z]:
      if e == item:
        gDrawLayer[z].delete(i)
        return
  log "ERROR: Unable to unregister item"

proc getImage*(item: DrawItem): var LCDBitmap {.inline.} =
  assert(item.kind == dikLCD, "getImage is only valid for LCD drawables")
  return item.lcd

proc setImage*(item: DrawItem, img: LCDBitmap) {.inline.} =
  item.lcd = img
  item.size = img.calcSize

proc setImage*(item: DrawItem, img: HEBitmap) {.inline.} =
  item.he = img
  item.size = img.calcSize

proc coversScreen(item: DrawItem): bool =
  ## True when drawing this item alone repaints the entire framebuffer,
  ## making a screen clear before it redundant
  item.kind == dikHE and item.he.isOpaque and item.pos.x <= 0 and item.pos.y <= 0 and
    item.pos.x + item.size.x >= LCD_COLUMNS and item.pos.y + item.size.y >= LCD_ROWS

proc drawSprites*() =
  playdate.sprite.addDirtyRect(LCD_SCREEN_RECT)
  playdate.graphics.setDrawMode(kDrawModeCopy)
  # log "START"
  var needsClear = true
  # Iterating with `items` instead of `pairs` matters here: `pairs` yields a
  # tuple, which copies the inner seq (and increfs every DrawItem) per bucket
  for bucket in gDrawLayer.items:
    for item in bucket:
      if item.visible:
        if needsClear:
          if not item.coversScreen:
            playdate.graphics.clear(kColorWhite)
          needsClear = false
        case item.kind
        of dikHE:
          item.he.draw(item.pos, item.flipY, item.inverted)
        of dikLCD:
          let flip = if item.flipY: kBitmapFlippedY else: kBitmapUnflipped
          if item.inverted:
            # The loop-wide draw mode is kDrawModeCopy; flip to inverted just
            # for this item and restore afterwards.
            playdate.graphics.setDrawMode(kDrawModeInverted)
            item.lcd.draw(item.pos.x, item.pos.y, flip)
            playdate.graphics.setDrawMode(kDrawModeCopy)
          else:
            item.lcd.draw(item.pos.x, item.pos.y, flip)
        # log "RENDERING: (",  item.pos.x, ", ", item.pos.y, ") ",
        #   item.dimens.x, "x", item.dimens.y, " at ", bucketId

        when defined(drawSpritesDebug):
          let capturedItem = item
          debugDraw do(img: LCDBitmap) -> void:
            playdate.graphics.pushContext(img)
            playdate.graphics.drawRect(
              capturedItem.pos.x.int, capturedItem.pos.y.int, capturedItem.dimens.x.int,
              capturedItem.dimens.y.int, kColorWhite,
            )
            playdate.graphics.popContext()

  if needsClear:
    playdate.graphics.clear(kColorWhite)

  when defined(simulator):
    var img = playdate.graphics.getDebugBitmap()
    if img != nil:
      for debug in debugCallbacks:
        debug(img)
    debugCallbacks.setLen(0)

  if defined(showFPS):
    playdate.system.drawFPS(LCD_COLUMNS - 18, 4)
