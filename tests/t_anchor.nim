import unittest, necsuspd/anchor, vmath

suite "AnchorLock resolveFromCenter":
  test "AnchorTopLeft":
    check resolveFromCenter(AnchorTopLeft, 100, 50) == ivec2(50, 25)
    check resolve(AnchorTopLeft, 100, 50) == ivec2(0, 0)

  test "AnchorTopMiddle":
    check resolveFromCenter(AnchorTopMiddle, 100, 50) == ivec2(0, 25)
    check resolve(AnchorTopMiddle, 100, 50) == ivec2(50, 0)

  test "AnchorTopRight":
    check resolveFromCenter(AnchorTopRight, 100, 50) == ivec2(-50, 25)
    check resolve(AnchorTopRight, 100, 50) == ivec2(100, 0)

  test "AnchorMiddle":
    check resolveFromCenter(AnchorMiddle, 100, 50) == ivec2(0, 0)
    check resolve(AnchorMiddle, 100, 50) == ivec2(50, 25)

  test "AnchorBottomLeft":
    check resolveFromCenter(AnchorBottomLeft, 100, 50) == ivec2(50, -25)
    check resolve(AnchorBottomLeft, 100, 50) == ivec2(0, 50)

  test "AnchorBottomMiddle":
    check resolveFromCenter(AnchorBottomMiddle, 100, 50) == ivec2(0, -25)
    check resolve(AnchorBottomMiddle, 100, 50) == ivec2(50, 50)

  test "AnchorBottomRight":
    check resolveFromCenter(AnchorBottomRight, 100, 50) == ivec2(-50, -25)
    check resolve(AnchorBottomRight, 100, 50) == ivec2(100, 50)

suite "toAnchor":
  test "from AnchorLock":
    check toAnchor(AnchorTopLeft).lock == AnchorTopLeft
    check toAnchor(AnchorTopLeft).offset == ivec2(0, 0)

  test "from Anchor tuple":
    check toAnchor((AnchorBottomRight, ivec2(7, -3))).lock == AnchorBottomRight
    check toAnchor((AnchorBottomRight, ivec2(7, -3))).offset == ivec2(7, -3)
