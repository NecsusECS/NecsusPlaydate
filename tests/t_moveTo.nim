import unittest, necsuspd/[moveTo, easing], std/[importutils], vmath

suite "MovingTo":
  privateAccess(MovingTo)

  proc moveTo(
      origin, target: Vec2, startTime, duration: float32 = 16, easing: EasingFunc
  ): auto =
    return MovingTo(
      origin: origin,
      target: target,
      delta: target - origin,
      startTime: startTime,
      duration: duration,
      easingX: easing,
      easingY: easing,
    )

  test "Calculate the position of a movement":
    let movement = moveTo(vec2(0, 0), vec2(4, 8), 100, 16, easeLinear)

    check(movement.calculate(0) == (ivec2(0, 0), false))
    check(movement.calculate(100) == (ivec2(0, 0), false))
    check(movement.calculate(104) == (ivec2(1, 2), false))
    check(movement.calculate(108) == (ivec2(2, 4), false))
    check(movement.calculate(112) == (ivec2(3, 6), false))
    check(movement.calculate(116) == (ivec2(4, 8), true))
    check(movement.calculate(500) == (ivec2(4, 8), true))

  test "Using an alternate easing function":
    let movement = moveTo(vec2(0, 0), vec2(4, 8), 100, 16, easeInOutSin)

    check(movement.calculate(100) == (ivec2(0, 0), false))
    check(movement.calculate(104) == (ivec2(1, 1), false))
    check(movement.calculate(108) == (ivec2(2, 4), false))
    check(movement.calculate(112) == (ivec2(3, 7), false))
    check(movement.calculate(116) == (ivec2(4, 8), true))
