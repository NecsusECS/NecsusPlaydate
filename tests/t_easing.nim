import unittest, necsuspd/easing, options, vmath

template checkEasing(name: untyped, expect: seq[(float32, float32)]): untyped =
    for (input, output) in expect:
        check(`ease name`(input) == output)
        check(`calc name`(vec2(0, 0), vec2(1, 1), input) == vec2(output, output))

        let closure = `calc name`(Vec2)
        check(closure(vec2(0, 0), vec2(1, 1), input) == vec2(output, output))

suite "Easing functions":

    test "Linear easing":
        checkEasing(Linear, @[
            (0f, 0f),
            (0.5f, 0.5f),
            (1.0f, 1.0f),
        ])

    test "Sin easing":
        checkEasing(InOutSin, @[
            (0f, 0f),
            (0.25f, 0.1464466154575348f),
            (0.5f, 0.5f),
            (0.75f, 0.8535534143447876f),
            (1.0f, 1.0f),
        ])
