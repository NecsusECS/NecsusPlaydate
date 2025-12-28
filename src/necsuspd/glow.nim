import vmath, perlin, fpvec, fixedpoint, dither, easing

when defined(simulator) or defined(device) or defined(nimsuggest) or defined(nimcheck):
  import playdate/api
else:
  import ../../tests/stubs/playdate_api

type
  GlowConfig* {.requiresInit.} = object
    size, frames: int32
    baseFade: FPInt
    color: LCDSolidColor
    noise: Noise
    dither: DitherModes
    radiusEasing, timeEasing, zEasing: EasingFunc

  GlowFrameInput {.requiresInit.} = object
    frame: int32
    radius: FPInt
    center: FPVec2
    noiseZ: int32
    conf: ptr GlowConfig

proc `=copy`*(x: var GlowConfig, y: GlowConfig) {.error.}

proc newGlowConfig*(
    size, frames: int32,
    baseFade: float = 2.0,
    color: LCDSolidColor = kColorWhite,
    dither: DitherModes = DitherModes.Bayer8x8,
    radiusEasing: EasingFunc = easeInExpo,
    timeEasing: EasingFunc = easeOutExpoBoomerang,
    zEasing: EasingFunc = easeLinearBoomerang,
    seed: uint32 = 4096,
): GlowConfig =
  return GlowConfig(
    size: size,
    frames: frames,
    baseFade: baseFade.fp(),
    color: color,
    dither: dither,
    noise: newNoise(seed),
    radiusEasing: radiusEasing,
    timeEasing: timeEasing,
    zEasing: zEasing,
  )

proc width*(frame: GlowFrameInput): auto =
  frame.conf.size

proc height*(frame: GlowFrameInput): auto =
  frame.conf.size

proc getPixel*(frame: GlowFrameInput, x, y: int): int =
  ## Treating `GlowFrameInput` as an image, this calculates the grayscale color for
  ## each point

  # Fade the image near the edges by calculating the percent distance to the radius squared
  let radius = frame.center.dist(fpvec2(x, y)) / frame.radius
  let radiusScale = 1.fp() - frame.conf.radiusEasing(radius.toFloat()).fp()
  if radius > 1.fp():
    return 0

  # Adjust this pixel based on the noise at this position
  let noiseScale = frame.conf.noise.simplex(x div 2, y div 2, frame.noiseZ).fp()

  # Adjust the pixels based on the overall time progression
  let timeScale = frame.conf.timeEasing(frame.frame / frame.conf.frames).fp()

  let fade = noiseScale * radiusScale * frame.conf.baseFade * timeScale

  return clamp(toInt(fade * 255), 0, 255)

proc setPixel(img: var LCDBitmap, x, y, color: int) =
  if color == 255:
    img.set(x, y, kColorWhite)

static:
  assert(BlackAndWhiteIntPalette is Palette[int])
  assert(GlowFrameInput is InputImage[int])

proc noiseZ(conf: GlowConfig, frame: int32): int32 =
  ## To make the noise loop seamlessly, we calculate the noise position in 3d space.
  ## The `(x, y)` is the coordinates of the image being generated. Then the `z` is
  ## is a point moving forward.
  return int32(conf.zEasing(frame / conf.frames) * conf.frames.float32)

proc drawFrame*[T](conf: GlowConfig, frame: int32, target: var T) =
  ## Builds a single frame for a glow animation
  assert(frame in 0 ..< conf.frames)
  static:
    assert(T is OutputImage[int])

  let center = conf.size div 2
  let frame = GlowFrameInput(
    frame: frame,
    center: fpvec2(center, center),
    radius: center.fp(),
    conf: addr conf,
    noiseZ: conf.noiseZ(frame),
  )

  dither(frame, target, conf.dither, BlackAndWhiteIntPalette, IntQuantizer)

proc buildFrame*(conf: GlowConfig, frame: int32): LCDBitmap =
  result = playdate.graphics.newBitmap(conf.size, conf.size, conf.color)
  discard
    result.setBitmapMask(playdate.graphics.newBitmap(conf.size, conf.size, kColorBlack))
  var mask = result.getBitmapMask()
  drawFrame(conf, frame, mask)

proc buildFrames*(conf: GlowConfig): seq[LCDBitmap] =
  ## Builds all frames
  result = newSeqOfCap[LCDBitmap](conf.frames)
  for frame in 0 ..< conf.frames:
    result.add(conf.buildFrame(frame))
