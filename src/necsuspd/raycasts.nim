import fpvec, std/options, std/math, vmath

type
  CollisionSide = enum
    XAxis
    YAxis

  HasCollision = enum
    InsideWall
    MissWall
    HitWall

proc calculateSideDist(dir, origin, map, deltaDist: FPInt): FPInt {.inline.} =
  if dir < 0:
    return (origin - map) * deltaDist
  else:
    return (map + 1.fp - origin) * deltaDist

proc intersectionPoint(map, origin, step, dir: FPInt): FPInt {.inline.} =
  return (map - origin + (1.fp - step) / 2.fp) / dir

proc initialDeltaDist(dir: FPInt): FPInt {.inline.} =
  if dir == 0:
    high(FPInt)
  else:
    abs(1.fp / dir)

proc raycast*(
    origin, heading: FPVec2,
    isSolid: proc(x, y: int32): bool,
    maxIterations: static[int32] = 1_000,
    tileSize: static[FPVec2] = fpvec2(1, 1),
): Option[FPVec2] {.inline.} =
  ## Casts a ray from the origin in the given direction and returns the first intersection
  ## with a solid tile. If the origin is on a solid tile itself, it will cast a ray until the
  ## tile is exited, then continue until the intersection with the next solid tile

  if heading.x == 0 and heading.y == 0:
    return none(FPVec2)

  # Convert origin from world space to grid space
  let originGrid = origin / tileSize

  # Normalize direction to avoid scaling issues
  let dir = heading.normalize()

  # Step direction (+1 or -1) for each axis
  let stepX = if dir.x < 0: -1.fp else: 1.fp
  let stepY = if dir.y < 0: -1.fp else: 1.fp

  # Distance to first vertical / horizontal grid boundary
  # Work in grid space, so these are distances in terms of grid cells
  let deltaDistX: FPInt = initialDeltaDist(dir.x / tileSize.x)
  let deltaDistY: FPInt = initialDeltaDist(dir.y / tileSize.y)

  # Current cell in grid space
  var mapX = originGrid.x.toInt().fp
  var mapY = originGrid.y.toInt().fp

  # The distance from the origin to the first intersection with a grid cell
  var sideDistX: FPInt =
    calculateSideDist(dir.x / tileSize.x, originGrid.x, mapX, deltaDistX)
  var sideDistY: FPInt =
    calculateSideDist(dir.y / tileSize.y, originGrid.y, mapY, deltaDistY)

  var hit = if isSolid(mapX.toInt(), mapY.toInt()): InsideWall else: MissWall
  var side = XAxis

  # echo "Origin: ", origin
  # echo "Direction: ", dir
  # echo "Delta distance: ", deltaDistX, ", ", deltaDistY
  # echo "Initial MapX: ", mapX, ", ", mapY
  # echo "Initial side distance: ", sideDistX, ", ", sideDistY
  # echo "Initial hit state: ", hit

  # DDA loop
  for _ in 0 ..< maxIterations:
    # Jump to next grid cell in whichever direction is closer
    if sideDistX < sideDistY:
      sideDistX += deltaDistX
      mapX += stepX
      side = XAxis
    else:
      sideDistY += deltaDistY
      mapY += stepY
      side = YAxis

    # echo i
    # echo " map: ", mapX.toInt(), ", ", mapY.toInt()
    # echo " side: ", side
    # echo " sideDist: ", sideDistX.toInt(), ", ", sideDistY.toInt()

    if isSolid(mapX.toInt(), mapY.toInt()):
      if hit == MissWall:
        hit = HitWall
        break
    elif hit == InsideWall:
      hit = MissWall

  if hit == HitWall:
    # Compute intersection point - convert mapX/mapY back to world space
    let perpWallDist: FPInt =
      case side
      of XAxis:
        intersectionPoint(mapX * tileSize.x, origin.x, stepX, dir.x)
      of YAxis:
        intersectionPoint(mapY * tileSize.y, origin.y, stepY, dir.y)

    return some(origin + dir * perpWallDist)
