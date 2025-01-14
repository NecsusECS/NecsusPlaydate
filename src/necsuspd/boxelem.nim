import sequtils, strformat, textwrap, alignment
export alignment

type
    BoxKind = enum TextElem, RowElem, StackElem, HorizLine, PadElem, BlankElem, ImgElem, MaxWidthElem

    BoxPad* = tuple[left, right, top, bottom: int32]

    BoxDimens* = tuple[width, height: int32]

    DrawArea = tuple[left, right, top: int32]

const defaultPad: BoxPad = (2, 2, 2, 2)

template defineBoxElem*[T](
    LCDFont, LCDBitmap, LCDSprite, LCDSolidColor, PDStringEncoding, LCDBitmapDrawMode, LCDBitmapFlip: typedesc,
    pdGraphics: T
) =

    type
        BoxElem* {.inject.} = ref object
            ## A box element that can be drawn on an image
            alignment: Alignment
            pad: BoxPad
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
            of MaxWidthElem:
                maxWidth: int32
                maxWidthInner: BoxElem

    proc `$`*(box: BoxElem): string =
        result = $box.kind & "("
        case box.kind
        of TextElem: result.add($box.text)
        of RowElem:
            for row in box.row:
                result.add($row & ", ")
        of StackElem:
            for stack in box.stack:
                result.add($stack & ", ")
        of HorizLine: discard
        of PadElem: result.add($box.pad & " " & $box.nested)
        of BlankElem: result.add($box.blank.width & "x" & $box.blank.height)
        of ImgElem: result.add($box.img.width & "x" & $box.img.height)
        of MaxWidthElem: result.add($box.maxWidth & " for " & $box.maxWidthInner)
        result.add(")")

    proc text*(
        text: string,
        font: LCDFont = nil,
        align: Alignment = AlignLeft,
        pad: BoxPad = defaultPad,
        wrap: bool = false,
        drawMode: LCDBitmapDrawMode = kDrawModeFillBlack
    ): BoxElem =
        ## Creates a text rendering element
        BoxElem(kind: TextElem, text: text, font: font, pad: pad, alignment: align, wrap: wrap, textMode: drawMode)

    proc row*(boxes: varargs[BoxElem]): BoxElem =
        ## Creates a row of draw boxes
        BoxElem(kind: RowElem, row: boxes.toSeq)

    proc stack*(boxes: varargs[BoxElem]): BoxElem =
        ## Creates a row of draw boxes
        BoxElem(kind: StackElem, stack: boxes.toSeq)

    proc horizLine*(thickness: int32 = 1, pad: BoxPad = defaultPad): BoxElem =
        ## Creates a horizontal line
        BoxElem(kind: HorizLine, pad: pad, thickness: thickness)

    proc pad*(left: int32 = 0, right: int32 = 0, top: int32 = 0, bottom: int32 = 0, nested: BoxElem): BoxElem =
        ## Creates a horizontal line
        BoxElem(kind: PadElem, pad: (left, right, top, bottom), nested: nested)

    proc pad*(nested: BoxElem, left: int32 = 0, right: int32 = 0, top: int32 = 0, bottom: int32 = 0): BoxElem =
        ## Creates a horizontal line
        pad(left, right, top, bottom, nested)

    proc blank*(width, height: int32): BoxElem =
        ## Creates a blank spacer element
        BoxElem(kind: BlankElem, blank: (width, height))

    proc minWidth*(base: BoxElem, width: int32): BoxElem =
        ## Creates a blank spacer element
        stack(blank(width, 0), base)

    proc img*(bitmap: LCDBitmap, align: Alignment = AlignLeft, mode: LCDBitmapDrawMode = kDrawModeCopy): BoxElem =
        ## Creates an box element from an image
        BoxElem(kind: ImgElem, img: bitmap, alignment: align, imgMode: mode)

    proc maxWidth*(width: int32, inner: BoxElem): BoxElem =
        ## Sets the max width to use for a nested element
        BoxElem(kind: MaxWidthElem, maxWidth: width, maxWidthInner: inner)

    proc maxWidth*(inner: BoxElem, width: int32): BoxElem = maxWidth(width, inner)
        ## Sets the max width to use for a nested element

    iterator textLines(box: BoxElem, font: LCDFont, maxWidth: int32): string =
        assert(box.kind == TextElem)
        if box.wrap == false:
            yield box.text
        else:
            proc getWidth(text: string): int32 =
                font.getTextWidth(text, text.len, PDStringEncoding.kUTF8Encoding, 0).int32
            for text in textwrap(box.text, maxWidth, getWidth):
                yield text

    proc recursiveDraw(
        executeDraw: static bool,
        box: BoxElem,
        img: LCDBitmap,
        defaultFont: LCDFont,
        area: DrawArea
    ): BoxDimens =
        let area: DrawArea = (
            left:   area.left   + box.pad.left,
            right:  area.right  - box.pad.right,
            top:    area.top    + box.pad.top,
        )

        case box.kind
        of TextElem:
            let font = if box.font == nil: defaultFont else: box.font

            when executeDraw:
                pdGraphics.setFont(font)
                pdGraphics.setDrawMode(box.textMode)

            result.height = area.top
            let fontHeight = getFontHeight(font).int32

            var lineSpacing = 0'i32
            for text in textLines(box, font, area.right - area.left):
                result.height += lineSpacing

                let width = font.getTextWidth(text, text.len, PDStringEncoding.kUTF8Encoding, 0).int32

                when executeDraw:
                    let x = box.alignment.calculateX(width, area.left, area.right)
                    pdGraphics.drawText(text, x, result.height)

                result.height += fontHeight
                result.width = max(result.width, width)

                if lineSpacing == 0:
                    lineSpacing = max(fontHeight div 4, 1)

        of RowElem:
            result.height = area.top
            result.width = area.left
            for nested in box.row:
                let nestedArea: DrawArea = (left: result.width, right: area.right, top: area.top)
                let drawn = recursiveDraw(executeDraw, nested, img, defaultFont, nestedArea)
                result.height = max(result.height, drawn.height)
                result.width += drawn.width

        of StackElem:
            result.height = area.top
            for nested in box.stack:
                let nestedArea: DrawArea = (left: area.left, right: area.right, top: result.height)
                let drawn = recursiveDraw(executeDraw, nested, img, defaultFont, nestedArea)
                result.height = drawn.height
                result.width = max(result.width, drawn.width)

        of HorizLine:
            when executeDraw:
                pdGraphics.fillRect(
                    area.left,
                    area.top,
                    area.right - area.left,
                    box.thickness,
                    LCDSolidColor.kColorBlack
                )
            result.height = area.top + box.thickness

        of PadElem:
            result = recursiveDraw(executeDraw, box.nested, img, defaultFont, area)

        of BlankElem:
            result.height = area.top + box.blank.height
            result.width = box.blank.width

        of ImgElem:
            when executeDraw:
                pdGraphics.setDrawMode(box.imgMode)
                let x = box.alignment.calculateX(box.img.width.int32, area.left, area.right)
                draw(box.img, x, area.top, LCDBitmapFlip.kBitmapUnflipped)
            result.height = area.top + box.img.height.int32
            result.width = box.img.width.int32

        of MaxWidthElem:
            let nestedSize = recursiveDraw(false, box.maxWidthInner, img, defaultFont, area)
            let maxWidth = min(nestedSize.width, box.maxWidth)
            let x = box.alignment.calculateX(maxWidth, area.left, area.right)
            let nestedArea: DrawArea = (left: x, right: x + maxWidth, top: area.top)
            result = recursiveDraw(executeDraw, box.maxWidthInner, img, defaultFont, nestedArea)

        result.height += box.pad.bottom
        result.width += box.pad.left + box.pad.right

    proc dimens*(box: BoxElem, defaultFont: LCDFont): BoxDimens =
        ## Returns the minimum dimensions required to draw this image
        recursiveDraw(false, box, default(LCDBitmap), defaultFont, (0'i32, high(int32), 0'i32))

    proc height*(box: BoxElem, defaultFont: LCDFont): int32 =
        ## Draws this text on the given sprite
        dimens(box, defaultFont).height

    proc draw*(box: BoxElem, img: LCDBitmap, defaultFont: LCDFont) =
        ## Draws this text on the given img
        pushContext(pdGraphics, img)
        defer: pdGraphics.popContext()
        let area = (0'i32, img.width.int32, 0'i32)
        discard recursiveDraw(true, box, img, defaultFont, area)

    proc draw*(box: BoxElem, img: LCDSprite, defaultFont: LCDFont) =
        ## Draws this text on the given img
        draw(box, img.getImage, defaultFont)

    proc newBitmap*(content: BoxElem, defaultFont: LCDFont, background: LCDSolidColor = kColorWhite): LCDBitmap =
        ## Creates a a bitmap from a box
        let size = content.dimens(defaultFont)
        result = pdGraphics.newBitmap(size.width, size.height, background)
        discard result.setBitmapMask()
        content.draw(result, defaultFont)

when not defined(unittests):
    import playdate/api
    defineBoxElem(
        LCDFont, LCDBitmap, LCDSprite, LCDSolidColor, PDStringEncoding, LCDBitmapDrawMode, LCDBitmapFlip,
        playdate.graphics
    )
