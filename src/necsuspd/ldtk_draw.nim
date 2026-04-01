import import_playdate, draw, ldtk, std/random, vmath

type LdtkMap*[W, H: static int] = object
  tiles: array[W, array[H, int32]]
  tileSize*: int32

proc newLdtkMap*[W, H: static int](tileSize: int32): LdtkMap[W, H] =
  ## Creates a new tile map with all cells initialised to 0 (empty)
  result.tileSize = tileSize

proc contains*[W, H: static int](map: LdtkMap[W, H], pos: IVec2): bool =
  pos.x in 0'i32 ..< W and pos.y in 0'i32 ..< H

proc contains*[W, H: static int](map: LdtkMap[W, H], x, y: int32): bool =
  map.contains(ivec2(x, y))

proc `[]`*[W, H: static int](map: LdtkMap[W, H], pos: IVec2): int32 =
  assert map.contains(pos)
  map.tiles[pos.x][pos.y]

proc `[]`*[W, H: static int](map: LdtkMap[W, H], x, y: int32): int32 =
  map[ivec2(x, y)]

proc `[]=`*[W, H: static int](map: var LdtkMap[W, H], pos: IVec2, value: int32) =
  assert map.contains(pos)
  map.tiles[pos.x][pos.y] = value

proc `[]=`*[W, H: static int](map: var LdtkMap[W, H], x, y: int32, value: int32) =
  map[ivec2(x, y)] = value

proc matchesCell*(patternValue: BiggestInt, cellValue: int32): bool =
  ## Returns true if cellValue satisfies the LDtk pattern constraint.
  ## 0 = don't care; 1000001 = any non-empty; -1000001 = must be empty;
  ## N>0 = must equal N; N<0 = must not equal -N.
  const AnyNonEmpty = 1000001 # sentinel defined by the LDtk JSON format
  const AnyEmpty = -1000001 # sentinel defined by the LDtk JSON format
  if patternValue == 0:
    true
  elif patternValue == AnyNonEmpty:
    cellValue != 0
  elif patternValue == AnyEmpty:
    cellValue == 0
  elif patternValue > 0:
    cellValue == patternValue.int32
  else:
    cellValue != (-patternValue).int32

proc flippedSrc(pos: IVec2, size: int, flipX, flipY: bool): IVec2 =
  ivec2(
    (if flipX: (size - 1).int32 - pos.x else: pos.x),
    (if flipY: (size - 1).int32 - pos.y else: pos.y),
  )

iterator patternCells(rule: LdtkAutoRuleDef): IVec2 =
  let size = rule.size.int
  for py in 0 ..< size:
    for px in 0 ..< size:
      yield ivec2(px.int32, py.int32)

proc matchesPattern*[W, H: static int](
    map: LdtkMap[W, H], rule: LdtkAutoRuleDef, center: IVec2, flipX, flipY: bool
): bool =
  let size = rule.size.int
  let half = (size div 2).int32
  for pos in rule.patternCells:
    let src = flippedSrc(pos, size, flipX, flipY)
    let patternValue = rule.pattern[src.y.int * size + src.x.int]
    if patternValue == 0:
      continue
    let cell = center + pos - ivec2(half, half)
    let cellValue =
      if map.contains(cell):
        map[cell]
      else:
        0
    if not matchesCell(patternValue, cellValue):
      return false
  true

proc bitmapFlip(flipX, flipY: bool): LCDBitmapFlip =
  if flipX and flipY:
    kBitmapFlippedXY
  elif flipX:
    kBitmapFlippedX
  elif flipY:
    kBitmapFlippedY
  else:
    kBitmapUnflipped

iterator cells[W, H: static int](map: LdtkMap[W, H]): IVec2 =
  for x in 0'i32 ..< W:
    for y in 0'i32 ..< H:
      yield ivec2(x, y)

iterator activeRules(layerDef: LdtkLayerDef): LdtkAutoRuleDef =
  for group in layerDef.autoRuleGroups:
    if group.active:
      for rule in group.rules:
        if rule.active:
          yield rule

iterator flips(rule: LdtkAutoRuleDef): (bool, bool) =
  yield (false, false)
  if rule.flipX:
    yield (true, false)
  if rule.flipY:
    yield (false, true)
  if rule.flipX and rule.flipY:
    yield (true, true)

proc draw*[W, H: static int](
    map: LdtkMap[W, H],
    tileset: LCDBitmapTable,
    layerDef: LdtkLayerDef,
    target: LCDBitmap,
    rng: var Rand,
) =
  ## Draws the map into target by applying autoRuleGroups from layerDef
  target.drawContext:
    for cell in map.cells:
      block cellBlock:
        for rule in layerDef.activeRules:
          if rng.rand(1.0) > rule.chance:
            continue
          var matched = false
          for (fx, fy) in rule.flips:
            if matchesPattern(map, rule, cell, fx, fy):
              matched = true
              if rule.tileRectsIds.len > 0:
                let chosen = rule.tileRectsIds[rng.rand(rule.tileRectsIds.len - 1)]
                if chosen.len > 0:
                  let px = cell * map.tileSize
                  tileset.getBitmap(chosen[0].int).draw(
                    px.x.int, px.y.int, bitmapFlip(fx, fy)
                  )
          if matched and rule.breakOnMatch:
            break cellBlock

proc newBitmap*[W, H: static int](
    map: LdtkMap[W, H], tileset: LCDBitmapTable, layerDef: LdtkLayerDef, rng: var Rand
): LCDBitmap =
  ## Creates a bitmap sized W*tileSize × H*tileSize and draws the map into it
  result = playdate.graphics.newBitmap(
    (W * map.tileSize).int, (H * map.tileSize).int, kColorClear
  )
  map.draw(tileset, layerDef, result, rng)
