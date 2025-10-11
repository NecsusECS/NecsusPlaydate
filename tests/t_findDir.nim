import unittest, necsuspd/[findDir, fpvec], options, fixedpoint

suite "Find Dir":
  iterator entities(): auto =
    yield (fpvec2(0, 0), 1)
    yield (fpvec2(10, 0), 2)
    yield (fpvec2(10, 10), 3)
    yield (fpvec2(0, 10), 4)

  test "Finding values to the right of a position":
    check(findDir[int](entities, FindRight, fpvec2(5, 1)).get.value == 2)
    check(findDir[int](entities, FindRight, fpvec2(-5, 1)).get.value == 1)
    check(findDir[int](entities, FindRight, fpvec2(8, 8)).get.value == 3)
    check(findDir[int](entities, FindRight, fpvec2(12, 8)).isNone)

  test "Finding values to the left of a position":
    check(findDir[int](entities, FindLeft, fpvec2(5, 1)).get.value == 1)
    check(findDir[int](entities, FindLeft, fpvec2(-5, 1)).isNone)
    check(findDir[int](entities, FindLeft, fpvec2(8, 8)).get.value == 4)
    check(findDir[int](entities, FindLeft, fpvec2(12, 8)).get.value == 3)

  test "Finding values to up from a position":
    check(findDir[int](entities, FindUp, fpvec2(5, 3)).get.value == 1)
    check(findDir[int](entities, FindUp, fpvec2(-5, 3)).get.value == 1)
    check(findDir[int](entities, FindUp, fpvec2(8, 8)).get.value == 2)
    check(findDir[int](entities, FindUp, fpvec2(12, 8)).get.value == 2)
    check(findDir[int](entities, FindUp, fpvec2(3, 18)).get.value == 4)
    check(findDir[int](entities, FindUp, fpvec2(3, -5)).isNone)

  test "Finding values to up from a position":
    check(findDir[int](entities, FindDown, fpvec2(4, 3)).get.value == 4)
    check(findDir[int](entities, FindDown, fpvec2(-4, 3)).get.value == 4)
    check(findDir[int](entities, FindDown, fpvec2(8, 8)).get.value == 3)
    check(findDir[int](entities, FindDown, fpvec2(12, 8)).get.value == 3)
    check(findDir[int](entities, FindDown, fpvec2(3, 18)).isNone)
    check(findDir[int](entities, FindDown, fpvec2(3, -5)).get.value == 1)

  test "Finding values based on the angle even when far away":
    let elems = [(fpvec2(200, 60), 1), (fpvec2(108, 145), 2)]
    check(findDir[int](elems, FindRight, fpvec2(50, 60)).get.value == 1)
