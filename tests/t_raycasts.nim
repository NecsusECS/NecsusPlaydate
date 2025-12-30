import std/[unittest, options], necsuspd/[raycasts, fpvec], vmath

proc `==`(a: Option[FPVec2], b: FPVec2): bool =
  if a.isNone:
    return false
  return abs(a.get().x - b.x) < fp(0.05) and abs(a.get().y - b.y) < fp(0.05)

suite "Raycasts":
  #!fmt: off
  let map = [
    [1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 1, 1],
    [1, 1, 1, 1, 1]
  ]
  #!fmt: on

  proc mapTile(x, y: int32): bool =
    map[y][x] == 1

  test "Intersect with a solid tile horizontally":
    let intersects = raycast(fpvec2(1.5, 1.5), fpvec2(1, 0), mapTile)
    check intersects == some(fpvec2(4.0, 1.5))

  test "Intersect with a solid tile vertically":
    let intersects = raycast(fpvec2(1.5, 1.5), fpvec2(0, 1), mapTile)
    check intersects == some(fpvec2(1.5, 3.0))

  test "Intersect with a solid tile diagonally":
    let intersects = raycast(fpvec2(1, 1), fpvec2(1, 1), mapTile)
    check intersects == fpvec2(3.0, 3.0)

    test "Intersect with a solid tile at a steep diagonal":
      let intersects = raycast(fpvec2(1, 2), fpvec2(2, -1), mapTile)
      check intersects == fpvec2(3.03125, 1.0)

  test "No intersection":
    let intersects = raycast(fpvec2(1.5, 1.5), fpvec2(1, 0)) do(x, y: int32) -> bool:
      false
    check intersects == none(FPVec2)

  test "Starts from inside a solid tile":
    let intersects = raycast(fpvec2(0, 4), fpvec2(2, -1), mapTile)
    check intersects == fpvec2(3.984375, 2.03125)

  test "Intersect with custom tile size horizontally":
    # With 2x2 tiles, the map coordinates should be scaled
    # Origin at (3, 3) in world space = tile [1, 1] in map coordinates
    # Casting right should hit the wall at tile [4] which is at x=8.0 in world space
    let intersects =
      raycast(fpvec2(3, 3), fpvec2(1, 0), mapTile, tileSize = fpvec2(2, 2))
    check intersects == fpvec2(8.0, 3.0)

  test "Intersect with custom tile size vertically":
    # With 2x2 tiles, casting down from (3, 3) should hit at y=6.0
    let intersects =
      raycast(fpvec2(3, 3), fpvec2(0, 1), mapTile, tileSize = fpvec2(2, 2))
    check intersects == fpvec2(3.0, 6.0)
