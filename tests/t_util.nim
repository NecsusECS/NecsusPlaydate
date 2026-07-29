import std/unittest, necsuspd/util

type TestEnum = enum
  A
  B
  C

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

  test "Enum length":
    check(len(TestEnum) == 3)

  test "strToEnum":
    check(strToEnum[TestEnum]("A") == A)
    check(strToEnum[TestEnum]("B") == B)
    check(strToEnum[TestEnum]("C") == C)
    check(strToEnum[TestEnum]("D") == A)
    check(strToEnum[TestEnum]("D", B) == B)

  test "Compile time modification times":
    const
      thisFile = currentSourcePath()
      missing = thisFile & ".nope"

    check(static(modifiedTime(thisFile)) > 0)
    check(static(modifiedTime(missing)) == -1)

    # A missing artifact always needs building
    check(static(isOutOfDate(missing, thisFile)))

    # A file is never out of date against itself, or against sources that are gone
    check(not static(isOutOfDate(thisFile, thisFile)))
    check(not static(isOutOfDate(thisFile, missing)))
    check(not static(isOutOfDate(thisFile, [thisFile, missing])))
