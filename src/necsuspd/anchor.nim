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

template resolve*(lock: AnchorLock, width, height: int32): IVec2 =
  ## Calculates the resolved position of an anchor lock
  block:
    var output: IVec2
    case lock
    of AnchorTopLeft, AnchorBottomLeft:
      output.x = width div 2
    of AnchorTopMiddle, AnchorMiddle, AnchorBottomMiddle:
      discard
    of AnchorTopRight, AnchorBottomRight:
      output.x = -(width div 2)

    case lock
    of AnchorTopLeft, AnchorTopMiddle, AnchorTopRight:
      output.y = height div 2
    of AnchorMiddle:
      discard
    of AnchorBottomLeft, AnchorBottomMiddle, AnchorBottomRight:
      output.y = -(height div 2)

    output

proc toAnchor*(anchor: AnchorPosition): Anchor {.inline.} =
  when anchor is AnchorLock:
    return (anchor, ivec2(0, 0))
  else:
    return anchor
