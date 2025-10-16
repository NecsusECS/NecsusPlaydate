import
  std/[unittest, options],
  necsus,
  necsuspd/[cursor, positioned, fpvec],
  vmath,
  graphics_stub

proc createStdCursorElems(create: auto): auto =
  return [
    create.with(positioned(50, 60), Selectable()),
    create.with(positioned(200, 60), Selectable()),
    create.with(positioned(50, 145), Selectable()),
    create.with(positioned(79, 145), Selectable()),
    create.with(positioned(108, 145), Selectable()),
    create.with(positioned(137, 145), Selectable()),
    create.with(positioned(42, 190), Selectable()),
  ]

template runTest(name: string, body: untyped) =
  runSystemOnce do(
    create {.inject.}: FullSpawn[(Positioned, Selectable)],
    createWithAnim {.inject.}: FullSpawn[(Positioned, Selectable, Animation)],
    createWithSprite {.inject.}: FullSpawn[(Positioned, Selectable, Sprite)],
    cursor {.inject.}: CursorControl
  ) -> void:
    test name:
      body

runTest "Start with nothing selected":
  check cursor.selection().kind == NoSelectionKind

runTest "Init to the closest selection to top left":
  let eids = create.createStdCursorElems()
  cursor.init()
  check cursor.selection().to(EntitySelected).entityId == eids[0]

runTest "Init to the closest selection to the given point":
  let eids = create.createStdCursorElems()
  cursor.init(fpvec2(500, 500))
  check cursor.selection().to(EntitySelected).entityId == eids[5]

runTest "Move the cursor around":
  let eids = create.createStdCursorElems()
  cursor.init()
  check cursor.selection().to(EntitySelected).entityId == eids[0]
  cursor.update(kButtonRight)
  check cursor.selection().to(EntitySelected).entityId == eids[1]
  cursor.update(kButtonDown)
  check cursor.selection().to(EntitySelected).entityId == eids[5]

runTest "Move the cursor without first initializing":
  let eids = create.createStdCursorElems()
  cursor.update(kButtonRight)
  check cursor.selection().to(EntitySelected).entityId == eids[0]

runTest "Update from a non-directional button":
  let eids = create.createStdCursorElems()
  cursor.init()
  cursor.update(kButtonA)
  check cursor.selection().to(EntitySelected).entityId == eids[0]

runTest "Forced selection":
  let pos = fpvec2(50, 60)
  let eid = create.with(positioned(pos), Selectable())
  cursor.select(EntitySelected.init(eid, pos).Selected)
  check cursor.selection().to(EntitySelected).entityId == eid

runTest "Animation dimensions impact selection":
  let eids = [
    createWithAnim.with(positioned(0, 0), Selectable(), newAnimation("img", 500, 10)),
    createWithAnim.with(positioned(0, 300), Selectable(), newAnimation("img", 30, 10)),
    createWithAnim.with(positioned(250, 300), Selectable(), newAnimation("img", 30, 10)),
  ]
  cursor.init()
  check cursor.selection().to(EntitySelected).entityId == eids[0]
  cursor.update(kButtonDown)
  check cursor.selection().to(EntitySelected).entityId == eids[2]

runTest "Sprite dimensions impact selection":
  let eids = [
    createWithSprite.with(positioned(0, 0), Selectable(), newSprite("img", 500, 10)),
    createWithSprite.with(positioned(0, 300), Selectable(), newSprite("img", 30, 10)),
    createWithSprite.with(positioned(250, 300), Selectable(), newSprite("img", 30, 10)),
  ]
  cursor.init()
  check cursor.selection().to(EntitySelected).entityId == eids[0]
  cursor.update(kButtonDown)
  check cursor.selection().to(EntitySelected).entityId == eids[2]

runTest "Ignore hidden animation entities":
  let hiddenAnim = newAnimation("img", 10, 10)
  hiddenAnim.visible = false

  let eids = [
    createWithAnim.with(positioned(0, 0), Selectable(), newAnimation("img", 10, 10)),
    createWithAnim.with(positioned(0, 100), Selectable(), hiddenAnim),
    createWithAnim.with(positioned(0, 200), Selectable(), newAnimation("img", 10, 10)),
  ]

  cursor.init()
  cursor.update(kButtonDown)
  check cursor.selection().to(EntitySelected).entityId == eids[2]

runTest "Ignore hidden sprite entities":
  let hiddenSprite = newSprite("img", 10, 10)
  hiddenSprite.visible = false

  let eids = [
    createWithSprite.with(positioned(0, 0), Selectable(), newSprite("img", 10, 10)),
    createWithSprite.with(positioned(0, 100), Selectable(), hiddenSprite),
    createWithSprite.with(positioned(0, 200), Selectable(), newSprite("img", 10, 10)),
  ]

  cursor.init()
  cursor.update(kButtonDown)
  check cursor.selection().to(EntitySelected).entityId == eids[2]
