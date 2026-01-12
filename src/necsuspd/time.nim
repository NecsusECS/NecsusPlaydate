import necsus, debug, util

type
  TimeValue = float32

  GameTime* = Shared[TimeValue]

  GlobalGameTime* = Shared[TimeValue]

  DeltaValue = float32

  GameTimeDelta* = Shared[DeltaValue]

  Speed* = Shared[tuple[numerator, denominator: int32]]

proc get(speed: Speed): auto =
  speed.get((1'i32, 1'i32))

proc `$`(speed: Speed): string =
  if speed.get.denominator == 1:
    return $speed.get.numerator & "x"
  else:
    return $speed.get.numerator & "/" & $speed.get.denominator

proc speedUp*(speed: Speed): string =
  let (numerator, denominator) = speed.get
  if denominator == 1:
    speed := (numerator + 1, denominator)
  else:
    speed := (numerator, denominator - 1)
  return $speed

proc slowDown*(speed: Speed): string =
  let (numerator, denominator) = speed.get
  if numerator == 1:
    speed := (numerator, denominator + 1)
  else:
    speed := (numerator - 1, denominator)
  return $speed

proc applyMultiplier(delta: TimeDelta, speed: Speed): float32 {.inline.} =
  when defined(device):
    return delta()
  else:
    let (numerator, denominator) = speed.get
    return numerator.float32 / denominator.float32 * delta()

proc buildGameTime*(StateType: typedesc[enum]): auto =
  ## Creates a system for managing game time. The `StateType` is used to determine
  ## the current state of the game and track the time for each state separately
  var elapsed: array[StateType, float32]

  return proc(
      delta: TimeDelta,
      gameTime: GameTime,
      gameDelta: GameTimeDelta,
      globalGameTime: GlobalGameTime,
      speed: Speed,
      state: Shared[StateType],
  ) =
    # Update the delta time based on the current debug game speed
    let tickDelta = delta.applyMultiplier(speed)
    gameDelta := tickDelta

    # Now update the elapsed time for the current state
    let currentState = state.get(default(StateType))
    elapsed[currentState] += tickDelta
    gameTime := elapsed[currentState]

    # Update the global game time, which isn't localized to the current state
    globalGameTime := gameTime.get() + tickDelta

proc timeDebugger*(slowDownKey, speedUpKey: char): auto =
  ## Hooks in debug key monitors for adjusting the time
  proc(events: Inbox[DebugKey], speed: Speed) {.debugSys.} =
    for key in events:
      if key == speedUpKey:
        let newSpeed = speed.speedUp()
        log "Increasing speed to ", newSpeed
      elif key == slowDownKey:
        let newSpeed = speed.slowDown()
        log "Decreasing speed to ", newSpeed
