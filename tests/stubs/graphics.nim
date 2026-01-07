import std/[math, macros, strutils, sequtils], necsuspd/anchor

type
  AnimationDef* = distinct int

  LCDFont* = ref object
    name: string
    height: int
    charWidth: int

  Font* = LCDFont

  Sprite* = ref object
    img: Image
    hidden: bool

  Animation* = ref object
    img: Image
    def*: AnimationDef
    hidden: bool

  LCDBitmap* = ref object
    name: string
    data: ImageData
    mask: LCDBitmap

  Image* = LCDBitmap

  ImageData* = ref object
    pixels: seq[seq[bool]]
    width*: int
    height*: int

  PDStringEncoding* = enum
    kASCIIEncoding
    kUTF8Encoding
    k16BitLEEncoding

  TextEncoding* = PDStringEncoding

  LCDSolidColor* = enum
    kColorBlack
    kColorWhite

  Color* = LCDSolidColor

  PlaydateGraphics* = ref object
    context: seq[Image]
    actions: seq[string]

  LCDBitmapFlip* = enum
    kBitmapUnflipped
    kBitmapFlippedX
    kBitmapFlippedY
    kBitmapFlippedXY

  LCDBitmapDrawMode* = enum
    kDrawModeCopy
    kDrawModeWhiteTransparent
    kDrawModeBlackTransparent
    kDrawModeFillWhite
    kDrawModeFillBlack
    kDrawModeXOR
    kDrawModeNXOR
    kDrawModeInverted

let pdGraphics* = PlaydateGraphics()

proc graphicActions*(): seq[string] =
  result = pdGraphics.actions.items.toSeq
  pdGraphics.actions.setLen(0)
  assert(pdGraphics.context.len == 0)

proc event(action: string, details: varargs[string]) =
  var data = newSeq[string]()

  if pdGraphics.context.len > 0:
    data.add(pdGraphics.context[^1].name)

  data.add(details)

  pdGraphics.actions.add(action & "(" & join(data, ", ") & ")")

macro record(action: string, elements: varargs[typed]) =
  result = newCall(bindSym("event"))
  result.add(action)
  for child in elements:
    result.add(
      nnkInfix.newTree(
        newIdentNode("&"),
        newLit(child.repr & ": "),
        nnkPrefix.newTree(newIdentNode("$"), child),
      )
    )

proc `==`*(a, b: AnimationDef): bool {.borrow.}

proc asBool(color: Color): bool =
  case color
  of kColorWhite:
    return false
  of kColorBlack:
    return true

proc newBitmapData(width, height: int, color: LCDSolidColor): ImageData =
  result = ImageData(width: width, height: height, pixels: newSeq[seq[bool]](height))
  for y in 0 ..< height:
    result.pixels[y] = newSeq[bool](width)
    for value in result.pixels[y].mitems:
      value = color.asBool

proc newImage*(name: string, width, height: int, color: LCDSolidColor): Image =
  Image(name: name, data: newBitmapData(width, height, color))

proc newBitmap*(
    graphics: PlaydateGraphics, width, height: int, color: LCDSolidColor
): Image =
  return newImage("anon", width, height, color)

proc width*(this: LCDBitmap): auto =
  this.data.width

proc height*(this: LCDBitmap): auto =
  this.data.height

proc getBitmapMask*(image: LCDBitmap): LCDBitmap =
  assert(image.mask != nil)
  image.mask

proc setBitmapMask*(
    this: LCDBitmap,
    mask: LCDBitmap = pdGraphics.newBitmap(this.width, this.height, kColorWhite),
): int {.discardable.} =
  this.mask = mask
  return 0

proc newSprite*(name: string, width, height: int): Sprite =
  Sprite(img: newImage(name, width, height, kColorBlack))

proc newAnimationDef*(id: int = 0): AnimationDef =
  id.AnimationDef

proc newAnimation*(
    name: string, width, height: int, def: AnimationDef = newAnimationDef()
): Animation =
  Animation(img: newImage(name, width, height, kColorBlack), def: def)

proc newFont*(name: string, height: int = 14, charWidth = 8): Font =
  Font(name: name, height: height, charWidth: charWidth)

proc getFontHeight*(font: Font): int =
  font.height

proc getTextWidth*(
    font: LCDFont, text: string, length: int, encoding: TextEncoding, tracking: int
): int =
  assert(text.len == length)
  font.charWidth * length

proc fill*(font: Font): int =
  12

proc fillRect*(graphics: PlaydateGraphics, x, y, width, height: int, color: Color) =
  record("fillRect", x, y, width, height, color)

proc pushContext*(graphics: PlaydateGraphics, img: Image) =
  graphics.context.add(img)

proc popContext*(graphics: PlaydateGraphics) =
  graphics.context.setLen(graphics.context.len - 1)

proc getImage*(sprite: Sprite): LCDBitmap =
  sprite.img

proc setFont*(graphics: PlaydateGraphics, font: Font) =
  record("setFont", font.name)

proc setDrawMode*(graphics: PlaydateGraphics, drawMode: LCDBitmapDrawMode) =
  record("drawMode", drawMode)

proc drawText*(graphics: PlaydateGraphics, text: string, x, y: int) =
  record("drawText", text, x, y)

proc draw*(bitmap: Image, x, y: int, flip: LCDBitmapFlip) =
  let name = bitmap.name
  record("drawBitmap", name, x, y)

proc setMany*[W: static int](this: var Image, pixels: openarray[array[W, Color]]) =
  var asStr: string
  for i, row in pixels:
    if i > 0:
      asStr &= ";"
    for x in row:
      case x
      of kColorBlack:
        asStr &= "X"
      of kColorWhite:
        asStr &= "."
  let img = this.name
  record("setMany", img, asStr)

proc setPixel*(this: var ImageData, x, y: int, color: Color) =
  if x >= 0 and x < this.width:
    if y >= 0 and y < this.height:
      this.pixels[y][x] = color.asBool

proc clear*(this: Image, color: Color) =
  for y in 0 ..< this.height:
    for x in 0 ..< this.width:
      this.data.pixels[y][x] = color.asBool

proc getDataObj*(this: Image): ImageData =
  this.data

iterator rows*(this: LCDBitmap): string =
  ## Renders the rows of an image as characters in a string
  for y in 0 ..< this.height:
    var row = ""
    for x in 0 ..< this.width:
      if this.mask != nil and this.mask.data.pixels[y][x]:
        row &= "_"
      elif this.data.pixels[y][x]:
        row &= "X"
      else:
        row &= "."
    yield row

proc `==`*(this: LCDBitmap, versus: openarray[string]): bool =
  var i = 0
  for row in this.rows:
    if i >= versus.len or row != versus[i]:
      return false
    i += 1
  return i == versus.len

proc `$`*(img: LCDBitmap): string =
  for row in img.rows:
    result &= row & "\n"

proc width*(this: Sprite): auto =
  this.img.width

proc height*(this: Sprite): auto =
  this.img.height

proc width*(this: Animation): auto =
  this.img.width

proc height*(this: Animation): auto =
  this.img.height

proc change*(animation: ptr Animation | Animation, def: AnimationDef) =
  animation.def = def

proc `$`*(def: AnimationDef): string =
  "AnimationDef(#" & $int(def) & ")"

proc visible*(value: Sprite | Animation): bool =
  not value.hidden

proc `visible=`*(value: Sprite | Animation, flag: bool) =
  value.hidden = not flag

proc set*(this: LCDBitmap, x, y: int, color: LCDSolidColor) =
  this.data.setPixel(x, y, color)

proc animation*[S: enum](
    sheet: S,
    timePerFrame: float32,
    frames: Slice[int32],
    anchor: AnchorPosition,
    loop: bool = true,
): AnimationDef =
  newAnimationDef()

proc newSheet*(
    frames: seq[LCDBitmap],
    def: AnimationDef,
    zIndex: SomeInteger or enum,
    absolutePos: bool = false,
): Animation =
  return newAnimation("custom", frames[0].width, frames[0].height, def)

proc drawLine*(g: PlaydateGraphics, x1, y1, x2, y2, w: int, c: LCDSolidColor) =
  let img = g.context[^1]
  let r = w div 2
  let dx = abs(x2 - x1)
  let dy = abs(y2 - y1)
  let sx = if x1 < x2: 1 else: -1
  let sy = if y1 < y2: 1 else: -1

  proc go(x, y, err: int) =
    for ox in -r .. r:
      for oy in -r .. r:
        let px = x + ox
        let py = y + oy
        if px in 0..<img.width and py in 0..<img.height:
          img.data.pixels[py][px] = c.asBool

    if x != x2 or y != y2:
      let e2 = err * 2
      go(
        x + (if e2 > -dy: sx else: 0),
        y + (if e2 < dx: sy else: 0),
        err - (if e2 > -dy: dy else: 0) + (if e2 < dx: dx else: 0),
      )

  go(x1, y1, dx - dy)
