import std/[unittest, sets, options], necsuspd/zone_fill, vmath

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
    check m.zoneCount == 1
    check m[0].bounds == (3'i32, 2'i32, 3'i32, 2'i32)

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
    check m.zoneCount == 1
    check m[0].bounds == (1'i32, 1'i32, 7'i32, 3'i32)

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
    check m.zoneCount == 1
    check m[0].bounds == (0'i32, 2'i32, 9'i32, 2'i32)

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
    check m.zoneCount == 2
    check m[0].bounds == (1'i32, 1'i32, 3'i32, 3'i32)
    check m[1].bounds == (4'i32, 1'i32, 9'i32, 2'i32)

  test "Every passable tile is assigned a zone":
    #!fmt: off
    let rows = [
      "##########",
      "#.........",
      "#.........",
      "#...######",
      "##########",
    ]
    #!fmt: on
    let input = parseMap(rows)
    var m: ZoneMap[W, H]
    m.detectZones(input)
    for y in 0'i32 ..< H:
      for x in 0'i32 ..< W:
        let pos = ivec2(x, y)
        if input.isPassable(pos):
          check m[pos].isSome

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
    # Predefined zone keeps its id and bounds
    check m[0].id == preId
    check m[0].bounds == (1'i32, 1'i32, 3'i32, 3'i32)
    # Its tiles still point to the predefined zone
    check m[ivec2(1, 1)] == some(preId)
    check m[ivec2(3, 3)] == some(preId)
    # The remaining open area became a separate zone
    check m.zoneCount == 2

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
    # Zone 0 (3-wide block) and zone 1 (wide right portion) share a vertical edge
    check ZoneId(1) in m[0].adjacent
    check ZoneId(0) in m[1].adjacent

  test "Predefined zones sharing a vertical edge are adjacent":
    let input = parseMap(["..........","..........","..........","..........",".........."])
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
    #!fmt: on
    # Left single-column zone and right 5-column zone are separated by walls
    check m.zoneCount == 2
    check m[0].adjacent.len == 0
    check m[1].adjacent.len == 0

# ---------------------------------------------------------------------------

suite "sharedEdgeMidpoint":
  test "Horizontal shared edge (zone above zone)":
    # Shared edge between row 2 (top zone) and row 3 (arm).
    # Overlapping cols 1..3, midpoint col = (1+3)/2 = 2.
    # Always returns the tile on the lower zone's boundary (row 3).
    let a: ZoneRect = (1'i32, 1'i32, 9'i32, 2'i32)
    let b: ZoneRect = (1'i32, 3'i32, 3'i32, 3'i32)
    check sharedEdgeMidpoint(a, b) == ivec2(2, 3)
    check sharedEdgeMidpoint(b, a) == ivec2(2, 3)

  test "Vertical shared edge (zone left of zone)":
    # Always returns the tile on the right zone's boundary (col 5).
    let a: ZoneRect = (0'i32, 0'i32, 4'i32, 4'i32)
    let b: ZoneRect = (5'i32, 0'i32, 9'i32, 4'i32)
    check sharedEdgeMidpoint(a, b) == ivec2(5, 2)
    check sharedEdgeMidpoint(b, a) == ivec2(5, 2)
