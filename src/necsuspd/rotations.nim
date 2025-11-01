import
  std/strformat,
  fixedpoint,
  necsus,
  playdate/api,
  vmath,
  loading,
  util,
  aseprite,
  sprite,
  fpvec,
  assetBag

const ROTATIONS = 64'i32 ## The number of rotations for game objects to generate

type
  GameObjDef*[SheetId, Anims, Keyframes] = object
    ## The configuration for a single game object
    sheetId: SheetId
    data: string
    ignoreAnims: set[Anims]
    ignoreKeyframes: set[Keyframes]

  GameObjDefs*[K, SheetId, Anims, Keyframes] =
    array[K, GameObjDef[SheetId, Anims, Keyframes]] ## An indexed group of game objects

  ObjAnims*[Anims] = object
    ## `anims` is a table of generated animations for each game object
    ## `tables` is the base sprite sheets for each game object
    anims: array[ROTATIONS, array[Anims, AnimationDef]]
    table: seq[LCDBitmap]

proc `=copy`[SheetId, Anims, Keyframes](
  a: var GameObjDef[SheetId, Anims, Keyframes], b: GameObjDef[SheetId, Anims, Keyframes]
) {.error.}

proc defineGameObj*[SheetId, Anims, Keyframes](
    sheetId: SheetId,
    data: string,
    ignoreAnims: set[Anims] = {},
    ignoreKeyframes: set[Keyframes] = {},
): auto =
  ## Define a game object
  return GameObjDef[SheetId, Anims, Keyframes](
    sheetId: sheetId,
    data: data,
    ignoreAnims: ignoreAnims,
    ignoreKeyframes: ignoreKeyframes,
  )

type RotationMutation = tuple[rotation, sourceFrameCount, baseCellIdx: int32]
  ## Defines the mutation being calculated for a game object

proc angle(mutate: RotationMutation): FPInt =
  ## The angle in degress at which a mutation is happening
  360.fp / ROTATIONS.fp * mutate.rotation

const RESIZE_RATIO = 1.0
  ## Game objects are resized as they are rotated to improve the precision of the rotation

proc buildBaseSheets*[K, SheetId, Anims, Keyframes](
    gameObjDefs: GameObjDefs[K, SheetId, Anims, Keyframes]
): array[K, SpriteSheet] {.compileTime.} =
  ## Precalculates sprite sheets for each game object
  for obj in K:
    result[obj] = loadAsepriteJson(gameObjDefs[obj].data)

proc fillTable[SheetId, Anims, Keyframes: enum](
    target: var ObjAnims[Anims],
    spriteSheet: SpriteSheet,
    obj: GameObjDef[SheetId, Anims, Keyframes],
    source: LCDBitmapTable,
    mutate: RotationMutation,
) =
  ## Populates the target with the frames from the source at the given rotation index
  var size: tuple[width, height: int]

  for frame in 0 ..< mutate.sourceFrameCount:
    let rotated = source
      .getBitmap(frame)
      .rotated(mutate.angle.toFloat, xScale = RESIZE_RATIO, yScale = RESIZE_RATIO).bitmap
    target.table[mutate.baseCellIdx + frame] = rotated
    size = rotated.getSize

  let baseAnims = animationTable[Anims, Keyframes](
    spriteSheet,
    obj.sheetId,
    ignore = obj.ignoreAnims,
    ignoreKeyframes = obj.ignoreKeyframes,
  )

  for anim in Anims:
    if anim notin obj.ignoreAnims:
      target.anims[mutate.rotation][anim] =
        modify(baseAnims[anim], mutate.baseCellIdx, (AnchorMiddle, ivec2(0, 0)))

proc defineObjAnims[SheetId, Anims, Keyframes](
    obj: GameObjDef[SheetId, Anims, Keyframes],
    sheet: SpriteSheet,
    source: LCDBitmapTable,
): ObjAnims[Anims] =
  let frames = source.getBitmapTableInfo.count.int32
  result.table = newSeq[LCDBitmap](frames * ROTATIONS)
  for rotation in 0'i32 ..< ROTATIONS:
    let mutation: RotationMutation = (rotation, frames, rotation * frames)
    result.fillTable(sheet, obj, source, mutation)

proc loadObjAnims*[K, SheetId, Anims, Keyframes](
    target: var array[K, ObjAnims[Anims]],
    defs: GameObjDefs[K, SheetId, Anims, Keyframes],
    sheets: array[K, SpriteSheet],
    task: Bundle[LoadTasks],
    assets: AssetBag,
) =
  ## Reads and precalculates the sprite sheets for all game objects
  for key in K:
    task.execTask(fmt"{key} sheet", K, key):
      target[key] =
        defineObjAnims(defs[key], sheets[key], assets.sheet(defs[key].sheetId))

proc chooseAngleBucket(angle: FixedPoint): int32 =
  ## Given an angle, chooses the rotation bucket to use
  const anglesPerBucket = 360.fp / ROTATIONS
  const halfAnglesPerBucket = anglesPerBucket / 2
  let fixedAngle = (angle + halfAnglesPerBucket).fixAngleDegrees
  result = toInt(fixedAngle div anglesPerBucket)

proc animationDef*[Anims](
    obj: ObjAnims[Anims], anim: Anims, angle: FixedPoint
): AnimationDef =
  ## Returns the animation definition for a game object the given angle
  let bucket = angle.chooseAngleBucket()
  assert(
    bucket in (0 ..< obj.anims.len), fmt"Invalid bucket {bucket} for angle {angle}"
  )
  assert(obj.anims[bucket][anim] != nil, fmt"Animation not found for angle {angle}")
  return obj.anims[bucket][anim]

proc animation*[Anims](
    obj: ObjAnims[Anims],
    anim: Anims,
    angle: FPInt,
    zIndex: enum,
    absolutePos: bool = false,
): Animation =
  ## Returns the animation for a game object the given angle
  assert(obj.table.len > 0, fmt"Object sheet not loaded: {obj}")
  let anim = obj.animationDef(anim, angle)
  return newSheet(obj.table, anim, zIndex, absolutePos)
