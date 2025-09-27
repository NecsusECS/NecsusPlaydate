import unittest, necsuspd/anchor, vmath

suite "AnchorLock resolve":
  test "AnchorTopLeft":
    check resolve(AnchorTopLeft, 100, 50) == ivec2(50, 25)

  test "AnchorTopMiddle":
    check resolve(AnchorTopMiddle, 100, 50) == ivec2(0, 25)

  test "AnchorTopRight":
    check resolve(AnchorTopRight, 100, 50) == ivec2(-50, 25)

  test "AnchorMiddle":
    check resolve(AnchorMiddle, 100, 50) == ivec2(0, 0)

  test "AnchorBottomLeft":
    check resolve(AnchorBottomLeft, 100, 50) == ivec2(50, -25)

  test "AnchorBottomMiddle":
    check resolve(AnchorBottomMiddle, 100, 50) == ivec2(0, -25)

  test "AnchorBottomRight":
    check resolve(AnchorBottomRight, 100, 50) == ivec2(-50, -25)

suite "toAnchor":
  test "from AnchorLock":
    check toAnchor(AnchorTopLeft).lock == AnchorTopLeft
    check toAnchor(AnchorTopLeft).offset == ivec2(0, 0)

  test "from Anchor tuple":
    check toAnchor((AnchorBottomRight, ivec2(7, -3))).lock == AnchorBottomRight
    check toAnchor((AnchorBottomRight, ivec2(7, -3))).offset == ivec2(7, -3)
