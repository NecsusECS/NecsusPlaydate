import std/[unittest, math], necsuspd/easing, options, vmath

template checkEasing(name: untyped, expect: seq[(float32, float32)]): untyped =
  for (input, output) in expect:
    check(`ease name`(input) == output)
    check(`calc name`(vec2(0, 0), vec2(1, 1), input) == vec2(output, output))

    let closure = `calc name`(Vec2)
    check(closure(vec2(0, 0), vec2(1, 1), input) == vec2(output, output))

suite "Easing functions":
  test "Linear easing":
    checkEasing(Linear, @[(0f, 0f), (0.5f, 0.5f), (1.0f, 1.0f)])

  test "Sin easing":
    checkEasing(
      InOutSin,
      @[
        (0f, 0f),
        (0.25f, 0.1464466154575348f),
        (0.5f, 0.5f),
        (0.75f, 0.8535534143447876f),
        (1.0f, 1.0f),
      ],
    )

  test "Boomerang easing":
    let ease = easeLinearBoomerang
    check(ease(0.0) == 0.0'f32)
    check(ease(0.1) == 0.2'f32)
    check(ease(0.3) == 0.6'f32)
    check(ease(0.5) == 1.0'f32)
    check(almostEqual(ease(0.6), 0.8'f32))
    check(almostEqual(ease(0.8), 0.4'f32))
    check(ease(1.0) == 0.0'f32)
