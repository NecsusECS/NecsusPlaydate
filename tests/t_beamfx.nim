import
  std/unittest,
  necsus,
  necsuspd/[beamfx, drawable, fpvec, pool, positioned],
  necsuspd/stubs/graphics,
  vmath

const TEST_POOL_SIZE = 3

makeBeamPool(TestBeam, 0, 20, TEST_POOL_SIZE)

proc keepAlive(img: LCDBitmap, step: uint, origin, target: IVec2): bool =
  true

runSystemOnce do(
  spawn: Spawn[(TestBeamBeamState, Positioned, Drawable, Handle[Drawable])],
  live: Query[(TestBeamBeamState,)]
) -> void:
  test "drops beams fired while the pool is full":
    for _ in 0 ..< TEST_POOL_SIZE + 2:
      TestBeam(beam(fpvec2(0, 0), fpvec2(5, 5), keepAlive, 1), spawn, live)
    check live.len == TEST_POOL_SIZE

suite "beamClip":
  test "grows the endpoints' bounding box by the spread":
    check beamClip(ivec2(20, 50), ivec2(60, 30), 5, 100) ==
      (ivec2(15, 25), ivec2(51, 31))

  test "is clamped to the image":
    check beamClip(ivec2(2, 90), ivec2(40, 98), 5, 100) == (ivec2(0, 85), ivec2(46, 15))

  test "is empty when the beam is entirely outside the image":
    check beamClip(ivec2(120, 130), ivec2(140, 150), 5, 100)[1] == ivec2(0, 0)
