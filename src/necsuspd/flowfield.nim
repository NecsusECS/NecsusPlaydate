import fixedpoint, vmath

type
  FlowFieldInput* =
    concept i
        ## An input from which a flow field can be generated.
        i.contains(IVec2) is bool
        i.totalCost(IVec2) is SomeNumber

  FlowField*[W, H: static int32] = array[W, array[H, FPVec2]]

export fixedpoint

iterator grid(width, height: static int32): IVec2 =
  for y in 0'i32 ..< height:
    for x in 0'i32 ..< width:
      yield ivec2(x, y)

iterator neighbors(
    node: IVec2, width, height: static int32
): tuple[absolute: IVec2, rel: FPVec2] =
  for dy in -1'i32 .. 1'i32:
    for dx in -1'i32 .. 1'i32:
      let nx = node.x + dx
      let ny = node.y + dy
      if nx in 0 ..< width and ny in 0 ..< height:
        yield (ivec2(nx, ny), fpvec2(dx, dy))

proc computeFlowField*[W, H: static int32](map: FlowFieldInput): FlowField[W, H] =
  ## Compute a flow field of a given size
  for node in grid(W, H):
    var total = fpvec2(0, 0)
    let nodeCost = map.totalCost(node)
    for (neighbor, rel) in neighbors(node, W, H):
      if map.contains(neighbor):
        let delta = nodeCost - map.totalCost(neighbor)
        if delta > 0:
          total += rel

    result[node.y][node.x] = if total == fpvec2(0, 0): total else: total.normalize
