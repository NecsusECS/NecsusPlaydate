import macros, strutils, sequtils

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

proc `==`*(a, b: AnimationDef): bool {.borrow.}

proc newBitmapData(width, height: int): ImageData =
  result = ImageData(width: width, height: height, pixels: newSeq[seq[bool]](height))
  for y in 0 ..< height:
    result.pixels[y] = newSeq[bool](width)

proc newImage*(name: string, width, height: int): Image =
  Image(name: name, data: newBitmapData(width, height))

proc newBitmap*(graphics: PlaydateGraphics, width, height: int, color: Color): Image =
  return newImage("anon", width, height)

proc setBitmapMask*(image: Image): int =
  return 0

proc newSprite*(name: string, width, height: int): Sprite =
  Sprite(img: newImage(name, width, height))

proc newAnimationDef*(id: int = 0): AnimationDef =
  id.AnimationDef

proc newAnimation*(
    name: string, width, height: int, def: AnimationDef = newAnimationDef()
): Animation =
  Animation(img: newImage(name, width, height), def: def)

proc newFont*(name: string, height: int = 14, charWidth = 8): Font =
  Font(name: name, height: height, charWidth: charWidth)

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

proc asBool(color: Color): bool =
  case color
  of kColorWhite:
    return false
  of kColorBlack:
    return true

proc setPixel*(this: var ImageData, x, y: int, color: Color) =
  if x >= 0 and x < this.width:
    if y >= 0 and y < this.height:
      this.pixels[y][x] = color.asBool

proc width*(this: Image): auto =
  this.data.width

proc height*(this: Image): auto =
  this.data.height

proc clear*(this: var Image, color: Color) =
  for y in 0 ..< this.height:
    for x in 0 ..< this.width:
      this.data.pixels[y][x] = color.asBool

proc getDataObj*(this: Image): ImageData =
  this.data

proc `$`*(img: ImageData): string =
  result = newStringOfCap(img.width * img.height + img.height)
  for row in img.pixels:
    for x in row:
      if x:
        result &= "X"
      else:
        result &= "."
    result &= ";"

proc `$`*(img: Image): string =
  $img.data

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
