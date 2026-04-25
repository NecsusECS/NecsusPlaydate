import
  std/[unittest, options],
  necsus,
  necsuspd/[visibleState, drawable],
  necsuspd/stubs/graphics,
  helpers

type GameState* = enum
  Idle
  Running
  GameOver

defineVisibleStateSystems(checkVisibleState, GameState)

proc runner(
    state: Shared[GameState],
    spawnDrawable: FullSpawn[(VisibleState, Drawable)],
    getDrawable: Lookup[(Drawable,)],
    tick: proc(): void,
) =
  test "isVisible returns true when state matches":
    state := Idle
    check visibility(Idle).isVisible(state)

  test "isVisible returns false when state does not match":
    state := Running
    check not visibility(Idle).isVisible(state)

  test "isVisible with multiple states":
    state := Running
    check visibility({Idle, Running}).isVisible(state)
    state := GameOver
    check not visibility({Idle, Running}).isVisible(state)

  test "drawable is visible when state matches":
    let e = spawnDrawable.with(visibility(Idle), newDrawable("test", 10, 10))
    state := Idle
    tick()
    check getDrawable(e).get()[0].visible

  test "drawable is hidden when state does not match":
    let e = spawnDrawable.with(visibility(Idle), newDrawable("test2", 10, 10))
    state := Running
    tick()
    check not getDrawable(e).get()[0].visible

  test "drawable becomes visible again when state returns":
    let e = spawnDrawable.with(visibility(Idle), newDrawable("test3", 10, 10))
    state := Running
    tick()
    state := Idle
    tick()
    check getDrawable(e).get()[0].visible

  test "drawable is hidden when state does not match (alt)":
    let e = spawnDrawable.with(visibility(GameOver), newDrawable("test4", 10, 10))
    state := GameOver
    tick()
    state := Idle
    tick()
    check not getDrawable(e).get()[0].visible

  test "drawable is visible when state matches (alt)":
    let e = spawnDrawable.with(visibility(GameOver), newDrawable("test5", 10, 10))
    state := GameOver
    tick()
    check getDrawable(e).get()[0].visible

proc testVisibleState() {.
  necsus(runner, [~evalVisibleState, ~checkVisibleState], newNecsusConf())
.}

testVisibleState()
