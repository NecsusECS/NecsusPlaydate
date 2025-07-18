import std/[unittest, math], necsuspd/fixedpoint

template defineTests(p: static Natural) =
  suite "Fixed point math at precision " & $p:
    proc `==`(found: FPInt32, expect: SomeNumber): bool =
      return abs(found.toFloat32 - expect.float32) < (1.0 / (10.0 * p))

    test "Addition":
      check 1.fp(p) + 1.fp(p) == 2.fp(p)
      check 1.5.fp(p) + 1.2.fp(p) == 2.7.fp(p)

    test "Subtraction":
      check 1.fp(p) - 1.fp(p) == 0.0
      check 1.5.fp(p) - 1.2.fp(p) == 0.3

    test "Less than":
      check 1.fp(p) < 2.fp(p)
      check 1.fp(p) < 8.fp(p)
      check 1.5.fp(p) < 2.5.fp(p)
      check 1.5.fp(p) < 8.5.fp(p)

    test "Greater than":
      check 2.fp(p) > 1.fp(p)
      check 8.fp(p) > 1.fp(p)
      check 2.5.fp(p) > 1.5.fp(p)
      check 8.5.fp(p) > 1.5.fp(p)

    test "Less than equal to":
      check 1.fp(p) <= 2.fp(p)
      check 1.fp(p) <= 8.fp(p)
      check 1.5.fp(p) <= 2.5.fp(p)
      check 1.5.fp(p) <= 8.5.fp(p)
      check 1.fp(p) <= 1.fp(p)

    test "Multiply":
      check 2.fp(p) * 4.fp(p) == 8.fp(p)
      check 2.5.fp(p) * 4.5.fp(p) == 11.25.fp(p)

    test "Divide":
      check 8.fp(p) / 4.fp(p) == 2.fp(p)
      check 11.25.fp(p) / 4.5.fp(p) == 2.5.fp(p)

    test "In place operators":
      var a = 2.fp(p)

      a += 3.fp(p)
      check a == 5.fp(p)

      a -= 1.fp(p)
      check a == 4.fp(p)

      a *= 2.fp(p)
      check a == 8.fp(p)

      a /= 4.fp(p)
      check a == 2.fp(p)

    test "toInt32":
      check 1.fp(p).toInt32 == 1
      check 1.5.fp(p).toInt32 == 1
      check 2.fp(p).toInt32 == 2

    test "toFloat32":
      check 1.fp(p) == 1.0
      check 1.7.fp(p) == 1.7

    test "Square root":
      for i in 0 .. 100:
        check almostEqual(sqrt(i.fp(p)), sqrt(i.float32).fp(p))

    test "arctan2":
      let arc = arctan2(1.fp(p), 1.fp(p))
      # check almostEqual(arctan2(1.fp(p), 1.fp(p)), PI / 4.fp(p))
      # check almostEqual(arctan2(1.fp(p), -1.fp(p)), 3 * PI / 4.fp(p))
      # check almostEqual(arctan2(-1.fp(p), 1.fp(p)), -PI / 4.fp(p))
      # check almostEqual(arctan2(-1.fp(p), -1.fp(p)), -3 * PI / 4.fp(p))

defineTests(4)
defineTests(8)
defineTests(16)

suite "Variable fixed point precision":
  test "High":
    check high(FPInt32[4]).toFloat32 == 134217728.0
    check high(FPInt32[8]).toFloat32 == 8388608.0
    check high(FPInt32[16]).toFloat32 == 32768.0

  test "Low":
    check low(FPInt32[4]).toFloat32 == -134217728.0
    check low(FPInt32[8]).toFloat32 == -8388608.0
    check low(FPInt32[16]).toFloat32 == -32768.0
