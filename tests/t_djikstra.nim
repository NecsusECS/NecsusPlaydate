import std/[unittest, strutils, strformat], necsuspd/djikstra

type
  Point = tuple[x, y: int]

  Map[N: static[int]] = array[N, array[N, int]]

  Source[N: static int] = tuple[map: Map[N], targets: seq[Point]]

proc `$`(p: Point): string =
  "(" & $p.x & ", " & $p.y & ")"

iterator neighbors*(source: Source, p: Point): Point =
  for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
    let neighbor: Point = (p.x + dx, p.y + dy)
    if neighbor.x in 0 ..< (source.map[0].len) and neighbor.y in 0 ..< (source.map.len):
      yield neighbor

proc cost(source: Source, a, b: Point): int =
  abs(source.map[a.y][a.x] - source.map[b.y][b.x])

proc direction(a, b: Point): char =
  #!fmt: off
  const table = [
    ['!', '^', '!'],
    ['<', 'X', '>'],
    ['!', 'v', '!']
  ]
  #!fmt: on
  let dx = b.x - a.x + 1
  let dy = b.y - a.y + 1
  result = table[dy][dx]
  assert(result != '!')

proc directions(graph: DjikstraGraph[int, Point], size: int): string =
  for y in 0 ..< size:
    for x in 0 ..< size:
      result &= direction((x, y), graph[(x, y)].next)
    result &= "\n"

proc distances(graph: DjikstraGraph[int, Point], size: int): string =
  for y in 0 ..< size:
    for x in 0 ..< size:
      result &= $graph[(x, y)].totalCost
    result &= "\n"

suite "Djikstra's algorithm":
  test "Generate a graph with a single target":
    #!fmt: off
    let map: Map[3] = [
      [1, 2, 3],
      [2, 3, 4],
      [0, 4, 5]
    ]
    #!fmt: on

    let source: Source[3] = (map, @[(2, 1)])
    let graph = calculateDjikstra[int, Point](source)

    check(
      graph.distances(3) ==
        """
        321
        210
        421
        """.dedent
    )

    check(
      graph.directions(3) ==
        """
        vvv
        >>X
        ^^^
        """.dedent
    )

  test "Generate a graph with multiple targets":
    #!fmt: off
    let map: Map[4] = [
      [1, 2, 3, 1],
      [2, 3, 4, 1],
      [3, 4, 5, 1],
      [9, 8, 7, 6]
    ]
    #!fmt: on

    let source: Source[4] = (map, @[(0, 0), (3, 3)])
    let graph = calculateDjikstra[int, Point](source)

    check(
      graph.distances(4) ==
        """
        0124
        1234
        2334
        3210
        """.dedent
    )

    check(
      graph.directions(4) ==
        """
        X<<<
        ^<<^
        ^<v^
        >>>X
        """.dedent
    )
