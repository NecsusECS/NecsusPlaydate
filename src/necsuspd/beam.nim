import import_playdate, vmath, std/[random, math], fpvec, draw

const
  MIN_TICK_SPACING = 4
  MAX_TICK_SPACING = 10
  MIN_TICK_HALF_LEN = 1
  MAX_TICK_HALF_LEN = 6

const
  SINUS_STEP = 2'i32
  SINUS_WAVELENGTH = 20'i32
  SINUS_MAX_AMPLITUDE = 3'i32

const
  COMB_BEAM_SPREAD* = int32(MAX_TICK_HALF_LEN + 1)
    ## How far `drawCombBeam` strays from the line between its endpoints
  SINUS_BEAM_SPREAD* = SINUS_MAX_AMPLITUDE + 1
    ## How far `drawSinusoidalBeam` strays from the line between its endpoints
  LASER_BEAM_SPREAD* = 2'i32
    ## How far `drawLaserBeam` strays from the line between its endpoints
  JAGGED_BEAM_SPREAD* = 48'i32
    ## How far `drawJaggedBeam` strays from the line between its endpoints.

const SINE_STEPS = 256'i32 ## Angle steps in a full turn for `sinSteps`

const SINE_TABLE = block:
  var table: array[SINE_STEPS, FPInt]
  for i in 0 ..< SINE_STEPS:
    table[i] = fp(sin(i.float * 2.0 * PI / SINE_STEPS.float))
  table

proc sinSteps(angle: int32): FPInt {.inline.} =
  ## The sine of an angle measured in 1/SINE_STEPS of a turn
  SINE_TABLE[angle and (SINE_STEPS - 1)]

proc clearAround(a, b: IVec2, spread: int32) =
  ## Clears the bounding box of `a` and `b`, grown by `spread`
  playdate.graphics.fillRect(
    int(min(a.x, b.x) - spread),
    int(min(a.y, b.y) - spread),
    int(abs(b.x - a.x) + spread * 2 + 1),
    int(abs(b.y - a.y) + spread * 2 + 1),
    kColorBlack,
  )

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
  img.getBitmapMask.drawContext:
    clearAround(a, b, SINUS_BEAM_SPREAD)
    let delta = (b - a).toFPVec2()
    let dist = delta.length.toInt
    if dist < 1:
      return

    let dir = delta.normalize()
    let perp = dir.perpendicular()
    let phaseSteps = int32(phase * SINE_STEPS.float / (2.0 * PI))

    var prevPoint1 = toIVec2(toFPVec2(a))
    var prevPoint2 = prevPoint1
    var first = true

    var t = 0'i32
    while t <= dist:
      let taper = sinSteps(t * (SINE_STEPS div 2) div dist)
      let wave = sinSteps(t * SINE_STEPS div SINUS_WAVELENGTH + phaseSteps)
      let offset = wave * fp(SINUS_MAX_AMPLITUDE) * taper
      let base = toFPVec2(a) + dir * fp(t)
      let point1 = toIVec2(base + perp * offset)
      let point2 = toIVec2(base - perp * offset)
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

const CROSS_HATCH_CORNER = SINUS_WAVELENGTH div 4
  ## Distance along the beam between a zigzag's peaks and crossings

proc drawCrossHatchBeam*(img: LCDBitmap, a, b: IVec2, phase: float) =
  ## Draws two mirrored zigzags from `a` to `b` that cross every half
  ## wavelength, forming a chain of Xs that tapers at both endpoints.
  img.getBitmapMask.drawContext:
    clearAround(a, b, SINUS_BEAM_SPREAD)
    let delta = (b - a).toFPVec2()
    let dist = delta.length.toInt
    if dist < 1:
      return

    let dir = delta.normalize()
    let perp = dir.perpendicular()
    let shift =
      euclMod(int32(phase * SINUS_WAVELENGTH.float / (2.0 * PI)), SINUS_WAVELENGTH)

    var prevPoint1 = a
    var prevPoint2 = a
    template lineTo(next1, next2: IVec2) =
      let point1 = next1
      let point2 = next2
      playdate.graphics.drawLine(
        prevPoint1.x.int, prevPoint1.y.int, point1.x.int, point1.y.int, 1, kColorWhite
      )
      playdate.graphics.drawLine(
        prevPoint2.x.int, prevPoint2.y.int, point2.x.int, point2.y.int, 1, kColorWhite
      )
      prevPoint1 = point1
      prevPoint2 = point2

    var t = CROSS_HATCH_CORNER - (shift mod CROSS_HATCH_CORNER)
    while t < dist:
      const sides = [0'i32, 1, 0, -1]
      let side = sides[((t + shift) div CROSS_HATCH_CORNER) mod 4]
      let taper = sinSteps(t * (SINE_STEPS div 2) div dist)
      let offset = fp(SINUS_MAX_AMPLITUDE * side) * taper
      let base = toFPVec2(a) + dir * fp(t)
      lineTo(toIVec2(base + perp * offset), toIVec2(base - perp * offset))
      t += CROSS_HATCH_CORNER
    lineTo(b, b)

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
    beamDistSq: int32,
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
    (mid.x - beamOrigin.x) * beamDelta.x + (mid.y - beamOrigin.y) * beamDelta.y
  let s = sinSteps(projected * (SINE_STEPS div 2) div beamDistSq)
  let taper = s * s
  let maxJitter = max(1'i32, (fp(width * 8 div (depth + 3)) * taper).toInt)
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
  let beamDistSq = delta.x * delta.x + delta.y * delta.y
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
