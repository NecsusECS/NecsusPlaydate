import vmath, std/random, fpvec

when defined(unittests):
  import ../../tests/stubs/playdate_api
else:
  import playdate/api

type LightningConf = object ## Configuration for generating lightning
  a, b: IVec2
  width, fullDistSq: int32
  random: Rand
  perp: FPVec2

proc rand(data: var LightningConf, range: auto): auto {.inline.} =
  data.random.rand(range)

proc shouldSubdivide(lightning: var LightningConf, a, b: IVec2): bool =
  ## Calculate whether a single branch of lightning should be subdivided into a zig zag line
  let distSq = a.distSq(b)
  if distSq > (lightning.fullDistSq div 3):
    return true
  elif distSq < 32:
    return false
  else:
    return lightning.rand(0 .. 100) < 50

proc distanceToCenter(lightning: var LightningConf, target: FPVec2): int32 =
  ## Calculates the distance that `target` is from the line segment formed by `lightning.a` to
  ## `lightning.b` along the slope `lightning.perp`
  dot(target - toFPVec2(lightning.a), lightning.perp).toInt

proc maxJitter(lightning: var LightningConf, depth: int32): int32 =
  ## Calculates the maximum jitter value for the lightning width band. This attempts to reduce
  ## the jitter as the lightning branches out.
  const JITTER_SCALE = 4
  return lightning.width * JITTER_SCALE div (depth + JITTER_SCALE + 1)

proc pickPointWithinWidth(
    lightning: var LightningConf, target: IVec2, depth: int32
): IVec2 =
  ## Picks a point within the lightning width band, perpendicular to the main segment.
  let target = fpvec2(target.x, target.y)
  let distanceToCenter = lightning.distanceToCenter(target).fp

  let maxJitter = lightning.maxJitter(depth)
  let offset =
    lightning.rand(0'i32 .. maxJitter).fp - (maxJitter div 2) - distanceToCenter

  result = toIVec2(target + lightning.perp * offset)

proc calculateSubdivide(
    lightning: var LightningConf, a, b: IVec2, depth: int32
): IVec2 =
  let midpoint = a + ((b - a) div 2)
  return lightning.pickPointWithinWidth(midpoint, depth)

proc calculateForkTarget(lightning: var LightningConf, a: IVec2, depth: int32): IVec2 =
  ## Calculates the target point for a forked branch. This picks a point between `a`
  ## and the lightning terminal point, `lightning.b`
  const FORK_DIVISION = 20
  let delta = (lightning.b.toFPVec2() - a.toFPVec2()) div FORK_DIVISION.fp()
  let branchLength = lightning.rand(3 .. (FORK_DIVISION - depth.int)).fp()
  let targetPoint = toIVec2(a.toFPVec2() + delta * branchLength)
  result = lightning.pickPointWithinWidth(targetPoint, depth)

proc chooseLineWidth(lightning: var LightningConf, depth: int32): int =
  ## Chooses the width of a line to draw
  return
    case depth
    of 0:
      2
    of 1:
      lightning.rand(1 .. 2)
    else:
      1

proc drawBranch(lightning: var LightningConf, a, b: IVec2, depth: int32) =
  ## Draws a branch of lightning between `a` and `b`. This will randomly choose to create a 'zig zag'
  ## pattern by subdividing the line into two smaller segments. It will also randomly choose whether
  ## to fork the lightning into smaller branches
  if lightning.shouldSubdivide(a, b):
    let newMid = lightning.calculateSubdivide(a, b, depth)
    lightning.drawBranch(a, newMid, depth)
    lightning.drawBranch(newMid, b, depth)
  else:
    playdate.graphics.drawLine(
      a.x.int, a.y.int, b.x.int, b.y.int, lightning.chooseLineWidth(depth), kColorWhite
    )

  let likelyhoodOfFork = 20 div (depth + 1)
  if depth <= 4 and lightning.rand(0 .. 100) < likelyhoodOfFork:
    let forkTo = lightning.calculateForkTarget(a, depth + 1)
    lightning.drawBranch(a, forkTo, depth + 1)

proc drawLightning*(
    img: LCDBitmap, seed: BiggestUInt, a, b: IVec2, width: SomeInteger
) =
  img.getBitmapMask.clear(kColorBlack)
  playdate.graphics.pushContext(img.getBitmapMask)
  try:
    var lightning = LightningConf(
      width: width.int32,
      fullDistSq: a.distSq(b),
      a: a,
      b: b,
      random: initRand(seed.int64),
      perp: (b - a).toFPVec2().perpendicular().normalize(),
    )
    lightning.drawBranch(a, b, 0)
  finally:
    playdate.graphics.popContext()
