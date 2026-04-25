import necsuspd/[import_playdate, util], vmath

type
  DrawItemObj* = object
    visible: bool
    zIndex: int16
    pos: IVec2
    lcd: LCDBitmap

  DrawItem* = ref DrawItemObj

proc newDrawItem*(lcd: LCDBitmap, zIndex: auto, visible: bool = true): DrawItem {.inline.} =
  DrawItem(lcd: lcd, zIndex: ord(zIndex).int16, visible: visible)

proc moveTo*(d: DrawItem, pos: IVec2) {.inline.} =
  d.pos = pos

proc pos*(d: DrawItem): IVec2 {.inline.} =
  d.pos

proc zIndex*(d: DrawItem): auto {.inline.} =
  d.zIndex

proc dimens*(d: DrawItem): IVec2 {.inline.} =
  let size = d.lcd.getSize
  return ivec2(size.width.int32, size.height.int32)

proc `img=`*(d: DrawItem, img: LCDBitmap) {.inline.} =
  d.lcd = img

proc img*(d: DrawItem): var LCDBitmap {.inline.} =
  d.lcd

proc visible*(d: DrawItem): bool {.inline.} =
  d.visible

proc `visible=`*(d: DrawItem, visible: bool) {.inline.} =
  d.visible = visible

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

proc drawSprites*() =
  playdate.graphics.clear(kColorWhite)
  playdate.sprite.addDirtyRect(LCD_SCREEN_RECT)
  playdate.graphics.setDrawMode(kDrawModeCopy)
  # log "START"
  for bucketId, bucket in gDrawLayer:
    for item in bucket:
      if item.visible:
        item.lcd.draw(item.pos.x, item.pos.y, kBitmapUnflipped)
        # log "RENDERING: (",  item.pos.x, ", ", item.pos.y, ") ",
        #   item.dimens.x, "x", item.dimens.y, " at ", bucketId

        when defined(drawSpritesDebug):
          let capturedItem = item
          debugDraw do(img: LCDBitmap) -> void:
            playdate.graphics.pushContext(img)
            playdate.graphics.drawRect(
              capturedItem.pos.x.int,
              capturedItem.pos.y.int,
              capturedItem.dimens.x.int,
              capturedItem.dimens.y.int,
              kColorWhite
            )
            playdate.graphics.popContext()

  when defined(simulator):
    var img = playdate.graphics.getDebugBitmap()
    if img != nil:
      for debug in debugCallbacks:
        debug(img)
    debugCallbacks.setLen(0)

  if defined(showFPS):
    playdate.system.drawFPS(LCD_COLUMNS - 18, 4)
