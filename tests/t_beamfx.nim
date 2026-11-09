import std/unittest, necsuspd/beamfx, vmath

suite "beamClip":
  test "grows the endpoints' bounding box by the spread":
    check beamClip(ivec2(20, 50), ivec2(60, 30), 5, 100) ==
      (ivec2(15, 25), ivec2(51, 31))

  test "is clamped to the image":
    check beamClip(ivec2(2, 90), ivec2(40, 98), 5, 100) == (ivec2(0, 85), ivec2(46, 15))

  test "is empty when the beam is entirely outside the image":
    check beamClip(ivec2(120, 130), ivec2(140, 150), 5, 100)[1] == ivec2(0, 0)
