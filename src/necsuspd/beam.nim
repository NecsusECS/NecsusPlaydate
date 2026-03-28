import import_playdate, vmath, std/[random, math], fpvec

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
  playdate.graphics.pushContext(img.getBitmapMask)
  try:
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
  finally:
    playdate.graphics.popContext()

proc drawSinusoidalBeam*(img: LCDBitmap, a, b: IVec2, phase: float) =
  ## Draws two sinusoidal waves from `a` to `b`, tapering at both endpoints.
  ## `phase` controls the wave animation offset.
  img.getBitmapMask.clear(kColorBlack)
  playdate.graphics.pushContext(img.getBitmapMask)
  try:
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
  finally:
    playdate.graphics.popContext()
