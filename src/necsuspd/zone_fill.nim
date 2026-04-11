## Decomposes a 2D orthogonal tile map into a graph of convex rectangular zones.
##
## Every zone is a fully filled rectangle containing only passable tiles.
## The flood fill seeds from the top-left unmapped passable tile and expands
## one tile at a time in each axis direction, accepting an expansion only when
## every tile on the new edge is passable and unmapped. This guarantees
## convexity by construction: walls and already-mapped tiles act as boundaries
## that stop expansion, so irregular map shapes naturally decompose into
## multiple zones at their narrowest points.
##
## Callers may register predefined zones (e.g. spawn points, targets) with
## `addZone` before calling `detectZones`. These zones are validated and seeded
## first, making them boundaries the flood fill cannot cross or absorb.
##
## Once all zones are defined, an adjacency graph is built: two zones are
## adjacent when their bounding rectangles are exactly one tile apart on one
## axis with overlapping extents on the other. `sharedEdgeMidpoint` returns
## the fractional tile-space position on the shared edge midpoint: the boundary
## axis lands exactly on the tile edge, the parallel axis at the midpoint tile
## center. Multiply by TILE_SIZE to convert to pixel coordinates.

import std/[hashes, options, strutils], vmath, fpvec

type
  ZoneFillInput* = concept m
    ## A tile map from which zones can be flood-filled.
    m.isPassable(IVec2) is bool

  ZoneId* = distinct int32

  ZoneRect* = tuple[minCol, minRow, maxCol, maxRow: int32]

  Zone* = ref object
    id: ZoneId
    bounds: ZoneRect
    adjacent: seq[ZoneId]

  ZoneMap*[W, H: static int32] = object
    zones: seq[Zone]
    tileToZone: array[H, array[W, Option[ZoneId]]]

proc hash*(id: ZoneId): Hash {.borrow.}
proc `<`*(a, b: ZoneId): bool {.borrow.}

proc id*(zone: Zone): ZoneId = ## The unique id of this zone.
  zone.id

proc bounds*(zone: Zone): ZoneRect = ## The bounding rectangle of this zone.
  zone.bounds

proc adjacent*(zone: Zone): seq[ZoneId] =
  ## The ids of all zones that share an edge with this zone.
  zone.adjacent

proc zoneCount*[W, H: static int32](map: ZoneMap[W, H]): int =
  ## The total number of zones in the map.
  map.zones.len

proc `[]`*[W, H: static int32](map: ZoneMap[W, H], i: int): Zone =
  ## Returns the zone at index i (equivalent to the zone with ZoneId(i)).
  map.zones[i]

proc `==`*(a, b: ZoneId): bool {.borrow.} ## Equality for ZoneId.

proc `$`*(id: ZoneId): string =
  ## Renders a ZoneId as its underlying integer value.
  $int32(id)

proc addZone*[W, H: static int32](map: var ZoneMap[W, H], bounds: ZoneRect): ZoneId =
  ## Registers a zone, seeds its tiles in tileToZone, and returns its assigned id.
  ## Call before detectZones to register predefined zones (spawn points, targets, etc.).
  result = ZoneId(map.zones.len)
  map.zones.add(Zone(id: result, bounds: bounds))
  for row in bounds.minRow .. bounds.maxRow:
    for col in bounds.minCol .. bounds.maxCol:
      map.tileToZone[row][col] = some(result)

proc `[]`*[W, H: static int32](map: ZoneMap[W, H], pos: IVec2): Option[ZoneId] =
  ## Returns the zone id at the given tile position, if any.
  if pos.x >= 0 and pos.x < W and pos.y >= 0 and pos.y < H:
    return map.tileToZone[pos.y][pos.x]

proc zoneById*[W, H: static int32](map: ZoneMap[W, H], id: ZoneId): Option[Zone] =
  ## Returns the zone with the given id, if it exists.
  let idx = int32(id)
  if idx >= 0 and idx < map.zones.len:
    return some(map.zones[idx])

proc sharesEdge(a, b: ZoneRect): bool =
  ## Returns true if rectangles a and b are exactly one tile apart on one axis
  ## with overlapping extents on the other.
  if a.maxCol + 1 == b.minCol or b.maxCol + 1 == a.minCol:
    return a.minRow <= b.maxRow and a.maxRow >= b.minRow
  if a.maxRow + 1 == b.minRow or b.maxRow + 1 == a.minRow:
    return a.minCol <= b.maxCol and a.maxCol >= b.minCol

proc sharedEdgeMidpoint*(a, b: ZoneRect, tileSize: FPInt): FPVec2 =
  ## Returns the pixel position of the midpoint of the shared edge between two zones.
  ## The boundary axis lands on the exact tile edge; the parallel axis at the tile
  ## center of the midpoint. Consistent regardless of argument order.
  let half = tileSize / 2
  if a.maxCol + 1 == b.minCol:
    let lo = max(a.minRow, b.minRow)
    let hi = min(a.maxRow, b.maxRow)
    return fpvec2(b.minCol.fp * tileSize, (lo + hi).fp / 2 * tileSize + half)
  elif b.maxCol + 1 == a.minCol:
    let lo = max(a.minRow, b.minRow)
    let hi = min(a.maxRow, b.maxRow)
    return fpvec2(a.minCol.fp * tileSize, (lo + hi).fp / 2 * tileSize + half)
  elif a.maxRow + 1 == b.minRow:
    let lo = max(a.minCol, b.minCol)
    let hi = min(a.maxCol, b.maxCol)
    return fpvec2((lo + hi).fp / 2 * tileSize + half, b.minRow.fp * tileSize)
  elif b.maxRow + 1 == a.minRow:
    let lo = max(a.minCol, b.minCol)
    let hi = min(a.maxCol, b.maxCol)
    return fpvec2((lo + hi).fp / 2 * tileSize + half, a.minRow.fp * tileSize)
  else:
    raise
      newException(ValueError, "Zones " & $a & " and " & $b & " do not share an edge")

proc sharedEdgeMidpoint*(a, b: Zone, tileSize: FPInt): FPVec2 =
  sharedEdgeMidpoint(a.bounds, b.bounds, tileSize)

proc isValid(zone: Zone, input: ZoneFillInput): bool =
  ## Returns true if every tile within the zone's bounds is passable.
  for row in zone.bounds.minRow .. zone.bounds.maxRow:
    for col in zone.bounds.minCol .. zone.bounds.maxCol:
      if not input.isPassable(ivec2(col, row)):
        return false
  return true

proc edgeFree[W, H: static int32](
    map: ZoneMap[W, H],
    input: ZoneFillInput,
    fixed, rangeMin, rangeMax: int32,
    colIsFixed: static bool,
): bool {.inline.} =
  ## Returns true if every tile on a new edge is passable and unmapped.
  ## `fixed` is the column (colIsFixed=true) or row (colIsFixed=false) of the new edge;
  ## `rangeMin..rangeMax` is the extent along the other axis.
  for i in rangeMin .. rangeMax:
    let pos =
      when colIsFixed:
        ivec2(fixed, i)
      else:
        ivec2(i, fixed)
    if not input.isPassable(pos) or map.tileToZone[pos.y][pos.x].isSome:
      return false
  return true

proc safePassable[W, H: static int32](
    input: ZoneFillInput, x, y: int32
): bool {.inline.} =
  ## Returns whether (x, y) is within bounds and passable; false if out of bounds.
  x >= 0 and x < W and y >= 0 and y < H and input.isPassable(ivec2(x, y))

proc canExpandLeft[W, H: static int32](
    map: ZoneMap[W, H], input: ZoneFillInput, b: ZoneRect
): bool =
  ## Returns true if b can grow one column to the left.
  b.minCol > 0 and edgeFree[W, H](map, input, b.minCol - 1, b.minRow, b.maxRow, true) and
    safePassable[W, H](input, b.minCol, b.minRow - 1) ==
    safePassable[W, H](input, b.minCol - 1, b.minRow - 1) and
    safePassable[W, H](input, b.minCol, b.maxRow + 1) ==
    safePassable[W, H](input, b.minCol - 1, b.maxRow + 1)

proc canExpandRight[W, H: static int32](
    map: ZoneMap[W, H], input: ZoneFillInput, b: ZoneRect
): bool =
  ## Returns true if b can grow one column to the right.
  b.maxCol < W - 1 and edgeFree[W, H](
    map, input, b.maxCol + 1, b.minRow, b.maxRow, true
  ) and
    safePassable[W, H](input, b.maxCol, b.minRow - 1) ==
    safePassable[W, H](input, b.maxCol + 1, b.minRow - 1) and
    safePassable[W, H](input, b.maxCol, b.maxRow + 1) ==
    safePassable[W, H](input, b.maxCol + 1, b.maxRow + 1)

proc canExpandUp[W, H: static int32](
    map: ZoneMap[W, H], input: ZoneFillInput, b: ZoneRect
): bool =
  ## Returns true if b can grow one row upward.
  b.minRow > 0 and edgeFree[W, H](map, input, b.minRow - 1, b.minCol, b.maxCol, false) and
    safePassable[W, H](input, b.minCol - 1, b.minRow) ==
    safePassable[W, H](input, b.minCol - 1, b.minRow - 1) and
    safePassable[W, H](input, b.maxCol + 1, b.minRow) ==
    safePassable[W, H](input, b.maxCol + 1, b.minRow - 1)

proc canExpandDown[W, H: static int32](
    map: ZoneMap[W, H], input: ZoneFillInput, b: ZoneRect
): bool =
  ## Returns true if b can grow one row downward.
  b.maxRow < H - 1 and
    edgeFree[W, H](map, input, b.maxRow + 1, b.minCol, b.maxCol, false) and
    safePassable[W, H](input, b.minCol - 1, b.maxRow) ==
    safePassable[W, H](input, b.minCol - 1, b.maxRow + 1) and
    safePassable[W, H](input, b.maxCol + 1, b.maxRow) ==
    safePassable[W, H](input, b.maxCol + 1, b.maxRow + 1)

proc floodZone[W, H: static int32](
    map: ZoneMap[W, H], input: ZoneFillInput, startPos: IVec2
): ZoneRect =
  ## Grows a bounding rectangle from startPos by repeatedly expanding in each
  ## direction until no further expansion is possible. Every tile on any new
  ## edge must be passable and unmapped for that expansion to be accepted.
  result = (startPos.x, startPos.y, startPos.x, startPos.y)
  var changed = true
  while changed:
    changed = false
    if canExpandLeft(map, input, result):
      result.minCol -= 1
      changed = true
    if canExpandRight(map, input, result):
      result.maxCol += 1
      changed = true
    if canExpandUp(map, input, result):
      result.minRow -= 1
      changed = true
    if canExpandDown(map, input, result):
      result.maxRow += 1
      changed = true

proc buildAdjacency[W, H: static int32](map: var ZoneMap[W, H]) =
  ## Registers adjacency between every pair of zones whose bounds share an edge.
  for i in 0 ..< map.zones.len:
    for j in i + 1 ..< map.zones.len:
      if sharesEdge(map.zones[i].bounds, map.zones[j].bounds):
        map.zones[i].adjacent.add(map.zones[j].id)
        map.zones[j].adjacent.add(map.zones[i].id)

proc `$`*[W, H: static int32](map: ZoneMap[W, H]): string =
  ## Returns a debug string of the zone map. Each tile with an assigned zone
  ## is shown as a letter (a=zone 0, b=zone 1, …). Unassigned tiles show as '.'.
  var lines: seq[string]
  for row in 0'i32 ..< H:
    var line = ""
    for col in 0'i32 ..< W:
      let zid = map[ivec2(col, row)]
      if zid.isSome:
        line.add(char(ord('a') + int32(zid.get)))
      else:
        line.add('.')
    lines.add(line)
  return lines.join("\n")

proc detectZones*[W, H: static int32](map: var ZoneMap[W, H], input: ZoneFillInput) =
  ## Decomposes the map into convex rectangular zones and builds an adjacency graph.
  ## Predefined zones registered with addZone are validated and seeded first;
  ## the flood fill then covers all remaining passable tiles.
  for zone in map.zones:
    assert zone.isValid(input),
      "Predefined zone " & $zone.id & " contains non-passable tiles"
  for row in 0'i32 ..< H:
    for col in 0'i32 ..< W:
      let pos = ivec2(col, row)
      if input.isPassable(pos) and map.tileToZone[row][col].isNone:
        discard addZone(map, floodZone(map, input, pos))
  buildAdjacency(map)
