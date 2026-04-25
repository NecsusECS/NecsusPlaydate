import sequtils, textwrap, alignment, import_playdate, drawable
export alignment

type
  BoxKind = enum
    TextElem
    RowElem
    StackElem
    HorizLine
    PadElem
    BlankElem
    ImgElem

  BoxPad* = tuple[left, right, top, bottom: int32]

  BoxDimens* = tuple[width, height: int32]

  DrawArea = tuple[left, right, top: int32]

  BoxSizeKind* = enum
    NaturalWidth
    FixedWidth
    FullWidth
    MinWidth
    MaxWidth
    RangeWidth

  BoxSize* = object
    case kind*: BoxSizeKind
    of NaturalWidth, FullWidth:
      discard
    of FixedWidth, MinWidth, MaxWidth:
      width*: int32
    of RangeWidth:
      minW*, maxW*: int32

const defaultPad: BoxPad = (2, 2, 2, 2)

type BoxElem* {.inject.} = ref object ## A box element that can be drawn on an image
  alignment: Alignment
  pad: BoxPad
  size: BoxSize
  case kind: BoxKind
  of TextElem:
    textMode: LCDBitmapDrawMode
    text: string
    font: LCDFont
    wrap: bool
  of RowElem:
    row: seq[BoxElem]
  of StackElem:
    stack: seq[BoxElem]
  of HorizLine:
    thickness: int32
  of PadElem:
    nested: BoxElem
  of BlankElem:
    blank: BoxDimens
  of ImgElem:
    img: LCDBitmap
    imgMode: LCDBitmapDrawMode

proc `$`*(box: BoxElem): string =
  result = $box.kind & "("
  case box.kind
  of TextElem:
    result.add($box.text)
  of RowElem:
    for row in box.row:
      result.add($row & ", ")
  of StackElem:
    for stack in box.stack:
      result.add($stack & ", ")
  of HorizLine:
    discard
  of PadElem:
    result.add($box.pad & " " & $box.nested)
  of BlankElem:
    result.add($box.blank.width & "x" & $box.blank.height)
  of ImgElem:
    result.add($box.img.width & "x" & $box.img.height)
  result.add(")")

proc text*(
    text: string,
    font: LCDFont = nil,
    align: Alignment = AlignLeft,
    pad: BoxPad = defaultPad,
    wrap: bool = false,
    drawMode: LCDBitmapDrawMode = kDrawModeFillBlack,
): BoxElem =
  ## Creates a text rendering element
  BoxElem(
    kind: TextElem,
    text: text,
    font: font,
    pad: pad,
    alignment: align,
    wrap: wrap,
    textMode: drawMode,
  )

proc row*(boxes: varargs[BoxElem]): BoxElem =
  ## Creates a row of draw boxes
  BoxElem(kind: RowElem, row: boxes.toSeq)

proc stack*(boxes: varargs[BoxElem]): BoxElem =
  ## Creates a stack of draw boxes
  BoxElem(kind: StackElem, stack: boxes.toSeq)

proc horizLine*(thickness: int32 = 1, pad: BoxPad = defaultPad): BoxElem =
  ## Creates a horizontal line
  BoxElem(kind: HorizLine, pad: pad, thickness: thickness)

proc pad*(
    left: int32 = 0,
    right: int32 = 0,
    top: int32 = 0,
    bottom: int32 = 0,
    nested: BoxElem,
): BoxElem =
  ## Wraps an element with padding
  BoxElem(kind: PadElem, pad: (left, right, top, bottom), nested: nested)

proc pad*(
    nested: BoxElem,
    left: int32 = 0,
    right: int32 = 0,
    top: int32 = 0,
    bottom: int32 = 0,
): BoxElem =
  ## Wraps an element with padding
  pad(left, right, top, bottom, nested)

proc blank*(width, height: int32): BoxElem =
  ## Creates a blank spacer element
  BoxElem(kind: BlankElem, blank: (width, height))

proc img*(
    bitmap: LCDBitmap,
    align: Alignment = AlignLeft,
    mode: LCDBitmapDrawMode = kDrawModeCopy,
): BoxElem =
  ## Creates a box element from an image
  BoxElem(kind: ImgElem, img: bitmap, alignment: align, imgMode: mode)

proc withSize*(box: BoxElem, size: BoxSize): BoxElem =
  ## Sets the size constraint on a box element (builder-style, mutates and returns)
  box.size = size
  box

proc maxWidth*(width: int32, inner: BoxElem): BoxElem =
  ## Constrains the maximum width of an element
  inner.withSize(BoxSize(kind: MaxWidth, width: width))

proc maxWidth*(inner: BoxElem, width: int32): BoxElem =
  ## Constrains the maximum width of an element
  maxWidth(width, inner)

proc minWidth*(base: BoxElem, width: int32): BoxElem =
  ## Enforces a minimum reported width on an element
  base.withSize(BoxSize(kind: MinWidth, width: width))

proc fixedWidth*(width: int32, inner: BoxElem): BoxElem =
  ## Forces an element to render at exactly the given width
  inner.withSize(BoxSize(kind: FixedWidth, width: width))

proc fixedWidth*(inner: BoxElem, width: int32): BoxElem =
  ## Forces an element to render at exactly the given width
  fixedWidth(width, inner)

proc fullWidth*(inner: BoxElem): BoxElem =
  ## Makes an element claim the full available width
  inner.withSize(BoxSize(kind: FullWidth))

proc rangeWidth*(minW, maxW: int32, inner: BoxElem): BoxElem =
  ## Constrains an element's width to the given range
  inner.withSize(BoxSize(kind: RangeWidth, minW: minW, maxW: maxW))

proc rangeWidth*(inner: BoxElem, minW, maxW: int32): BoxElem =
  ## Constrains an element's width to the given range
  rangeWidth(minW, maxW, inner)

iterator textLines(box: BoxElem, font: LCDFont, maxWidth: int32): string =
  assert(box.kind == TextElem)
  if box.wrap == false:
    yield box.text
  else:
    proc getWidth(text: string): int32 =
      font.getTextWidth(text, text.len, PDStringEncoding.kUTF8Encoding, 0).int32

    for text in textwrap(box.text, maxWidth, getWidth):
      yield text

proc renderText(
    executeDraw: static bool, box: BoxElem, defaultFont: LCDFont, area: DrawArea
): BoxDimens =
  let font = if box.font == nil: defaultFont else: box.font

  when executeDraw:
    playdate.graphics.setFont(font)
    playdate.graphics.setDrawMode(box.textMode)

  result.height = area.top
  let fontHeight = getFontHeight(font).int32

  var lineSpacing = 0'i32
  for text in textLines(box, font, area.right - area.left):
    result.height += lineSpacing

    let width =
      font.getTextWidth(text, text.len, PDStringEncoding.kUTF8Encoding, 0).int32

    when executeDraw:
      let x = box.alignment.calculateX(width, area.left, area.right)
      playdate.graphics.drawText(text, x, result.height)

    result.height += fontHeight
    result.width = max(result.width, width)

    if lineSpacing == 0:
      lineSpacing = max(fontHeight div 4, 1)

# Forward declared because recursiveDraw and recursiveDrawInner are mutually recursive:
# recursiveDraw dispatches on size constraints and calls recursiveDrawInner to render,
# while recursiveDrawInner calls recursiveDraw on child elements so children get their
# own size constraints applied.
proc recursiveDraw(
  executeDraw: static bool,
  box: BoxElem,
  img: LCDBitmap,
  defaultFont: LCDFont,
  area: DrawArea,
): BoxDimens

proc renderRow(
    executeDraw: static bool,
    box: BoxElem,
    img: LCDBitmap,
    defaultFont: LCDFont,
    area: DrawArea,
): BoxDimens =
  result.height = area.top
  result.width = area.left

  # Pass 1: measure total width of right-aligned children so they can be right-docked
  var rightWidth = 0'i32
  for nested in box.row:
    if nested.alignment == AlignRight:
      let measured = recursiveDraw(false, nested, img, defaultFont, area)
      rightWidth += measured.width

  let rightStart = area.right - rightWidth
  var rightOffset = 0'i32

  # Pass 2: draw left-aligned children from the left, right-aligned from the right
  for nested in box.row:
    if nested.alignment != AlignRight:
      let nestedArea: DrawArea = (left: result.width, right: area.right, top: area.top)
      let drawn = recursiveDraw(executeDraw, nested, img, defaultFont, nestedArea)
      result.height = max(result.height, drawn.height)
      result.width += drawn.width
    else:
      let x = rightStart + rightOffset
      let nestedArea: DrawArea = (left: x, right: area.right, top: area.top)
      let drawn = recursiveDraw(executeDraw, nested, img, defaultFont, nestedArea)
      result.height = max(result.height, drawn.height)
      rightOffset += drawn.width

  result.width += rightWidth

proc recursiveDrawInner(
    executeDraw: static bool,
    box: BoxElem,
    img: LCDBitmap,
    defaultFont: LCDFont,
    area: DrawArea,
): BoxDimens =
  ## Applies padding and renders content for a box element. Does NOT apply the element's
  ## size constraint — called by recursiveDraw either directly (NaturalWidth) or after the
  ## area has already been constrained (MaxWidth, RangeWidth), to avoid re-entering the
  ## size dispatch and looping.
  let area: DrawArea = (
    left: area.left + box.pad.left,
    right: area.right - box.pad.right,
    top: area.top + box.pad.top,
  )

  case box.kind
  of TextElem:
    result = renderText(executeDraw, box, defaultFont, area)
  of RowElem:
    result = renderRow(executeDraw, box, img, defaultFont, area)
  of StackElem:
    result.height = area.top
    for nested in box.stack:
      let nestedArea: DrawArea =
        (left: area.left, right: area.right, top: result.height)
      let drawn = recursiveDraw(executeDraw, nested, img, defaultFont, nestedArea)
      result.height = drawn.height
      result.width = max(result.width, drawn.width)
  of HorizLine:
    when executeDraw:
      playdate.graphics.fillRect(
        area.left,
        area.top,
        area.right - area.left,
        box.thickness,
        LCDSolidColor.kColorBlack,
      )
    result.height = area.top + box.thickness
  of PadElem:
    result = recursiveDraw(executeDraw, box.nested, img, defaultFont, area)
  of BlankElem:
    result.height = area.top + box.blank.height
    result.width = box.blank.width
  of ImgElem:
    when executeDraw:
      playdate.graphics.setDrawMode(box.imgMode)
      let x = box.alignment.calculateX(box.img.width.int32, area.left, area.right)
      draw(box.img, x, area.top, LCDBitmapFlip.kBitmapUnflipped)
    result.height = area.top + box.img.height.int32
    result.width = box.img.width.int32

  result.height += box.pad.bottom
  result.width += box.pad.left + box.pad.right

proc recursiveDraw(
    executeDraw: static bool,
    box: BoxElem,
    img: LCDBitmap,
    defaultFont: LCDFont,
    area: DrawArea,
): BoxDimens =
  ## Entry point for rendering. Applies the element's BoxSize constraint to the draw area,
  ## then delegates to recursiveDrawInner. For MaxWidth and RangeWidth, calls
  ## recursiveDrawInner first with the unconstrained area to measure natural dimensions,
  ## then again with the clamped area.
  case box.size.kind
  of NaturalWidth:
    result = recursiveDrawInner(executeDraw, box, img, defaultFont, area)
  of FullWidth:
    result = recursiveDrawInner(executeDraw, box, img, defaultFont, area)
    result.width = area.right - area.left
  of FixedWidth:
    let constrainedArea: DrawArea = (area.left, area.left + box.size.width, area.top)
    result = recursiveDrawInner(executeDraw, box, img, defaultFont, constrainedArea)
    result.width = box.size.width
  of MinWidth:
    result = recursiveDrawInner(executeDraw, box, img, defaultFont, area)
    result.width = max(result.width, box.size.width)
  of MaxWidth:
    let natural = recursiveDrawInner(false, box, img, defaultFont, area)
    let w = min(natural.width, box.size.width)
    let x = box.alignment.calculateX(w, area.left, area.right)
    let constrainedArea: DrawArea = (x, x + w, area.top)
    result = recursiveDrawInner(executeDraw, box, img, defaultFont, constrainedArea)
  of RangeWidth:
    let natural = recursiveDrawInner(false, box, img, defaultFont, area)
    let w = min(natural.width, box.size.maxW)
    let x = box.alignment.calculateX(w, area.left, area.right)
    let constrainedArea: DrawArea = (x, x + w, area.top)
    result = recursiveDrawInner(executeDraw, box, img, defaultFont, constrainedArea)
    result.width = max(result.width, box.size.minW)

proc dimens*(box: BoxElem, defaultFont: LCDFont): BoxDimens =
  ## Returns the minimum dimensions required to draw this image
  recursiveDraw(
    false, box, default(LCDBitmap), defaultFont, (0'i32, high(int32), 0'i32)
  )

proc height*(box: BoxElem, defaultFont: LCDFont): int32 =
  ## Draws this text on the given sprite
  dimens(box, defaultFont).height

proc draw*(box: BoxElem, img: LCDBitmap, defaultFont: LCDFont) =
  ## Draws this text on the given img
  pushContext(playdate.graphics, img)
  defer:
    playdate.graphics.popContext()
  let area = (0'i32, img.width.int32, 0'i32)
  discard recursiveDraw(true, box, img, defaultFont, area)

proc draw*(box: BoxElem, sprite: auto, defaultFont: LCDFont) =
  ## Draws this text on the given img
  draw(box, sprite.getImage, defaultFont)

proc newBitmap*(
    content: BoxElem, defaultFont: LCDFont, background: LCDSolidColor = kColorWhite
): LCDBitmap =
  ## Creates a a bitmap from a box
  let size = content.dimens(defaultFont)
  result = playdate.graphics.newBitmap(size.width, size.height, background)
  discard result.setBitmapMask()
  content.draw(result, defaultFont)
