import necsus, debug, util

type
  TimeValue = float32

  GameTime* = Shared[TimeValue]

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

proc gameTime*(
    time: TimeElapsed,
    delta: TimeDelta,
    gameTime: GameTime,
    gameDelta: GameTimeDelta,
    speed: Speed,
) =
  when defined(playdate):
    gameTime := time
    gameDelta := delta
  else:
    if speed.isEmpty:
      gameTime := time()
      gameDelta := delta()
    else:
      let (numerator, denominator) = speed.get
      let adjustedDelta = delta() * numerator.float32 / denominator.float32
      gameDelta := adjustedDelta
      gameTime := gameTime.get(time()) + adjustedDelta

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
