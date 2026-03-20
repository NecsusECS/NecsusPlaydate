import import_playdate, vmath, std/random, fpvec

const
  MIN_TICK_SPACING = 4
  MAX_TICK_SPACING = 10
  MIN_TICK_HALF_LEN = 1
  MAX_TICK_HALF_LEN = 6

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
