import
  std/strformat,
  fixedpoint,
  necsus,
  import_playdate,
  vmath,
  loading,
  util,
  aseprite,
  anim,
  fpvec,
  assetBag

const
  ROTATIONS = 64'i32 ## The number of rotations for game objects to generate

  HISTORY_SIZE* = 5'i32
    ## How many recently-abandoned rotation buckets are remembered to avoid flip-flopping

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
    table: ref seq[HEBitmap]

  BucketHistory* = object
    ## Tracks the historic values of rotations for an object to prevent flickering
    ## back and forth across a boundary
    nextIdx, used: int32
    entries: array[HISTORY_SIZE, int32]

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
  for frame in 0 ..< mutate.sourceFrameCount:
    let rotated = source
      .getBitmap(frame)
      .rotated(mutate.angle.toFloat, xScale = RESIZE_RATIO, yScale = RESIZE_RATIO).bitmap
    target.table[mutate.baseCellIdx + frame] = fromLCDBitmap(rotated)

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
  let halfRots = ROTATIONS div 2
  let quarter = ROTATIONS div 4
  result = RotAnims[Anims](table: new(seq[HEBitmap]))
  result.table[] = newSeq[HEBitmap](frames * (halfRots + 1))
  for rotation in 0'i32 ..< quarter + 1:
    let mutation: RotationMutation = (rotation, frames, (rotation + quarter) * frames)
    result.fillTable(sheet, obj, source, mutation)
  for rotation in ROTATIONS - quarter ..< ROTATIONS:
    let mutation: RotationMutation =
      (rotation, frames, (rotation - (ROTATIONS - quarter)) * frames)
    result.fillTable(sheet, obj, source, mutation)
  for rotation in quarter + 1 ..< ROTATIONS - quarter:
    let mirrorCellIdx = (ROTATIONS * 3 div 4 - rotation) * frames
    let mutation: RotationMutation = (rotation, frames, mirrorCellIdx)
    result.fillTablePreRotated(sheet, obj, mutation, flipY = true)

proc fillTablePreRotated[SheetId, Anims, Keyframes](
    target: var RotAnims[Anims],
    spriteSheet: SpriteSheet,
    obj: RotAnimDef[SheetId, Anims, Keyframes],
    mutate: RotationMutation,
    flipY: bool = false,
) =
  let baseAnims = animationTable[Anims, Keyframes](
    spriteSheet,
    obj.sheetId,
    ignore = obj.ignoreAnims,
    ignoreKeyframes = obj.ignoreKeyframes,
  )

  for anim in Anims:
    if anim notin obj.ignoreAnims:
      target.anims[mutate.rotation][anim] =
        modify(baseAnims[anim], mutate.baseCellIdx, (AnchorMiddle, ivec2(0, 0)), flipY)

proc definePreRotAnims[SheetId, Anims, Keyframes](
    obj: RotAnimDef[SheetId, Anims, Keyframes],
    sheet: SpriteSheet,
    frames: ref seq[HEBitmap],
): RotAnims[Anims] =
  let totalFrames = frames[].len.int32
  let halfRots = ROTATIONS div 2
  let expected = sheet.frames.len.int32 * (halfRots + 1)
  assert(
    totalFrames == expected,
    fmt"Pre-rotated bitmap table frame count mismatch: got {totalFrames}, expected {expected}",
  )
  let quarter = ROTATIONS div 4
  let framesPerRotation = totalFrames div (halfRots + 1)
  result = RotAnims[Anims](table: frames)
  for rotation in 0'i32 ..< quarter + 1:
    let mutation: RotationMutation =
      (rotation, framesPerRotation, (rotation + quarter) * framesPerRotation)
    result.fillTablePreRotated(sheet, obj, mutation)
  for rotation in quarter + 1 ..< ROTATIONS - quarter:
    let mirrorCellIdx = (ROTATIONS * 3 div 4 - rotation) * framesPerRotation
    let mutation: RotationMutation = (rotation, framesPerRotation, mirrorCellIdx)
    result.fillTablePreRotated(sheet, obj, mutation, flipY = true)
  for rotation in ROTATIONS - quarter ..< ROTATIONS:
    let mutation: RotationMutation = (
      rotation,
      framesPerRotation,
      (rotation - (ROTATIONS - quarter)) * framesPerRotation,
    )
    result.fillTablePreRotated(sheet, obj, mutation)

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

proc calculatePreRotAnims*[K, SheetId, Anims, Keyframes](
    target: var array[K, RotAnims[Anims]],
    defs: RotAnimDefs[K, SheetId, Anims, Keyframes],
    sheets: array[K, SpriteSheet],
    task: Bundle[LoadTasks],
    assets: AssetBag,
) =
  ## Reads pre-rotated sprite sheets for all game objects; all 64 rotations must
  ## already be present in the sheet (ROTATIONS * framesPerAnim total frames).
  ## The sheet is released from the AssetBag after extraction to free memory.
  for key in K:
    task.execTask(fmt"{key} sheet", K, key):
      target[key] =
        definePreRotAnims(defs[key], sheets[key], assets.heSheet(defs[key].sheetId))

proc wrapDegrees(angle: FixedPoint): FixedPoint =
  ## Normalizes an angle to be within 0 ..< 360 degrees
  result = angle
  while result >= 360.fp:
    result -= 360.fp
  while result < fp(0):
    result += 360.fp

proc chooseAngleBucket(angle: FixedPoint): int32 =
  ## Given an angle, chooses the rotation bucket to use
  const anglesPerBucket = 360.fp / ROTATIONS
  const halfAnglesPerBucket = anglesPerBucket / 2
  let fixedAngle = (angle + halfAnglesPerBucket).wrapDegrees
  result = toInt(fixedAngle div anglesPerBucket)

proc stickyAngleBucket*(angle: FixedPoint, history: var BucketHistory): int32 =
  ## Chooses the rotation bucket to use for `angle`, refusing to flip back to a
  ## recently-abandoned bucket. This prevents flickering across a bucket boundary.
  ## Always recording the outcome (even when unchanged) lets an old bucket age
  ## out of history, so a genuine switch back is still allowed eventually.
  result = angle.chooseAngleBucket()
  for i in 0 ..< history.used:
    if history.entries[i] == result:
      result = history.entries[(history.nextIdx + HISTORY_SIZE - 1) mod HISTORY_SIZE]
      break

  history.entries[history.nextIdx] = result
  history.nextIdx = (history.nextIdx + 1) mod HISTORY_SIZE
  history.used = min(HISTORY_SIZE, history.used + 1)

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

proc animationDef*[Anims](
    obj: RotAnims[Anims], anim: Anims, angle: FixedPoint, history: var BucketHistory
): AnimationDef =
  ## Returns the animation definition for a game object at the given angle, using
  ## `stickyAngleBucket` to resist flicker at the mirrored-sprite seam
  let bucket = angle.stickyAngleBucket(history)
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
): (Drawable, Anim) =
  ## Returns the animation for a game object the given angle
  assert(obj != nil, fmt"Object sheet not loaded")
  let animDef = obj.animationDef(anim, angle)
  return newHESheet(obj.table, animDef, zIndex, absolutePos)
