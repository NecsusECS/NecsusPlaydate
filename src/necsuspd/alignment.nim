type Alignment* = enum
  AlignLeft
  AlignCenter
  AlignRight

const AlignTop* = AlignLeft
const AlignBottom* = AlignRight

proc bounds*(
    alignment: Alignment, elementWidth, left, right: int32
): tuple[left, right: int32] =
  ## Returns the X coordinate needed to align an element of the given width
  case alignment
  of AlignLeft:
    result = (left, right)
  of AlignRight:
    result = (right - elementWidth, right)
  of AlignCenter:
    let halfAreaWidth = (right - left) div 2
    let halfBodyWidth = elementWidth div 2
    result.left = left + halfAreaWidth - halfBodyWidth
    result.right = result.left + elementWidth

proc calculateX*(alignment: Alignment, elementWidth, left, right: int32): int32 =
  ## Returns the X coordinate needed to align an element of the given width
  bounds(alignment, elementWidth, left, right).left

proc alignment1d*[T](size: T, alignment: Alignment): T =
  ## Returns the 0 rooted alignment of an element of the given width
  return
    case alignment
    of AlignLeft:
      0
    of AlignRight:
      size
    of AlignCenter:
      size div 2

proc alignment2d*(size: auto, horizAlign, vertAlign: Alignment): auto =
  ## Returns the 0 rooted alignment of an element of the given size
  return
    (x: alignment1d(size.width, horizAlign), y: alignment1d(size.height, vertAlign))
