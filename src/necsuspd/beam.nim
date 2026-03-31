import import_playdate, vmath, std/[random, math], fpvec, draw

const
  MIN_TICK_SPACING = 4
  MAX_TICK_SPACING = 10
  MIN_TICK_HALF_LEN = 1
  MAX_TICK_HALF_LEN = 6

const
  SINUS_STEP = 2.0
  SINUS_WAVELENGTH = 20.0
  SINUS_MAX_AMPLITUDE = 3.0

proc drawCombBeam*(img: LCDBitmap, a, b: IVec2, rng: var Rand) =
  ## Draws a comb beam from `a` to `b`. A solid core line runs between the
  ## two points, with randomly-spaced perpendicular tick marks of random length.
  img.getBitmapMask.clear(kColorBlack)
  img.getBitmapMask.drawContext:
    playdate.graphics.drawLine(a.x.int, a.y.int, b.x.int, b.y.int, 1, kColorWhite)

    let delta = (b - a).toFPVec2()
    let dist = delta.length
    if dist < fp(1):
      return

    let dir = delta.normalize()
    let perp = dir.perpendicular()

    var t = fp(rng.rand(MIN_TICK_SPACING .. MAX_TICK_SPACING))
    while t < dist:
      let point = toFPVec2(a) + dir * t
      let halfLen = fp(rng.rand(MIN_TICK_HALF_LEN .. MAX_TICK_HALF_LEN))
      let tickStart = toIVec2(point - perp * halfLen)
      let tickEnd = toIVec2(point + perp * halfLen)
      playdate.graphics.drawLine(
        tickStart.x.int, tickStart.y.int, tickEnd.x.int, tickEnd.y.int, 1, kColorWhite
      )
      t += fp(rng.rand(MIN_TICK_SPACING .. MAX_TICK_SPACING))

proc drawSinusoidalBeam*(img: LCDBitmap, a, b: IVec2, phase: float) =
  ## Draws two sinusoidal waves from `a` to `b`, tapering at both endpoints.
  ## `phase` controls the wave animation offset.
  img.getBitmapMask.clear(kColorBlack)
  img.getBitmapMask.drawContext:
    let delta = (b - a).toFPVec2()
    let dist = delta.length.toFloat()
    if dist < 1.0:
      return

    let dir = delta.normalize()
    let perp = dir.perpendicular()

    var prevPoint1 = toIVec2(toFPVec2(a))
    var prevPoint2 = prevPoint1
    var first = true

    var t = 0.0
    while t <= dist:
      let taper = sin(t / dist * PI)
      let wavePhase1 = (t / SINUS_WAVELENGTH) * 2.0 * PI + phase
      let wavePhase2 = wavePhase1 + PI
      let offset1 = sin(wavePhase1) * SINUS_MAX_AMPLITUDE * taper
      let offset2 = sin(wavePhase2) * SINUS_MAX_AMPLITUDE * taper
      let base = toFPVec2(a) + dir * fp(t)
      let point1 = toIVec2(base + perp * fp(offset1))
      let point2 = toIVec2(base + perp * fp(offset2))
      if not first:
        playdate.graphics.drawLine(
          prevPoint1.x.int, prevPoint1.y.int, point1.x.int, point1.y.int, 1, kColorWhite
        )
        playdate.graphics.drawLine(
          prevPoint2.x.int, prevPoint2.y.int, point2.x.int, point2.y.int, 1, kColorWhite
        )
      prevPoint1 = point1
      prevPoint2 = point2
      first = false
      t += SINUS_STEP

let sparse = block:
  ## A sparse checkerboard pattern used for rendering the laser
  let X = kColorBlack
  let O = kColorWhite
  makePattern(
    [X, X, X, O, X, X, X, O],
    [X, O, X, X, X, O, X, X],
    [X, X, O, X, X, X, O, X],
    [O, X, X, X, O, X, X, X],
    [X, X, X, O, X, X, X, O],
    [X, O, X, X, X, O, X, X],
    [X, X, O, X, X, X, O, X],
    [O, X, X, X, O, X, X, X],
  )

let checkered = block:
  ## A checkerboard pattern used for rendering the laser
  let X = kColorBlack
  let O = kColorWhite
  makePattern(
    [X, O, X, O, X, O, X, O],
    [O, X, O, X, O, X, O, X],
    [X, O, X, O, X, O, X, O],
    [O, X, O, X, O, X, O, X],
    [X, O, X, O, X, O, X, O],
    [O, X, O, X, O, X, O, X],
    [X, O, X, O, X, O, X, O],
    [O, X, O, X, O, X, O, X],
  )

proc drawAnimatedLine(ax, ay, bx, by: int, step: uint) =
  ## Draws a single line segment using the animated laser style for the given `step`.
  const lineWidths = [2, 1, 1, 1]
  let lw = lineWidths[int(step mod 4)]
  case step mod 4
  of 3:
    playdate.graphics.drawLine(ax, ay, bx, by, lw, sparse)
  of 2:
    playdate.graphics.drawLine(ax, ay, bx, by, lw, checkered)
  else:
    playdate.graphics.drawLine(ax, ay, bx, by, lw, kColorWhite)

proc drawJaggedSegment(
    rng: var Rand,
    perp: FPVec2,
    beamOrigin, beamTarget: IVec2,
    beamDistSq: float,
    a, b: IVec2,
    width, depth: int32,
    step: uint,
) =
  if a.distSq(b) < 100 or depth > 5:
    drawAnimatedLine(a.x.int, a.y.int, b.x.int, b.y.int, step)
    return
  let mid = a + ((b - a) div 2)
  let beamDelta = beamTarget - beamOrigin
  let projected =
    float(mid.x - beamOrigin.x) * float(beamDelta.x) +
    float(mid.y - beamOrigin.y) * float(beamDelta.y)
  let s = sin(projected / beamDistSq * PI)
  let taper = s * s
  let maxJitter = max(1'i32, int32(float(width * 8 div (depth + 3)) * taper))
  let offset = (rng.rand(0'i32 .. maxJitter) - maxJitter div 2).fp
  let displaced = toIVec2(mid.toFPVec2() + perp * offset)
  drawJaggedSegment(
    rng, perp, beamOrigin, beamTarget, beamDistSq, a, displaced, width, depth + 1, step
  )
  drawJaggedSegment(
    rng, perp, beamOrigin, beamTarget, beamDistSq, displaced, b, width, depth + 1, step
  )

proc drawJaggedBeam*(img: LCDBitmap, step: uint, origin, target: IVec2): bool =
  ## Draws an animated jagged beam from `origin` to `target`.
  ## The path is deterministic (derived from the endpoints) and stays the same across animation frames.
  ## `step` controls the animation; uses the same drawing style as the laser beam.
  ## Returns false when the animation is complete (step >= 3).
  const width = 20'i32
  let seed =
    BiggestUInt(origin.x) * 73856093 xor BiggestUInt(origin.y) * 19349663 xor
    BiggestUInt(target.x) * 83492791 xor BiggestUInt(target.y) * 53842781
  var rng = initRand(seed.int64)
  let delta = target - origin
  let beamDistSq = float(delta.x * delta.x + delta.y * delta.y)
  let perp = delta.toFPVec2().perpendicular().normalize()

  img.getBitmapMask.clear(kColorBlack)
  img.getBitmapMask.drawContext:
    drawJaggedSegment(
      rng, perp, origin, target, beamDistSq, origin, target, width, 0, step
    )
  return step < 3

proc drawLaserBeam*(img: LCDBitmap, step: uint, origin: IVec2, target: IVec2): bool =
  ## Draws an animated laser beam from `origin` to `target`.
  ## `step` is the animation frame counter. Returns false when the animation is complete (step >= 3).
  img.getBitmapMask.clear(kColorBlack)
  img.getBitmapMask.drawContext:
    drawAnimatedLine(origin.x.int, origin.y.int, target.x.int, target.y.int, step)
  return step < 3
