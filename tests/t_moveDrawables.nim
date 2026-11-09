import
  std/unittest,
  std/options,
  necsus,
  necsuspd/[drawable, positioned, viewport],
  necsuspd/stubs/graphics,
  helpers,
  vmath

template setupTest(body: untyped) =
  runSystemOnce do(
    drawables {.inject.}: Query[(ptr Drawable, Positioned)],
    viewport {.inject.}: Shared[ViewPort],
    tweaks {.inject.}: Query[(ViewPortTweak,)],
    spawn {.inject.}: FullSpawn[(Positioned, Drawable)],
    getPos {.inject.}: Lookup[(ptr Positioned,)]
  ) -> void:
    proc move() {.inject.} =
      moveDrawables(drawables, viewport, tweaks)

    body

proc drawPos(d: Drawable): IVec2 =
  d.drawItem.pos

setupTest:
  test "Places a sprite after it spawns, even at the origin":
    let d = newDrawable("d", 4, 4)
    d.drawItem.moveTo(ivec2(99, 99))
    discard spawn.with(positioned(0, 0), d)
    move()
    check(d.drawPos == ivec2(0, 0))

setupTest:
  test "Follows changes to the entity's position":
    let d = newDrawable("d", 4, 4)
    let eid = spawn.with(positioned(10, 20), d)
    move()
    getPos(eid).get()[0].pos = ivec2(30, 40)
    move()
    check(d.drawPos == ivec2(30, 40))

setupTest:
  test "Follows changes to the viewport":
    let d = newDrawable("d", 4, 4)
    discard spawn.with(positioned(10, 20), d)
    move()
    viewport := ivec2(5, 5)
    move()
    check(d.drawPos == ivec2(5, 15))

setupTest:
  test "Re-places a sprite whose offset changes while it sits still":
    let d = newDrawable("d", 4, 4)
    discard spawn.with(positioned(10, 20), d)
    move()
    d.offset = ivec2(3, 0)
    move()
    check(d.drawPos == ivec2(13, 20))

setupTest:
  test "Re-places a sprite whose image changes size while it sits still":
    let d =
      newBitmapDrawable(newImage("d", 4, 4, kColorBlack), FirstLayer, AnchorMiddle)
    discard spawn.with(positioned(10, 20), d)
    move()
    d.setImage(newImage("e", 8, 8, kColorBlack))
    move()
    check(d.drawPos == ivec2(6, 16))

setupTest:
  test "Re-places a linked sprite whose offset changes":
    let parent = newDrawable("p", 4, 4)
    let child = newDrawable("c", 4, 4)
    parent.link = child
    discard spawn.with(positioned(10, 20), parent)
    move()
    child.offset = ivec2(0, 7)
    move()
    check(child.drawPos == ivec2(10, 27))

setupTest:
  test "Skips a sprite when nothing about its placement changed":
    let d = newDrawable("d", 4, 4)
    discard spawn.with(positioned(10, 20), d)
    move()
    d.drawItem.moveTo(ivec2(99, 99))
    move()
    check(d.drawPos == ivec2(99, 99))
