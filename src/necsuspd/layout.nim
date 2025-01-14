import necsus, sequtils, positioned, options, vmath, alignment
export alignment

when defined(unittests):
    type Layouter*[T] = object
        get*: proc(eid: EntityId): Option[tuple[pos: ptr Positioned, sprite: T]] {.gcsafe, raises: [].}
else:
    import sprite
    type Layouter* = object
        get*: Lookup[tuple[pos: ptr Positioned, sprite: Sprite]]

type
    LayoutKind = enum SpriteLayout, CardLayout, StackLayout, RowLayout, PadLayout, HorizLayout

    LayoutElem* = ref object
        case kind: LayoutKind
        of HorizLayout:
            align: Alignment
            horizNested: LayoutElem
        of SpriteLayout:
            entityId: EntityId
        of CardLayout:
            columns: int32
            cards: seq[LayoutElem]
        of StackLayout:
            stack: seq[LayoutElem]
        of RowLayout:
            row: seq[LayoutElem]
        of PadLayout:
            padnested: LayoutElem
            padding: tuple[left, right, top, bottom: int32]

    LayoutArea = tuple[left, right, top: int32]

    LayoutDimens = tuple[width, height: int32]

proc horizLayout*(nested: LayoutElem, align: Alignment): LayoutElem =
    ## Horizontally aligns an element
    LayoutElem(kind: HorizLayout, horizNested: nested, align: align)

proc horizLayout*(align: Alignment, nested: LayoutElem): LayoutElem = nested.horizLayout(align)
    ## Horizontally aligns an element

proc spriteLayout*(entityId: EntityId, align: Alignment = AlignLeft): LayoutElem =
    ## Uses a sprite as a layout
    result = LayoutElem(kind: SpriteLayout, entityId: entityId)
    if align != AlignLeft:
        result = result.horizLayout(align)

proc cardLayout*(columns: int32, cards: seq[LayoutElem]): LayoutElem =
    ## Lays out a set of elements in a series of columns
    LayoutElem(kind: CardLayout, columns: columns, cards: cards)

proc cardLayout*(columns: int32, cards: varargs[LayoutElem]): LayoutElem =
    ## Lays out a set of elements in a series of columns
    cardLayout(columns, cards.toSeq)

proc stackLayout*(stack: varargs[LayoutElem]): LayoutElem =
    ## Stacks values on top of each other
    LayoutElem(kind: StackLayout, stack: stack.toSeq)

proc rowLayout*(row: varargs[LayoutElem]): LayoutElem =
    ## Aligns layout elements in a row
    LayoutElem(kind: RowLayout, row: row.toSeq)

proc padLayout*(sublayout: LayoutElem; left: int32 = 0, right: int32 = 0, top: int32 = 0, bottom: int32 = 0): LayoutElem =
    ## Aligns layout elements in a row
    LayoutElem(kind: PadLayout, padnested: sublayout, padding: (left: left, right: right, top: top, bottom: bottom))

proc padLayout*(left: int32 = 0, right: int32 = 0, top: int32 = 0, bottom: int32 = 0; sublayout: LayoutElem): LayoutElem =
    ## Aligns layout elements in a row
    padLayout(sublayout, left, right, top, bottom)

proc minWidth*[T](control: T, elem: LayoutElem): int32 =
    ## Calculates the minimum width for a view
    case elem.kind

    of HorizLayout:
        result = minWidth(control, elem.horizNested)

    of SpriteLayout:
        let entity = control.get(elem.entityId)
        result = if entity.isSome: get(entity).sprite.width.int32 else: 0'i32

    of CardLayout:
        result = 0
        var currentRow = 0'i32
        for i, card in elem.cards:

            if i mod elem.columns == 0:
                result = max(result, currentRow)
                currentRow = 0

            currentRow += minWidth(control, card)

        result = max(result, currentRow)

    of StackLayout:
        result = 0
        for child in elem.stack:
            result = max(result, minWidth(control, child))

    of RowLayout:
        result = 0
        for child in elem.row:
            result += minWidth(control, child)

    of PadLayout:
        result = minWidth(control, elem.padnested) + elem.padding.left + elem.padding.right

proc update[T](enact: static bool, control: T, elem: LayoutElem, area: LayoutArea): LayoutDimens =
    ## Recursively applies layout
    case elem.kind:

    of HorizLayout:
        var nestedArea = area
        let bounds =  elem.align.bounds(minWidth(control, elem), area.left, area.right)
        nestedArea.left = bounds.left
        nestedArea.right = bounds.right

        let (width, height) = update(enact, control, elem.horizNested, nestedArea)

        result.height = height
        result.width = case elem.align
            of AlignLeft: width
            of AlignCenter, AlignRight: area.right - area.left

    of SpriteLayout:
        let entity = control.get(elem.entityId)
        if entity.isSome:

            if enact:
                let newPos = ivec2(area.left.int32, area.top.int32)
                `pos=`(entity.get.pos, newPos)
                # echo "Layout: ", elem.entityId, " pos=", newPos, " area=", area

            return (entity.get.sprite.width.int32, entity.get.sprite.height.int32)
        else:
            return (0, 0)

    of CardLayout:
        var currentArea = area
        var nextRowTop = area.top
        var currentWidth = 0'i32
        for i, card in elem.cards:

            if i mod elem.columns == 0:
                currentArea.left = area.left
                currentArea.top = nextRowTop
                result.width = max(result.width, currentWidth)
                currentWidth = 0

            let (width, height) = update(enact, control, card, currentArea)
            nextRowTop = max(nextRowTop, currentArea.top + height)
            currentArea.left += width
            currentWidth += width

        result.width = max(result.width, currentWidth)
        result.height = nextRowTop - area.top

    of StackLayout:
        var currentArea = area
        for child in elem.stack:
            let (width, height) = update(enact, control, child, currentArea)
            currentArea.top += height
            result.width = max(result.width, width)
        result.height = currentArea.top - area.top

    of RowLayout:
        var currentArea = area
        for child in elem.row:
            let (width, height) = update(enact, control, child, currentArea)
            currentArea.left += width
            result.height = max(result.height, height)
        result.width = currentArea.left - area.left

    of PadLayout:
        let nestedArea = (
            left: area.left + elem.padding.left,
            right: area.right - elem.padding.right,
            top: area.top + elem.padding.top
        )
        let (width, height) = update(enact, control, elem.padnested, nestedArea)
        return (
            width: elem.padding.left + width + elem.padding.right,
            height: elem.padding.top + height + elem.padding.bottom
        )

proc dimens*[T](elem: LayoutElem, control: T, x, y, width: int32): LayoutDimens =
    ## Calculates the dimensions a layout will take without moving anything
    update(false, control, elem, (x, x + width, y))

proc layout*[T](elem: LayoutElem, control: T, x, y, width: int32): LayoutDimens {.discardable.} =
    ## Applies layout operations to a set of elements
    update(true, control, elem, (x, x + width, y))