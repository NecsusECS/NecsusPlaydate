import unittest, necsus, necsuspd/[layout, positioned], options, vmath

type TestSprite = tuple[width, height: int]

proc `==`(a: (int32, int32), b: (int, int)): bool =
  return a == (b[0].int32, b[1].int32)

template createLayouter(entities: untyped) =
  proc lookup(
      eid: EntityId
  ): Option[(ptr Positioned, TestSprite)] {.gcsafe, raises: [].} =
    {.cast(gcsafe).}:
      let i = eid.uint.int
      if i < entities.len:
        return some((unsafeAddr entities[i][0], entities[i][1]))
      else:
        return none((ptr Positioned, TestSprite))

  let layouter {.inject.} = Layouter[TestSprite](get: lookup)

suite "Layout Elem":
  test "A simple sprite should have layout performed":
    var entities = [(positioned(0, 0), (10, 20))]
    createLayouter(entities)
    let layout = spriteLayout(EntityId(0))
    let dimens = layout.layout(layouter, x = 5, y = 20, width = 40)
    check(entities[0][0].toIVec2 == ivec2(5, 20))
    check(dimens == (width: 10, height: 20))
    check(layouter.minWidth(layout) == 10)

  test "A right aligned sprite":
    var entities = [(positioned(0, 0), (10, 20))]
    createLayouter(entities)
    let layout = spriteLayout(EntityId(0), align = AlignRight)
    let dimens = layout.layout(layouter, x = 5, y = 20, width = 40)
    check(entities[0][0].toIVec2 == ivec2(35, 20))
    check(dimens == (width: 40, height: 20))
    check(layouter.minWidth(layout) == 10)

  test "A center aligned sprite":
    var entities = [(positioned(0, 0), (10, 20))]
    createLayouter(entities)
    let layout = spriteLayout(EntityId(0), align = AlignCenter)
    let dimens = layout.layout(layouter, x = 5, y = 20, width = 40)
    check(entities[0][0].toIVec2 == ivec2(20, 20))
    check(dimens == (width: 40, height: 20))
    check(layouter.minWidth(layout) == 10)

  test "A layout with a missing sprite should ignore it":
    var entities = newSeq[(Positioned, TestSprite)]()
    createLayouter(entities)
    let layout = spriteLayout(EntityId(0))
    let dimens = layout.layout(layouter, x = 5, y = 20, width = 40)
    check(dimens == (width: 0, height: 0))
    check(layouter.minWidth(layout) == 0)

  test "Cards should be layed out in columns":
    var entities = [
      (positioned(0, 0), (width: 10, height: 20)),
      (positioned(0, 0), (width: 8, height: 25)),
      (positioned(0, 0), (width: 8, height: 30)),
      (positioned(0, 0), (width: 20, height: 20)),
      (positioned(0, 0), (width: 20, height: 15)),
      (positioned(0, 0), (width: 20, height: 10)),
      (positioned(0, 0), (width: 20, height: 19)),
    ]
    createLayouter(entities)

    let layout = cardLayout(
      3,
      EntityId(0).spriteLayout,
      EntityId(1).spriteLayout,
      EntityId(2).spriteLayout,
      EntityId(3).spriteLayout,
      EntityId(4).spriteLayout,
      EntityId(5).spriteLayout,
      EntityId(6).spriteLayout,
    )
    let dimens = layout.layout(layouter, x = 5, y = 7, width = 100)

    check(entities[0][0].toIVec2 == ivec2(5, 7))
    check(entities[1][0].toIVec2 == ivec2(15, 7))
    check(entities[2][0].toIVec2 == ivec2(23, 7))

    check(entities[3][0].toIVec2 == ivec2(5, 37))
    check(entities[4][0].toIVec2 == ivec2(25, 37))
    check(entities[5][0].toIVec2 == ivec2(45, 37))

    check(entities[6][0].toIVec2 == ivec2(5, 57))

    check(dimens == (width: 60, height: 69))
    check(layouter.minWidth(layout) == 60)

  test "Card layout without any cards":
    var entities = [(positioned(0, 0), (width: 10, height: 20))]
    createLayouter(entities)

    let layout = cardLayout(3)
    let dimens = layout.layout(layouter, x = 5, y = 7, width = 100)
    check(dimens == (width: 0, height: 0))
    check(layouter.minWidth(layout) == 0)

  test "Card layout without a full row":
    var entities = [(positioned(0, 0), (width: 10, height: 20))]
    createLayouter(entities)

    let layout = cardLayout(3, EntityId(0).spriteLayout)
    let dimens = layout.layout(layouter, x = 5, y = 7, width = 100)
    check(dimens == (width: 10, height: 20))
    check(layouter.minWidth(layout) == 10)

  test "Stacked entities should be layed out vertically":
    var entities = [
      (positioned(0, 0), (width: 10, height: 20)),
      (positioned(0, 0), (width: 15, height: 30)),
      (positioned(0, 0), (width: 20, height: 40)),
    ]
    createLayouter(entities)

    let layout = stackLayout(
      EntityId(0).spriteLayout, EntityId(1).spriteLayout, EntityId(2).spriteLayout
    )
    let dimens = layout.layout(layouter, x = 5, y = 7, width = 100)

    check(entities[0][0].toIVec2 == ivec2(5, 7))
    check(entities[1][0].toIVec2 == ivec2(5, 27))
    check(entities[2][0].toIVec2 == ivec2(5, 57))

    check(dimens == (width: 20, height: 90))
    check(layouter.minWidth(layout) == 20)

  test "Row entities should be layed out horizontally":
    var entities = [
      (positioned(0, 0), (width: 10, height: 20)),
      (positioned(0, 0), (width: 15, height: 30)),
      (positioned(0, 0), (width: 20, height: 40)),
    ]
    createLayouter(entities)

    let layout = rowLayout(
      EntityId(0).spriteLayout, EntityId(1).spriteLayout, EntityId(2).spriteLayout
    )

    let dimens = layout.layout(layouter, x = 5, y = 7, width = 100)

    check(entities[0][0].toIVec2 == ivec2(5, 7))
    check(entities[1][0].toIVec2 == ivec2(15, 7))
    check(entities[2][0].toIVec2 == ivec2(30, 7))

    check(dimens == (width: 45, height: 40))
    check(layouter.minWidth(layout) == 45)

  test "Padding should be added to nested elements":
    var entities = [(positioned(0, 0), (10, 20))]
    createLayouter(entities)

    let layout = spriteLayout(EntityId(0)).padLayout(2, 3, 4, 5)
    let dimens = layout.layout(layouter, x = 5, y = 20, width = 40)

    check(entities[0][0].toIVec2 == ivec2(7, 24))
    check(dimens == (width: 15, height: 29))
    check(layouter.minWidth(layout) == 15)

  test "Right aligned entity inside of padding":
    var entities = [(positioned(0, 0), (10, 20))]
    createLayouter(entities)

    let layout = spriteLayout(EntityId(0), AlignRight).padLayout(2, 3, 4, 5)
    let dimens = layout.layout(layouter, x = 5, y = 20, width = 40)

    check(entities[0][0].toIVec2 == ivec2(32, 24))
    check(dimens == (width: 40, height: 29))
    check(layouter.minWidth(layout) == 15)

  test "Right aligned entity inside of center columns":
    var entities = [(positioned(0, 0), (10, 20)), (positioned(0, 0), (30, 40))]
    createLayouter(entities)

    let layout = horizLayout(
      AlignCenter,
      rowLayout(EntityId(0).spriteLayout, EntityId(1).spriteLayout(AlignRight)),
    )

    let dimens = layout.layout(layouter, x = 5, y = 20, width = 100)

    check(entities[0][0].toIVec2 == ivec2(35, 20))
    check(entities[1][0].toIVec2 == ivec2(45, 20))

    check(dimens == (width: 100, height: 40))
    check(layouter.minWidth(layout) == 40)
