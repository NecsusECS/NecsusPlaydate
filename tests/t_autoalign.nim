import
  std/[unittest, options],
  necsus,
  necsuspd/[autoalign, positioned, alignment, drawable],
  helpers,
  necsuspd/stubs/sprites,
  vmath

type MyEntity = object

template setupTest(body: untyped) =
  runSystemOnce do(
    align {.inject.}: AutoAlign[MyEntity],
    createTarget {.inject.}: FullSpawn[(MyEntity, Positioned)],
    createAnchor {.inject.}: FullSpawn[(Positioned, Drawable)],
    lookup {.inject.}: Lookup[(Positioned,)]
  ) -> void:
    body

setupTest:
  test "Align elements to the top left":
    let anchor = createAnchor.with(positioned(10, 20), newDrawable("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignLeft, AlignTop)
    check(lookup(target).get()[0].toIVec2 == ivec2(10, 20))

setupTest:
  test "Align elements to the bottom right":
    let anchor = createAnchor.with(positioned(10, 20), newDrawable("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignRight, AlignBottom)
    check(lookup(target).get()[0].toIVec2 == ivec2(40, 60))

setupTest:
  test "Align elements to the center":
    let anchor = createAnchor.with(positioned(10, 20), newDrawable("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignCenter, AlignCenter)
    check(lookup(target).get()[0].toIVec2 == ivec2(25, 40))

setupTest:
  test "Aligning Animations":
    let anchor = createAnchor.with(positioned(10, 20), newDrawable("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignCenter, AlignCenter)
    check(lookup(target).get()[0].toIVec2 == ivec2(25, 40))

setupTest:
  test "Updating multiple targets":
    let anchor = createAnchor.with(positioned(10, 20), newDrawable("anchor", 30, 40))
    let target1 = createTarget.with(MyEntity(), positioned(0, 0))
    let target2 = createTarget.with(MyEntity(), positioned(0, 0))
    let target3 = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignCenter, AlignCenter)
    check(lookup(target1).get()[0].toIVec2 == ivec2(25, 40))
    check(lookup(target2).get()[0].toIVec2 == ivec2(25, 40))
    check(lookup(target3).get()[0].toIVec2 == ivec2(25, 40))
