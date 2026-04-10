import std/[unittest, sets, options, strutils], necsuspd/zone_fill, necsuspd/fpvec, vmath

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

type TestMap = object
  passable: HashSet[IVec2]

proc isPassable(m: TestMap, pos: IVec2): bool =
  m.passable.contains(pos)

proc parseMap(rows: openarray[string]): TestMap =
  for y, row in rows:
    for x, ch in row:
      if ch == '.':
        result.passable.incl(ivec2(x.int32, y.int32))

proc `==`[W, H: static int32](m: ZoneMap[W, H], rows: openarray[string]): bool =
  $m == rows.join("\n")

const W = 10'i32
const H = 5'i32

proc detect(rows: openarray[string]): ZoneMap[W, H] =
  let input = parseMap(rows)
  result.detectZones(input)

# ---------------------------------------------------------------------------

suite "Zone detection":
  test "Single passable tile creates one zone":
    #!fmt: off
    let m = detect([
      "##########",
      "##########",
      "###.######",
      "##########",
      "##########",
    ])
    #!fmt: on
    #!fmt: off
    check m == [
      "..........",
      "..........",
      "...a......",
      "..........",
      "..........",
    ]
    #!fmt: on

  test "Open rectangle becomes a single zone":
    #!fmt: off
    let m = detect([
      "##########",
      "#.......##",
      "#.......##",
      "#.......##",
      "##########",
    ])
    #!fmt: on
    #!fmt: off
    check m == [
      "..........",
      ".aaaaaaa..",
      ".aaaaaaa..",
      ".aaaaaaa..",
      "..........",
    ]
    #!fmt: on

  test "Horizontal corridor stays a single zone":
    #!fmt: off
    let m = detect([
      "##########",
      "##########",
      "..........",
      "##########",
      "##########",
    ])
    #!fmt: on
    #!fmt: off
    check m == [
      "..........",
      "..........",
      "aaaaaaaaaa",
      "..........",
      "..........",
    ]
    #!fmt: on

  test "L-shape creates two zones":
    # The flood fill expands the first seed into the widest balanced rect it
    # can form: a 3-wide block (cols 1-3, rows 1-3) constrained by the arm
    # width. The remaining open area (cols 4-9, rows 1-2) becomes zone 1.
    #!fmt: off
    let m = detect([
      "##########",
      "#.........",
      "#.........",
      "#...######",
      "##########",
    ])
    #!fmt: on
    #!fmt: off
    check m == [
      "..........",
      ".aaabbbbbb",
      ".aaabbbbbb",
      ".aaa......",
      "..........",
    ]
    #!fmt: on

# ---------------------------------------------------------------------------

suite "Predefined zones":
  test "Valid predefined zone is not overwritten by flood fill":
    #!fmt: off
    let rows = [
      "##########",
      "#......###",
      "#......###",
      "#......###",
      "##########",
    ]
    #!fmt: on
    let input = parseMap(rows)
    var m: ZoneMap[W, H]
    let preId = m.addZone((1'i32, 1'i32, 3'i32, 3'i32))
    m.detectZones(input)
    check preId == ZoneId(0)
    #!fmt: off
    check m == [
      "..........",
      ".aaabbb...",
      ".aaabbb...",
      ".aaabbb...",
      "..........",
    ]
    #!fmt: on

  test "Predefined zone containing a wall raises ValueError":
    #!fmt: off
    let rows = [
      "##########",
      "#......###",
      "#......###",
      "#......###",
      "##########",
    ]
    #!fmt: on
    let input = parseMap(rows)
    var m: ZoneMap[W, H]
    discard m.addZone((0'i32, 0'i32, 5'i32, 4'i32)) # includes wall tiles
    expect(AssertionDefect):
      m.detectZones(input)

# ---------------------------------------------------------------------------

suite "Adjacency":
  test "Two natural zones from L-shape are adjacent":
    #!fmt: off
    let m = detect([
      "##########",
      "#.........",
      "#.........",
      "#...######",
      "##########",
    ])
    #!fmt: on
    check ZoneId(1) in m[0].adjacent
    check ZoneId(0) in m[1].adjacent

  test "Predefined zones sharing a vertical edge are adjacent":
    let input =
      parseMap(["..........", "..........", "..........", "..........", ".........."])
    var m: ZoneMap[W, H]
    discard m.addZone((0'i32, 0'i32, 4'i32, 4'i32))
    discard m.addZone((5'i32, 0'i32, 9'i32, 4'i32))
    m.detectZones(input)
    check ZoneId(1) in m[0].adjacent
    check ZoneId(0) in m[1].adjacent

  test "Zones that do not touch are not adjacent":
    #!fmt: off
    let m = detect([
      ".####.....",
      ".####.....",
      ".####.....",
      ".####.....",
      ".####.....",
    ])
    check m == [
      "a....bbbbb",
      "a....bbbbb",
      "a....bbbbb",
      "a....bbbbb",
      "a....bbbbb",
    ]
    #!fmt: on
    check m[0].adjacent.len == 0
    check m[1].adjacent.len == 0

# ---------------------------------------------------------------------------

suite "Complex map":
  #!fmt: off
  const level4 = [
    "#########################",
    "#######...........#######",
    "#######...........#######",
    "#######...........#######",
    "#######...#####...#######",
    "#....##.....#.....##....#",
    "#....##.....#.....##....#",
    "#....###...###...###....#",
    "#....###...###...###....#",
    "##....##....#....##....##",
    "##....##....#....##....##",
    "##.........###.........##",
    "##.........###.........##",
    "#########################",
    "#########################",
  ]
  #!fmt: on

  test "Every floor tile is assigned a zone":
    let input = parseMap(level4)
    var m: ZoneMap[25'i32, 15'i32]
    m.detectZones(input)
    for y in 0'i32 ..< 15:
      for x in 0'i32 ..< 25:
        let pos = ivec2(x, y)
        if input.isPassable(pos):
          check m[pos].isSome

  test "Zone map matches expected layout":
    let input = parseMap(level4)
    var m: ZoneMap[25'i32, 15'i32]
    m.detectZones(input)
    #!fmt: off
    check m == [
      ".........................",
      ".......aaaaaaaaaaa.......",
      ".......aaaaaaaaaaa.......",
      ".......aaaaaaaaaaa.......",
      ".......bbb.....ccc.......",
      ".dddd..bbbee.ffccc..gggg.",
      ".dddd..bbbee.ffccc..gggg.",
      ".dddd...hhh...iii...gggg.",
      ".dddd...hhh...iii...gggg.",
      "..jjjj..hhhk.liii..mmmm..",
      "..jjjj..hhhk.liii..mmmm..",
      "..jjjjnnhhh...iiioommmm..",
      "..jjjjnnhhh...iiioommmm..",
      ".........................",
      ".........................",
    ]
    #!fmt: on

# ---------------------------------------------------------------------------

suite "sharedEdgeMidpoint":
  # Use tileSize=1 so tile coords equal pixel coords, making expectations easy to read.
  let ts = fp(1)

  test "Horizontal shared edge (zone above zone)":
    # Overlapping cols 1..3: parallel center = (1+3)/2 * 1 + 0.5 = 2.5.
    # Boundary row = b.minRow = 3 (exact tile edge).
    let a: ZoneRect = (1'i32, 1'i32, 9'i32, 2'i32)
    let b: ZoneRect = (1'i32, 3'i32, 3'i32, 3'i32)
    check sharedEdgeMidpoint(a, b, ts) == fpvec2(2.5, 3.0)
    check sharedEdgeMidpoint(b, a, ts) == fpvec2(2.5, 3.0)

  test "Vertical shared edge (zone left of zone)":
    # Boundary col = b.minCol = 5 (exact tile edge).
    # Overlapping rows 0..4: parallel center = (0+4)/2 * 1 + 0.5 = 2.5.
    let a: ZoneRect = (0'i32, 0'i32, 4'i32, 4'i32)
    let b: ZoneRect = (5'i32, 0'i32, 9'i32, 4'i32)
    check sharedEdgeMidpoint(a, b, ts) == fpvec2(5.0, 2.5)
    check sharedEdgeMidpoint(b, a, ts) == fpvec2(5.0, 2.5)
