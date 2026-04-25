import
  json_schema_import,
  necsus,
  vmath,
  std/[options, strutils, sequtils, json],
  import_playdate,
  drawable,
  positioned,
  util,
  assetBag,
  draw

# Pulled from https://ldtk.io/docs/game-dev/json-overview/json-schema/
importJsonSchema("./ldtk-schema.json", "Ldtk")

template getLevel*(data: LdtkJsonRoot, levelIdx: int32): LdtkLevel =
  data.levels[levelIdx]

proc findSourceImage(
    data: LdtkJsonRoot,
    assets: SharedOrT[AssetBag],
    sheets: typedesc[enum],
    layer: LdtkLayerInstance,
): Option[LCDBitmapTable] =
  ## Searches for the image that contains the tileset for a layer
  let layerTilesetUid = layer.tilesetDefUid.orElse:
    log "Layer has no tileset definition UID: ", layer.identifier
    return none(LCDBitmapTable)

  for it in data.defs.tilesets:
    if it.uid == layerTilesetUid:
      return some(assets.unwrap.sheet(parseEnum[sheets](it.identifier)))

  raiseAssert "Could not find source image for layer"

proc findBackgroundImage(
    level: LdtkLevel, assets: SharedOrT[AssetBag], images: typedesc[enum]
): LCDBitmap =
  ## Returns the base background bitmap to use for a level
  let bgPath = level.bgRelPath.orElse:
    raiseAssert "Could not find 'bgRelPath' key for level: " & level.identifier
  let key = bgPath.findAssetBagKey(images)
  log "Loading level background from ", key, " based on ", level.bgRelPath
  return assets.unwrap.asset(key)

iterator layers*(level: LdtkLevel): lent LdtkLayerInstance =
  for layer in level.layerInstances:
    yield layer

template withLayer*(level: LdtkLevel, id: string, varname, exec: untyped): untyped =
  ## Searches for a layer in the given level
  block:
    var found = false
    var varname {.cursor.}: LdtkLayerInstance
    for layer in level.layers:
      if layer.identifier == id:
        found = true
        varname = layer
    assert(found, "Could not find layer")
    exec

iterator allTiles*(layer: LdtkLayerInstance): lent LdtkTile =
  ## Yields all the tiles that need to be drawn
  for tile in layer.autoLayerTiles:
    yield tile
  for tile in layer.gridTiles:
    yield tile

proc backgroundFlip(level: LdtkLevel): LCDBitmapFlip =
  ## Returns the background flip
  for field in level.fieldInstances:
    if field.identifier == "BackgroundFlip":
      var value = field.value.getStr("k")
      if value.len > 0:
        value[0] = value[0].toLowerAscii()
        return parseEnum[LCDBitmapFlip](value)

proc flipState(tile: LdtkTile): LCDBitmapFlip =
  const mapping = [kBitmapUnflipped, kBitmapFlippedX, kBitmapFlippedY, kBitmapFlippedXY]
  return mapping[tile.f]

proc drawLevel*(
    level: LdtkLevel,
    data: LdtkJsonRoot,
    assets: SharedOrT[AssetBag],
    sheets: typedesc[enum],
    images: typedesc[enum],
): LCDBitmap =
  result = playdate.graphics.newBitmap(level.pxWid.int, level.pxHei.int, kColorBlack)
  result.drawContext:
    playdate.graphics.setDrawMode(kDrawModeCopy)
    findBackgroundImage(level, assets, images).draw(0, 0, level.backgroundFlip)
    for layer in level.layers:
      if source from findSourceImage(data, assets, sheets, layer):
        log "Drawing layer: ", layer.identifier
        for tile in layer.allTiles:
          source.getBitmap(tile.t.int).draw(
            tile.px[0].int, tile.px[1].int, tile.flipState
          )
      else:
        log "Skipping layer without a source image: ", layer.identifier

iterator entities*(level {.byref.}: LdtkLevel): lent LdtkEntityInstance =
  ## Yields all entities in a level
  for layer in level.layers:
    if layer.type == "Entities":
      for entity in layer.entityInstances:
        yield entity

iterator entities*(level: LdtkLevel, kind: string): lent LdtkEntityInstance =
  ## Produces all the targets for a level
  for entity in level.entities:
    if entity.identifier == kind:
      yield entity

proc `[]`*(layer: LdtkLayerInstance, coord: IVec2): int32 =
  ## Returns the entityID at the given position
  assert(coord.x >= 0)
  assert(coord.y >= 0)
  assert(coord.x < layer.cWid.int32)
  assert(coord.y < layer.cHei.int32)
  return layer.intGridCsv[coord.y.int32 * layer.cWid.int32 + coord.x.int32].int32

proc contains*(layer: LdtkLayerInstance, coord: IVec2): bool =
  ## Checks if a coordinate is within the bounds of the layer
  return coord.x in 0'i32 ..< layer.cWid.int32 and coord.y in 0'i32 ..< layer.cHei.int32

proc tileset*(root: LdtkJsonRoot, tile: LdtkTilesetRect): Option[LdtkTilesetDef] =
  ## Returns the tileset for an entity
  for tileset in root.defs.tilesets:
    if tileset.uid == tile.tilesetUid:
      return some(tileset)

proc tileset*(root: LdtkJsonRoot, entity: LdtkEntityInstance): Option[LdtkTilesetDef] =
  ## Returns the tileset for an entity
  entity.tile.withValue(tile):
    return tileset(root, tile)
