import
  std/[unittest, options],
  necsus,
  necsuspd/[autoalign, positioned, alignment],
  graphics_stub,
  vmath

type MyEntity = object

template setupTest(body: untyped) =
  runSystemOnce do(
    align {.inject.}: AutoAlign[MyEntity],
    createTarget {.inject.}: FullSpawn[(MyEntity, Positioned)],
    createAnchor {.inject.}: FullSpawn[(Positioned, Sprite)],
    lookup {.inject.}: Lookup[(Positioned,)]
  ) -> void:
    body

setupTest:
  test "Align elements to the top left":
    let anchor = createAnchor.with(positioned(10, 20), newSprite("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignLeft, AlignTop)
    check(lookup(target).get()[0].toIVec2 == ivec2(10, 20))

setupTest:
  test "Align elements to the top right":
    let anchor = createAnchor.with(positioned(10, 20), newSprite("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignRight, AlignTop)
    # Anchor: x=10, y=20, width=30, height=40
    # AlignRight: anchor.x + anchor.width = 10 + 30 = 40
    # AlignTop: anchor.y = 20
    check(lookup(target).get()[0].toIVec2 == ivec2(40, 20))

setupTest:
  test "Align elements to the bottom left":
    let anchor = createAnchor.with(positioned(10, 20), newSprite("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignLeft, AlignBottom)
    # Anchor: x=10, y=20, width=30, height=40
    # AlignLeft: anchor.x = 10
    # AlignBottom: anchor.y + anchor.height = 20 + 40 = 60
    check(lookup(target).get()[0].toIVec2 == ivec2(10, 60))

setupTest:
  test "Align elements to the bottom right":
    let anchor = createAnchor.with(positioned(10, 20), newSprite("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignRight, AlignBottom)
    # Anchor: x=10, y=20, width=30, height=40
    # AlignRight: anchor.x + anchor.width = 10 + 30 = 40
    # AlignBottom: anchor.y + anchor.height = 20 + 40 = 60
    check(lookup(target).get()[0].toIVec2 == ivec2(40, 60))

setupTest:
  test "Align elements to the center":
    let anchor = createAnchor.with(positioned(10, 20), newSprite("anchor", 30, 40))
    let target = createTarget.with(MyEntity(), positioned(0, 0))
    align.align(anchor, AlignCenter, AlignCenter)
    # Anchor: x=10, y=20, width=30, height=40
    # AlignHCenter: anchor.x + anchor.width / 2 = 10 + 30 / 2 = 10 + 15 = 25
    # AlignVCenter: anchor.y + anchor.height / 2 = 20 + 40 / 2 = 20 + 20 = 40
    check(lookup(target).get()[0].toIVec2 == ivec2(25, 40))
