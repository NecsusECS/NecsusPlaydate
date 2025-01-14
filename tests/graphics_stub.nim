import macros, strutils, sequtils

type
    Font* = ref object
        name: string
        height: int
        charWidth: int

    Sprite* = ref object
        img: Image

    Image* = ref object
        name: string
        data: ImageData

    ImageData* = ref object
        pixels: seq[seq[bool]]
        width*: int
        height*: int

    TextEncoding* = enum kASCIIEncoding, kUTF8Encoding

    Color* = enum kColorBlack, kColorWhite

    DrawMode* = enum kDrawModeCopy, kDrawModeFillBlack, kDrawModeFillWhite

    PDGraphics* = ref object
        context: seq[Image]
        actions: seq[string]

    BitmapFlip* = enum
        kBitmapUnflipped,
        kBitmapFlippedX,
        kBitmapFlippedY,
        kBitmapFlippedXY

proc newBitmapData(width, height: int): ImageData =
    result = ImageData(width: width, height: height, pixels: newSeq[seq[bool]](height))
    for y in 0..<height:
        result.pixels[y] = newSeq[bool](width)

proc newImage*(name: string, width, height: int): Image =
    Image(name: name, data: newBitmapData(width, height))

proc newBitmap*(graphics: PDGraphics, width, height: int, color: Color): Image =
    return newImage("anon", width, height)

proc setBitmapMask*(image: Image): int =
    return 0

proc newSprite*(name: string, width, height: int): Sprite =
    Sprite(img: newImage(name, width, height))

proc newFont*(name: string, height: int = 14, charWidth = 8): Font =
    Font(name: name, height: height, charWidth: charWidth)

let graphics* = new(PDGraphics)

proc graphicActions*(): seq[string] =
    result = graphics.actions.items.toSeq
    graphics.actions.setLen(0)
    assert(graphics.context.len == 0)

proc event(action: string, details: varargs[string]) =
    var data = newSeq[string]()

    if graphics.context.len > 0:
        data.add(graphics.context[^1].name)

    data.add(details)

    graphics.actions.add(action & "(" & join(data, ", ") & ")")

macro record(action: string, elements: varargs[typed]) =
    result = newCall(bindSym("event"))
    result.add(action)
    for child in elements:
        result.add(
            nnkInfix.newTree(
                newIdentNode("&"),
                newLit(child.repr & ": "),
                nnkPrefix.newTree(newIdentNode("$"), child)
            )
        )

proc getFontHeight*(font: Font): int = font.height

proc getTextWidth*(font: Font, text: string, length: int, encoding: TextEncoding, tracking: int): int =
    assert(text.len == length)
    font.charWidth * length

proc fill*(font: Font): int = 12

proc fillRect*(graphics: PDGraphics, x, y, width, height: int; color: Color) =
    record("fillRect", x, y, width, height, color)

proc pushContext*(graphics: PDGraphics, img: Image) =
    graphics.context.add(img)

proc popContext*(graphics: PDGraphics) =
    graphics.context.setLen(graphics.context.len - 1)

proc getImage*(sprite: Sprite): Image = sprite.img

proc setFont*(graphics: PDGraphics, font: Font) =
    record("setFont", font.name)

proc setDrawMode*(graphics: PDGraphics, drawMode: DrawMode) =
    record("drawMode", drawMode)

proc drawText*(graphics: PDGraphics, text: string, x, y: int) =
    record("drawText", text, x, y)

proc draw*(bitmap: Image; x, y: int, flip: BitmapFlip) =
    let name = bitmap.name
    record("drawBitmap", name, x, y)

proc setMany*[W: static int](this: var Image, pixels: openarray[array[W, Color]]) =
    var asStr: string
    for i, row in pixels:
        if i > 0:
            asStr &= ";"
        for x in row:
            case x:
            of kColorBlack: asStr &= "X"
            of kColorWhite: asStr &= "."
    let img = this.name
    record("setMany", img, asStr)

proc asBool(color: Color): bool =
    case color
    of kColorWhite: return false
    of kColorBlack: return true

proc setPixel*(this: var ImageData, x, y: int; color: Color) =
    if x >= 0 and x < this.width:
        if y >= 0 and y < this.height:
            this.pixels[y][x] = color.asBool

proc width*(this: Image): auto = this.data.width

proc height*(this: Image): auto = this.data.height

proc clear*(this: var Image, color: Color) =
    for y in 0..<this.height:
        for x in 0..<this.width:
            this.data.pixels[y][x] = color.asBool

proc getDataObj*(this: Image): ImageData = this.data


proc `$`*(img: ImageData): string =
    result = newStringOfCap(img.width * img.height + img.height)
    for row in img.pixels:
        for x in row:
            if x:
                result &= "X"
            else:
                result &= "."
        result &= ";"

proc `$`*(img: Image): string = $img.data
