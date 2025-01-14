import unittest, necsus, necsuspd/inputs, std/[importutils, math]
import necsuspd/crankData {.all.}

proc buildAdjustor(angle: Shared[CrankAngle], delta: Shared[CrankDelta]): auto =
    return proc (by: float32) =
        var newAngle = (angle.get + by) mod 360
        while newAngle < 0:
            newAngle += 360
        angle := newAngle
        delta := by

runSystemOnce do (crank: Bundle[CrankData], angle: Shared[CrankAngle], delta: Shared[CrankDelta]) -> void:
    let adjustCrank = buildAdjustor(angle, delta)

    test "Negative crank position":
        check(crank.recalculateRotations == 0.0)

        adjustCrank(-10)
        check(crank.recalculateRotations == -10.0)

        adjustCrank(-360)
        check(crank.recalculateRotations == -370.0)

        adjustCrank(-180)
        check(crank.recalculateRotations == -550.0)

        adjustCrank(-355)
        check(crank.recalculateRotations == -905.0)

runSystemOnce do (crank: Bundle[CrankData], angle: Shared[CrankAngle], delta: Shared[CrankDelta]) -> void:
    let adjustCrank = buildAdjustor(angle, delta)

    test "Positive crank position":
        check(crank.recalculateRotations == 0.0)

        adjustCrank(10)
        check(crank.recalculateRotations == 10.0)

        adjustCrank(360)
        check(crank.recalculateRotations == 370.0)

        adjustCrank(180)
        check(crank.recalculateRotations == 550.0)

        adjustCrank(355)
        check(crank.recalculateRotations == 905.0)

runSystemOnce do (crank: Bundle[CrankData], angle: Shared[CrankAngle], delta: Shared[CrankDelta]) -> void:
    let adjustCrank = buildAdjustor(angle, delta)

    test "Crank back and forth over 0":
        check(crank.recalculateRotations == 0.0)

        adjustCrank(10)
        check(crank.recalculateRotations == 10.0)

        adjustCrank(-40)
        check(crank.recalculateRotations == -30.0)

        adjustCrank(80)
        check(crank.recalculateRotations == 50.0)

        adjustCrank(-50)
        check(crank.recalculateRotations == 0.0)

        adjustCrank(-10)
        check(crank.recalculateRotations == -10.0)

        adjustCrank(10)
        check(crank.recalculateRotations == 0.0)
