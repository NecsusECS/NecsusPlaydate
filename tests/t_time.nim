import unittest, necsus, necsuspd/[time, debounce]

type
  TestState = enum
    First
    Second

  DebounceFlag = object

let gameTimeSys = buildGameTime(TestState)

proc fixedDelta(seconds: float32): TimeDelta =
  return proc(): BiggestFloat =
    seconds

runSystemOnce do(gameTime: GameTime, globalTime: GlobalGameTime) -> void:
  test "GameTime and GlobalGameTime hold separate values":
    gameTime := 1.0'f32
    globalTime := 2.0'f32
    check(gameTime.get() == 1.0'f32)
    check(globalTime.get() == 2.0'f32)

runSystemOnce do(
  gameTime: GameTime,
  gameDelta: GameTimeDelta,
  globalTime: GlobalGameTime,
  speed: Speed,
  state: Shared[TestState]
) -> void:
  proc tick(seconds: float32) =
    gameTimeSys(fixedDelta(seconds), gameTime, gameDelta, globalTime, speed, state)

  test "Each state keeps its own clock while the global clock always runs":
    state := First
    tick(0.5)
    tick(0.5)
    check(gameTime.get() == 1.0'f32)
    check(globalTime.get() == 1.0'f32)

    state := Second
    tick(0.25)
    check(gameTime.get() == 0.25'f32)
    check(globalTime.get() == 1.25'f32)
    check(gameDelta.get() == 0.25'f32)

    state := First
    tick(0.5)
    check(gameTime.get() == 1.5'f32)
    check(globalTime.get() == 1.75'f32)

runSystemOnce do(
  gameTime: GameTime,
  gameDelta: GameTimeDelta,
  globalTime: GlobalGameTime,
  speed: Speed,
  state: Shared[TestState],
  debounce: Bundle[Debounce[DebounceFlag]]
) -> void:
  proc tick(seconds: float32) =
    gameTimeSys(fixedDelta(seconds), gameTime, gameDelta, globalTime, speed, state)

  test "Debounce measures across state changes on the global clock":
    state := First
    tick(5.0)
    debounce.mark()

    # The new state's clock starts far behind the one the mark was taken in
    state := Second
    tick(0.25)
    check(not (0.5'f32 < debounce))
    tick(0.25)
    check(0.5'f32 < debounce)
