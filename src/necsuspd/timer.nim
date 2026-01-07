import necsus, time, util

type
  Lifetime* = object
    ttl: float32

  Timer* = ref object
    name: string
    timestamp: float32
    action: proc(): void

  LifetimeControl* = object

  TimerControl*[T] = object
    spawn: Spawn[(Timer, T)]
    time: GameTime

proc startTimer*[T](
    control: Bundle[TimerControl[T]], name: string, delta: float32, action: proc(): void
) =
  ## Creates a timer
  control.spawn.with(
    Timer(name: name, timestamp: control.time.get + delta, action: action), default(T)
  )

proc newLifetime*(ttl: SomeNumber): Lifetime =
  ## Creates a lifetime that deletes an entity after a specific time span
  Lifetime(ttl: ttl.float32)

proc newLifetime*(control: Bundle[LifetimeControl], delta: SomeNumber): Lifetime =
  ## Creates a lifetime that deletes an entity after a specific time span
  return newLifetime(delta)

proc lifetimes*(
    lifetimes: FullQuery[(ptr Lifetime,)], time: GameTimeDelta, delete: Delete
) {.depends(gameTime).} =
  ## System for deleting objects with a lifetime
  let delta = time.get
  for eid, (lifetime) in lifetimes:
    lifetime.ttl -= delta
    if lifetime.ttl <= 0:
      log "Lifetime expired, deleting ", eid
      delete(eid)

proc runTimers*(
    timers: FullQuery[(Timer,)], time: GameTime, delete: Delete
) {.depends(gameTime, lifetimes).} =
  ## System for triggering timers
  for eid, (timer) in timers:
    if timer.timestamp <= time.get:
      log "Triggering timer: ", timer.name
      delete(eid)
      timer.action()
