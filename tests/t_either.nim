import std/[unittest, options], necsuspd/either

suite "Either":
  test "isLeft / isRight":
    let l = left[string, int]("err")
    let r = right[string, int](42)
    check l.isLeft
    check not l.isRight
    check r.isRight
    check not r.isLeft

  test "getLeft returns the left value":
    let e = left[string, int]("err")
    check e.getLeft == "err"

  test "getRight returns the right value":
    let e = right[string, int](42)
    check e.getRight == 42

  test "leftOr returns left value when Left":
    let e = left[string, int]("err")
    check e.leftOr == "err"

  test "leftOr returns default when Right":
    let e = right[string, int](42)
    check e.leftOr == ""

  test "leftOr returns provided fallback when Right":
    let e = right[string, int](42)
    check e.leftOr("fallback") == "fallback"

  test "rightOr returns right value when Right":
    let e = right[string, int](42)
    check e.rightOr == 42

  test "rightOr returns default when Left":
    let e = left[string, int]("err")
    check e.rightOr == 0

  test "rightOr returns provided fallback when Left":
    let e = left[string, int]("err")
    check e.rightOr(-1) == -1

  test "applyLeft executes body only for Left":
    var seen: seq[string]
    left[string, int]("err").applyLeft: seen.add(it)
    right[string, int](42).applyLeft: seen.add(it)
    check seen == @["err"]

  test "applyRight executes body only for Right":
    var seen: seq[int]
    right[string, int](42).applyRight: seen.add(it)
    left[string, int]("err").applyRight: seen.add(it)
    check seen == @[42]

  test "apply returns left branch for Left":
    let e = left[string, int]("err")
    let result = e.apply("was left", "was right")
    check result == "was left"

  test "apply returns right branch for Right":
    let e = right[string, int](42)
    let result = e.apply("was left", "was right")
    check result == "was right"

  test "apply with a single body":
    block:
      let result = left[string, int]("was left").apply("value: " & $it)
      check result == "value: was left"

    block:
      let result = right[string, int](123).apply("value: " & $it)
      check result == "value: 123"

  test "== compares two Either values":
    check left[string, int]("err") == left[string, int]("err")
    check right[string, int](42) == right[string, int](42)
    check left[string, int]("err") != left[string, int]("other")
    check right[string, int](42) != right[string, int](99)
    check left[string, int]("err") != right[string, int](42)
    check right[string, int](42) != left[string, int]("err")

  test "toOption returns none for Left":
    let e = left[string, int]("err")
    check e.toOption == none(int)

  test "toOption returns some for Right":
    let e = right[string, int](42)
    check e.toOption == some(42)
