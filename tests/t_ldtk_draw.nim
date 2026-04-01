import
  std/[unittest, json, jsonutils],
  necsuspd/[ldtk_draw, ldtk],
  necsuspd/stubs/graphics,
  vmath

suite "newLdtkMap":
  test "correct tileSize":
    let m = newLdtkMap[10, 8](16'i32)
    check m.tileSize == 16

  test "all cells default to 0":
    let m = newLdtkMap[3, 3](16'i32)
    for x in 0'i32 ..< 3:
      for y in 0'i32 ..< 3:
        check m[x, y] == 0

suite "contains":
  test "valid positions":
    let m = newLdtkMap[10, 8](16'i32)
    check m.contains(0, 0)
    check m.contains(9, 7)
    check m.contains(5, 3)

  test "invalid positions":
    let m = newLdtkMap[10, 8](16'i32)
    check not m.contains(-1, 0)
    check not m.contains(0, -1)
    check not m.contains(10, 0)
    check not m.contains(0, 8)

suite "tile access":
  test "set and get":
    var m = newLdtkMap[10, 8](16'i32)
    m[3, 4] = 42
    check m[3, 4] == 42'i32

  test "other cells unaffected":
    var m = newLdtkMap[5, 5](16'i32)
    m[2, 2] = 99
    check m[0, 0] == 0
    check m[2, 2] == 99'i32

  test "overwrite cell":
    var m = newLdtkMap[5, 5](16'i32)
    m[1, 1] = 10
    m[1, 1] = 20
    check m[1, 1] == 20'i32

  test "reset to 0":
    var m = newLdtkMap[5, 5](16'i32)
    m[2, 3] = 15
    m[2, 3] = 0
    check m[2, 3] == 0

suite "matchesCell":
  test "0 matches anything":
    check matchesCell(0, 0)
    check matchesCell(0, 1)
    check matchesCell(0, 99)

  test "1000001 matches any non-empty":
    check matchesCell(1000001, 1)
    check matchesCell(1000001, 42)
    check not matchesCell(1000001, 0)

  test "-1000001 matches empty only":
    check matchesCell(-1000001, 0)
    check not matchesCell(-1000001, 1)
    check not matchesCell(-1000001, 99)

  test "positive N matches exact value":
    check matchesCell(3, 3)
    check not matchesCell(3, 2)
    check not matchesCell(3, 0)

  test "negative N rejects that value":
    check matchesCell(-3, 2)
    check matchesCell(-3, 0)
    check not matchesCell(-3, 3)

suite "matchesPattern":
  # Pattern layout for 3x3 (flat, row-major):
  # [0] [1] [2]   <- py=0 (top)
  # [3] [4] [5]   <- py=1 (center row)
  # [6] [7] [8]   <- py=2 (bottom)
  # Index 4 = center cell (cx, cy)
  # Index 1 = cell above center (cx, cy-1)

  proc makeRule(pattern: seq[int64]): LdtkAutoRuleDef =
    LdtkAutoRuleDef(size: 3, active: true, chance: 1.0, pattern: pattern)

  test "all don't-care always matches":
    var m = newLdtkMap[5, 5](16'i32)
    let rule = makeRule(@[0'i64, 0, 0, 0, 0, 0, 0, 0, 0])
    check matchesPattern(m, rule, ivec2(2, 2), false, false)

  test "any-non-empty center matches when cell set":
    var m = newLdtkMap[5, 5](16'i32)
    m[2, 2] = 1
    let rule = makeRule(@[0'i64, 0, 0, 0, 1000001, 0, 0, 0, 0])
    check matchesPattern(m, rule, ivec2(2, 2), false, false)

  test "any-non-empty center fails when cell empty":
    var m = newLdtkMap[5, 5](16'i32)
    let rule = makeRule(@[0'i64, 0, 0, 0, 1000001, 0, 0, 0, 0])
    check not matchesPattern(m, rule, ivec2(2, 2), false, false)

  test "empty-above with non-empty center":
    var m = newLdtkMap[5, 5](16'i32)
    m[2, 2] = 1 # center non-empty
    # m[2, 1] = 0 by default (empty above)
    let rule = makeRule(@[0'i64, -1000001, 0, 0, 1000001, 0, 0, 0, 0])
    check matchesPattern(m, rule, ivec2(2, 2), false, false)

  test "fails when above is not empty":
    var m = newLdtkMap[5, 5](16'i32)
    m[2, 2] = 1
    m[2, 1] = 1 # above also non-empty, but pattern requires empty
    let rule = makeRule(@[0'i64, -1000001, 0, 0, 1000001, 0, 0, 0, 0])
    check not matchesPattern(m, rule, ivec2(2, 2), false, false)

  test "out-of-bounds neighbours treated as 0":
    var m = newLdtkMap[5, 5](16'i32)
    m[0, 0] = 1 # corner cell; neighbours to left and above are out of bounds
    # Pattern: top-left neighbour must be empty (out of bounds = 0 = empty)
    let rule = makeRule(@[-1000001'i64, 0, 0, 0, 1000001, 0, 0, 0, 0])
    check matchesPattern(m, rule, ivec2(0, 0), false, false)

  test "flipX mirrors pattern horizontally":
    var m = newLdtkMap[5, 5](16'i32)
    m[2, 2] = 1
    m[3, 2] = 1 # right neighbour set
    # Original pattern: left neighbour (index 3) must be non-empty — won't match
    # FlipX pattern: right neighbour (index 5) checked via left slot — should match
    let rule = makeRule(@[0'i64, 0, 0, 1000001, 1000001, 0, 0, 0, 0])
    check not matchesPattern(m, rule, ivec2(2, 2), false, false)
    check matchesPattern(m, rule, ivec2(2, 2), true, false)
