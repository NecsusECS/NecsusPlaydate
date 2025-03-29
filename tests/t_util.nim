import std/unittest, necsuspd/util

suite "Utilities":
  test "Loop unrolling":
    var output: seq[(int32, string)]
    const inputs = ["a", "b", "c"]
    unroll i, value, inputs:
      output.add((i, value))
    check(output == @[(0'i32, "a"), (1'i32, "b"), (2'i32, "c")])
