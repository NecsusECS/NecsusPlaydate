import
  std/[unittest, options],
  necsus,
  necsuspd/[visibleState, sprite],
  necsuspd/stubs/graphics,
  helpers

type GameState* = enum
  Idle
  Running
  GameOver

defineVisibleStateSystems(checkVisibleState, GameState)

proc runner(
    state: Shared[GameState],
    spawnSprite: FullSpawn[(VisibleState, Sprite)],
    spawnAnim: FullSpawn[(VisibleState, Animation)],
    getSprite: Lookup[(Sprite,)],
    getAnim: Lookup[(Animation,)],
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

  test "sprite is visible when state matches":
    let e = spawnSprite.with(visibility(Idle), newSprite("test", 10, 10))
    state := Idle
    tick()
    check getSprite(e).get()[0].visible

  test "sprite is hidden when state does not match":
    let e = spawnSprite.with(visibility(Idle), newSprite("test2", 10, 10))
    state := Running
    tick()
    check not getSprite(e).get()[0].visible

  test "sprite becomes visible again when state returns":
    let e = spawnSprite.with(visibility(Idle), newSprite("test3", 10, 10))
    state := Running
    tick()
    state := Idle
    tick()
    check getSprite(e).get()[0].visible

  test "animation is hidden when state does not match":
    let e = spawnAnim.with(visibility(GameOver), newAnimation("test", 10, 10))
    state := GameOver
    tick()
    state := Idle
    tick()
    check not getAnim(e).get()[0].visible

  test "animation is visible when state matches":
    let e = spawnAnim.with(visibility(GameOver), newAnimation("test2", 10, 10))
    state := GameOver
    tick()
    check getAnim(e).get()[0].visible

proc testVisibleState() {.
  necsus(runner, [~evalVisibleState, ~checkVisibleState], newNecsusConf())
.}

testVisibleState()
