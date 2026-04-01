import
  std/[unittest, json, jsonutils, sequtils, options, strutils],
  necsuspd/[ldtk, data_bundle],
  vmath

let data = readFile("tests/sample.ldtk").parseJson.jsonTo(LdtkJsonRoot)

suite "Parsing":
  test "Three levels":
    checkpoint "level count: " & $data.levels.len
    check(data.levels.len == 3)

  test "Level identifiers":
    let ids = data.levels.mapIt(it.identifier)
    checkpoint "level identifiers: " & ids.join(", ")
    check(data.levels[0].identifier == "World_Level_0")
    check(data.levels[1].identifier == "World_Level_1")
    check(data.levels[2].identifier == "World_Level_2")

  test "Two tilesets":
    let names = data.defs.tilesets.mapIt(it.identifier)
    checkpoint "tileset count: " & $data.defs.tilesets.len & " (" & names.join(", ") &
      ")"
    check(data.defs.tilesets.len == 2)

suite "getLevel":
  test "Returns correct level by index":
    let id = getLevel(data, 0).identifier
    checkpoint "level 0 identifier: " & id
    check(id == "World_Level_0")

  test "Level dimensions":
    let level0 = getLevel(data, 0)
    checkpoint "pxWid=" & $level0.pxWid & " pxHei=" & $level0.pxHei
    check(level0.pxWid == 512)
    check(level0.pxHei == 256)

suite "layers iterator":
  test "Has at least three layers":
    let level0 = getLevel(data, 0)
    let ids = toSeq(level0.layers).mapIt(it.identifier)
    checkpoint "layers (" & $ids.len & "): " & ids.join(", ")
    check(ids.len >= 3)

  test "Contains Collisions and Entities layers":
    let level0 = getLevel(data, 0)
    let ids = toSeq(level0.layers).mapIt(it.identifier)
    checkpoint "layer identifiers: " & ids.join(", ")
    check("Collisions" in ids)
    check("Entities" in ids)

suite "withLayer":
  test "Finds Collisions layer":
    let level0 = getLevel(data, 0)
    withLayer(level0, "Collisions", layer):
      checkpoint "layer identifier: " & layer.identifier & " type: " & layer.`type`
      check(layer.identifier == "Collisions")

  test "Finds Entities layer":
    let level0 = getLevel(data, 0)
    withLayer(level0, "Entities", layer):
      checkpoint "layer identifier: " & layer.identifier & " type: " & layer.`type`
      check(layer.`type` == "Entities")

suite "entities iterator":
  test "Finds one Player entity":
    let level0 = getLevel(data, 0)
    let players = toSeq(level0.entities("Player"))
    checkpoint "Player entity count: " & $players.len
    if players.len > 0:
      checkpoint "Player px: " & $players[0].px
    check(players.len == 1)

  test "All entities yields at least one":
    let level0 = getLevel(data, 0)
    let all = toSeq(level0.entities).mapIt(it.identifier)
    checkpoint "entities (" & $all.len & "): " & all.join(", ")
    check(all.len >= 1)

  test "Unknown kind yields no entities":
    let level0 = getLevel(data, 0)
    let ghosts = toSeq(level0.entities("Ghost"))
    checkpoint "Ghost entity count: " & $ghosts.len
    check(ghosts.len == 0)

suite "IntGrid layer [] and contains":
  test "Grid bounds checks":
    let level0 = getLevel(data, 0)
    withLayer(level0, "Collisions", layer):
      checkpoint "grid size: cWid=" & $layer.cWid & " cHei=" & $layer.cHei
      check(layer.contains(ivec2(0, 0)))
      check(layer.contains(ivec2(31, 15)))
      check(not layer.contains(ivec2(-1, 0)))
      check(not layer.contains(ivec2(0, -1)))
      check(not layer.contains(ivec2(32, 0)))
      check(not layer.contains(ivec2(0, 16)))

  test "Empty cell returns 0":
    let level0 = getLevel(data, 0)
    withLayer(level0, "Collisions", layer):
      let val = layer[ivec2(0, 0)]
      checkpoint "value at (0,0): " & $val
      check(val == 0)

  test "Wall cell returns 1":
    let level0 = getLevel(data, 0)
    withLayer(level0, "Collisions", layer):
      let gridStr = block:
        var rows: seq[string]
        for row in 0 ..< layer.cHei.int:
          var cells: seq[string]
          for col in 0 ..< layer.cWid.int:
            cells.add($layer[ivec2(col.int32, row.int32)])
          rows.add("row " & $row & ": " & cells.join(""))
        rows.join("\n")
      checkpoint "intGrid:\n" & gridStr
      check(layer[ivec2(0, 12)] == 1)

suite "tileset lookup":
  test "Finds tileset by uid":
    let tileRect = LdtkTilesetRect(tilesetUid: 1, h: 16, x: 0, y: 0, w: 16)
    let ts = data.tileset(tileRect)
    checkpoint "tileset found: " & $ts.isSome &
      (if ts.isSome: " identifier=" & ts.get.identifier else: "")
    check(ts.isSome)
    check(ts.get.identifier == "TopDown_by_deepnight")

  test "Returns none for unknown uid":
    let tileRect = LdtkTilesetRect(tilesetUid: 9999, h: 16, x: 0, y: 0, w: 16)
    let ts = data.tileset(tileRect)
    checkpoint "tileset found for uid 9999: " & $ts.isSome
    check(ts.isNone)
