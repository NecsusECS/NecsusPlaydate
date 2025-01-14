import unittest, necsuspd/[findDir, positioned], options

suite "Find Dir":
    iterator entities(): auto =
        yield (positioned(0, 0),   1)
        yield (positioned(10, 0),  2)
        yield (positioned(10, 10), 3)
        yield (positioned(0, 10),  4)

    test "Finding values to the right of a position":
        check(findDir[int](entities, FindRight, positioned(5, 1)).get.value == 2)
        check(findDir[int](entities, FindRight, positioned(-5, 1)).get.value == 1)
        check(findDir[int](entities, FindRight, positioned(8, 8)).get.value == 3)
        check(findDir[int](entities, FindRight, positioned(12, 8)).isNone)

    test "Finding values to the left of a position":
        check(findDir[int](entities, FindLeft, positioned(5, 1)).get.value == 1)
        check(findDir[int](entities, FindLeft, positioned(-5, 1)).isNone)
        check(findDir[int](entities, FindLeft, positioned(8, 8)).get.value == 4)
        check(findDir[int](entities, FindLeft, positioned(12, 8)).get.value == 3)

    test "Finding values to up from a position":
        check(findDir[int](entities, FindUp, positioned(5, 3)).get.value == 1)
        check(findDir[int](entities, FindUp, positioned(-5, 3)).get.value == 1)
        check(findDir[int](entities, FindUp, positioned(8, 8)).get.value == 2)
        check(findDir[int](entities, FindUp, positioned(12, 8)).get.value == 2)
        check(findDir[int](entities, FindUp, positioned(3, 18)).get.value == 4)
        check(findDir[int](entities, FindUp, positioned(3, -5)).isNone)

    test "Finding values to up from a position":
        check(findDir[int](entities, FindDown, positioned(4, 3)).get.value == 4)
        check(findDir[int](entities, FindDown, positioned(-4, 3)).get.value == 4)
        check(findDir[int](entities, FindDown, positioned(8, 8)).get.value == 3)
        check(findDir[int](entities, FindDown, positioned(12, 8)).get.value == 3)
        check(findDir[int](entities, FindDown, positioned(3, 18)).isNone)
        check(findDir[int](entities, FindDown, positioned(3, -5)).get.value == 1)
