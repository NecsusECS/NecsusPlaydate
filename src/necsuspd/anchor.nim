import vmath

type
  AnchorLock* = enum
    AnchorTopLeft
    AnchorTopMiddle
    AnchorTopRight
    AnchorMiddle
    AnchorBottomLeft
    AnchorBottomMiddle
    AnchorBottomRight

  Anchor* = tuple[lock: AnchorLock, offset: IVec2]

  AnchorPosition* = Anchor | AnchorLock

template resolver(lock: AnchorLock, left, center, right, top, middle, bottom: int32): IVec2 =
  block:
    var output: IVec2
    case lock
    of AnchorTopLeft, AnchorBottomLeft:
      output.x = left
    of AnchorTopMiddle, AnchorMiddle, AnchorBottomMiddle:
      output.x = center
    of AnchorTopRight, AnchorBottomRight:
      output.x = right

    case lock
    of AnchorTopLeft, AnchorTopMiddle, AnchorTopRight:
      output.y = top
    of AnchorMiddle:
      output.y = middle
    of AnchorBottomLeft, AnchorBottomMiddle, AnchorBottomRight:
      output.y = bottom

    output

template resolve*(lock: AnchorLock, width, height: int32): IVec2 =
  ## Calculates the resolved position of an anchor lock
  resolver(lock, 0, width div 2, width, 0, height div 2, height)

template resolveFromCenter*(lock: AnchorLock, width, height: int32): IVec2 =
  ## Calculates the resolved position of an anchor lock
  resolver(lock, width div 2, 0, -(width div 2), height div 2, 0, -(height div 2))

proc toAnchor*(anchor: AnchorPosition): Anchor {.inline.} =
  when anchor is AnchorLock:
    return (anchor, ivec2(0, 0))
  else:
    return anchor
