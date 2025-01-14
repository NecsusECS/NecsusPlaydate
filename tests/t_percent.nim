import std/unittest, necsuspd/percent

proc `==`(p: Percent, vs: SomeFloat): bool =
    return abs(p.toFloat - vs) < 0.001

suite "Percentile calculations":

    test "Int Percentage multiplication":
        let pct = percent(50, 100)

        check(8 * pct == 4)
        check(12 * pct == 6)

        check(pct * 8 == 4)
        check(pct * 12 == 6)

    test "Float percent multiplication":
        check(1.0 * percent(50, 100) == 0.5)
        check(20.0 * percent(50, 100) == 10.0)

    test "Combining Percentages":
        let pct = percent(50, 100) * percent(25, 100)
        check(32 * pct == 4)

    test "Percentages from floats":
        check(32 * percent(0.5) == 16)
        check(32 * percent(0.25) == 8)
        check(32 * percent(0.125) == 4)

    test "Comparisons":
        check(percent(10, 20) == percent(20, 40))
        check(percent(10, 20) != percent(10, 40))
        check(percent(1, 4) < percent(1, 2))

    test "Invert":
        check(percent(1, 4).invert == percent(3, 4))

    test "To float":
        check(percent(1, 4) == 0.25)

    test "To a power":
        check(percent(12, 10) ^ 0 == 1.0)
        check(percent(12, 10) ^ 1 == 1.2)
        check(percent(12, 10) ^ 2 == 1.44)
        check(percent(12, 10) ^ 3 == 1.728)
