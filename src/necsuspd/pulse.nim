import vmath, perlin, circle, util, percent, fpvec, fixedpoint, import_playdate

importPlaydateApi()

export fixedpoint.`<=`, fixedpoint.`$`, fixedpoint.`<`

type PulseConfig*[S: static int] = object
  size, steps, thickness: int32
  fgColor: LCDSolidColor
  noise: array[S, array[S, FPInt]]

proc `=copy`*[T: static int](x: var PulseConfig[T], y: PulseConfig[T]) {.error.}

proc newPulseConfig*(
    size: static int32,
    steps, thickness: int32,
    fgColor: LCDSolidColor = kColorWhite,
    seed: static int32 = 1029384756,
): PulseConfig[size] =
  ## Creates a new pulse configuration
  result =
    PulseConfig[size](size: size, steps: steps, thickness: thickness, fgColor: fgColor)

  let noise = newNoise(seed)
  for y in 0 ..< size:
    for x in 0 ..< size:
      result.noise[y][x] = noise.simplex(x, y).fp()

proc buildPulseStep*(config: static PulseConfig, frame: int32): LCDBitmap =
  ## Builds a single step of the pulse animation.
  const maxRadius = config.size div 2

  result = playdate.graphics.newBitmap(config.size, config.size, config.fgColor)
  discard result.setBitmapMask(
    playdate.graphics.newBitmap(config.size, config.size, kColorBlack)
  )
  var mask = result.getBitmapMask()

  let circleT = fp(frame + 1) / config.steps.fp()
  let localMaxRadius = toInt(circleT * maxRadius)
  let localMinRadius = max(localMaxRadius - config.thickness, 0)
  let maxRadiusSq = fp(localMaxRadius ^ 2)
  let minRadiusSq = fp(localMinRadius ^ 2)

  const center = fpvec2(maxRadius, maxRadius)
  const canvas: CircleCanvas = (x: 0'i32, y: 0'i32, w: config.size, h: config.size)

  # The overall progression of this frame in the pulse. This allows us to fade
  # out the pulse over time.
  let overallT = min(fp(config.steps - frame) / config.steps.fp() / 0.8.fp(), 1.fp())

  for (x, y) in circlePixels(
    center.x.toInt(), center.y.toInt(), localMinRadius, localMaxRadius, canvas
  ):
    let radiusSq = center.distSq(fpvec2(x, y))

    # Calculate the percent of this radius relative to the min and max radius.
    # This allows us to draw strong lines at the outer edges of the pulse.
    let radiusT = (radiusSq - minRadiusSq) / (maxRadiusSq - minRadiusSq)

    let t = radiusT * overallT

    if config.noise[y][x] <= t:
      mask.set(x, y, kColorWhite)

proc buildPulseFrames*(config: static PulseConfig): seq[LCDBitmap] =
  ## Builds a sequence of LCDBitmap frames for a pulse effect.
  result = newSeq[LCDBitmap](config.steps)
  for i in 0'i32 ..< config.steps:
    result[i] = buildPulseStep(config, i)
