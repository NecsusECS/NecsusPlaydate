import std/[unittest, strutils], necsuspd/[flowfield, djikstra], vmath

type Map[N] = array[N, array[N, int]]

proc `$`(field: FlowField): string =
  result = ""
  for row in field:
    for elem in row:
      result.add "("
      result.add $elem.x
      result.add ", "
      result.add $elem.y
      result.add ")"
    result.add("\n")
  result.add("\n")

proc contains(map: Map, point: IVec2): bool =
  point.x >= 0 and point.x < len(map) and point.y >= 0 and point.y < len(map[point.x])

proc totalCost(map: Map, point: IVec2): int =
  if contains(map, point):
    map[point.x][point.y]
  else:
    0

suite "FlowField":
  test "Generate a flow field":
    #!fmt: off
    let map: Map[3] = [
      [4, 3, 2],
      [3, 2, 1],
      [2, 1, 0]
    ]
    #!fmt: on

    let flowfield = computeFlowField[3, 3](map)

    check(
      $flowfield ==
        """
        (0.703125, 0.703125)(0.703125, 0.703125)(0.0, 1.0)
        (0.703125, 0.703125)(0.703125, 0.703125)(0.0, 1.0)
        (1.0, 0.0)(1.0, 0.0)(0.0, 0.0)

        """.dedent
    )

  test "Generate a flow field from a djikstra map":
    var djikstra: DjikstraGraph[int32, IVec2]
    discard computeFlowField[3, 3](djikstra)
