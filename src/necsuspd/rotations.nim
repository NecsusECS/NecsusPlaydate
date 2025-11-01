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
  RotAnimDef*[SheetId, Anims, Keyframes] = object
    ## The configuration for a single game object
    sheetId: SheetId
    data: string
    ignoreAnims: set[Anims]
    ignoreKeyframes: set[Keyframes]

  RotAnimDefs*[K, SheetId, Anims, Keyframes] =
    array[K, RotAnimDef[SheetId, Anims, Keyframes]] ## An indexed group of game objects

  RotAnims*[Anims] = ref object
    ## `anims` is a table of generated animations for each game object
    ## `tables` is the base sprite sheets for each game object
    anims: array[ROTATIONS, array[Anims, AnimationDef]]
    table: seq[LCDBitmap]

proc `=copy`[SheetId, Anims, Keyframes](
  a: var RotAnimDef[SheetId, Anims, Keyframes], b: RotAnimDef[SheetId, Anims, Keyframes]
) {.error.}

proc defineRotAnim*[SheetId, Anims, Keyframes](
    sheetId: SheetId,
    data: string,
    ignoreAnims: set[Anims] = {},
    ignoreKeyframes: set[Keyframes] = {},
): auto =
  ## Define a game object
  return RotAnimDef[SheetId, Anims, Keyframes](
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
    gameObjDefs: RotAnimDefs[K, SheetId, Anims, Keyframes]
): array[K, SpriteSheet] {.compileTime.} =
  ## Precalculates sprite sheets for each game object
  for obj in K:
    result[obj] = loadAsepriteJson(gameObjDefs[obj].data)

proc fillTable[SheetId, Anims, Keyframes: enum](
    target: var RotAnims[Anims],
    spriteSheet: SpriteSheet,
    obj: RotAnimDef[SheetId, Anims, Keyframes],
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

proc defineRotAnims[SheetId, Anims, Keyframes](
    obj: RotAnimDef[SheetId, Anims, Keyframes],
    sheet: SpriteSheet,
    source: LCDBitmapTable,
): RotAnims[Anims] =
  let frames = source.getBitmapTableInfo.count.int32
  result = RotAnims[Anims](table: newSeq[LCDBitmap](frames * ROTATIONS))
  for rotation in 0'i32 ..< ROTATIONS:
    let mutation: RotationMutation = (rotation, frames, rotation * frames)
    result.fillTable(sheet, obj, source, mutation)

proc calculateRotAnims*[K, SheetId, Anims, Keyframes](
    target: var array[K, RotAnims[Anims]],
    defs: RotAnimDefs[K, SheetId, Anims, Keyframes],
    sheets: array[K, SpriteSheet],
    task: Bundle[LoadTasks],
    assets: AssetBag,
) =
  ## Reads and precalculates the sprite sheets for all game objects
  for key in K:
    task.execTask(fmt"{key} sheet", K, key):
      target[key] =
        defineRotAnims(defs[key], sheets[key], assets.sheet(defs[key].sheetId))

proc chooseAngleBucket(angle: FixedPoint): int32 =
  ## Given an angle, chooses the rotation bucket to use
  const anglesPerBucket = 360.fp / ROTATIONS
  const halfAnglesPerBucket = anglesPerBucket / 2
  let fixedAngle = (angle + halfAnglesPerBucket).fixAngleDegrees
  result = toInt(fixedAngle div anglesPerBucket)

proc animationDef*[Anims](
    obj: RotAnims[Anims], anim: Anims, angle: FixedPoint
): AnimationDef =
  ## Returns the animation definition for a game object the given angle
  let bucket = angle.chooseAngleBucket()
  assert(
    bucket in (0 ..< obj.anims.len), fmt"Invalid bucket {bucket} for angle {angle}"
  )
  assert(obj.anims[bucket][anim] != nil, fmt"Animation not found for angle {angle}")
  return obj.anims[bucket][anim]

proc animation*[Anims](
    obj: RotAnims[Anims],
    anim: Anims,
    angle: FPInt,
    zIndex: enum,
    absolutePos: bool = false,
): Animation =
  ## Returns the animation for a game object the given angle
  assert(obj != nil, fmt"Object sheet not loaded")
  let anim = obj.animationDef(anim, angle)
  return newSheet(obj.table, anim, zIndex, absolutePos)
