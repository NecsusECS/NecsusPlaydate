import std/unittest, necsuspd/util

suite "Utilities":
  test "Loop unrolling":
    var output: seq[(int32, string)]
    const inputs = ["a", "b", "c"]
    unroll i, value, inputs:
      output.add((i, value))
    check(output == @[(0'i32, "a"), (1'i32, "b"), (2'i32, "c")])

  test "Integer square roots":
    check(isqrt(0) == 0)
    check(isqrt(1) == 1)
    check(isqrt(4) == 2)
    check(isqrt(8) == 2)
    check(isqrt(9) == 3)
    check(isqrt(10) == 3)
