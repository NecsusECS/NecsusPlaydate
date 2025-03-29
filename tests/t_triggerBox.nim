import unittest, necsuspd/[positioned, triggerBox], vmath

type ZIndex = enum
  Example

suite "TriggerBox":
  test "Overlap without any offset":
    let box = (triggerBox(20, 40, ZIndex.Example), positioned(50, 100))

    check(box.tLocation(ivec2(50, 100)) == vec2(0.0, 0.0))
    check(box.tLocation(ivec2(70, 140)) == vec2(1.0, 1.0))
    check(box.tLocation(ivec2(60, 140)) == vec2(0.5, 1.0))
    check(box.tLocation(ivec2(50, 110)) == vec2(0.0, 0.25))

  test "Points outside of the box":
    let box = (triggerBox(20, 40, ZIndex.Example), positioned(50, 100))

    check(box.tLocation(ivec2(20, 60)) == vec2(-1.5, -1.0))
    check(box.tLocation(ivec2(80, 150)) == vec2(1.5, 1.25))

  test "Points with an offset":
    let box = (triggerBox(20, 40, ZIndex.Example, ivec2(10, 0)), positioned(40, 100))

    check(box.tLocation(ivec2(50, 100)) == vec2(0.0, 0.0))
    check(box.tLocation(ivec2(70, 140)) == vec2(1.0, 1.0))
    check(box.tLocation(ivec2(60, 140)) == vec2(0.5, 1.0))
    check(box.tLocation(ivec2(50, 110)) == vec2(0.0, 0.25))
