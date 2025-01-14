import necsus, time, util

type
    Lifetime* = ref object
        timestamp: float32

    Timer* = ref object
        name: string
        timestamp: float32
        action: proc(): void

    LifetimeControl* = object
        time: GameTime

    TimerControl*[T] = object
        spawn: Spawn[(Timer, T, )]
        time: GameTime

proc startTimer*[T](control: Bundle[TimerControl[T]], name: string, delta: float32, action: proc(): void) =
    ## Creates a timer
    control.spawn.with(
        Timer(name: name, timestamp: control.time.get + delta, action: action),
        default(T),
    )

proc newLifetime*(control: Bundle[LifetimeControl],  delta: SomeNumber): Lifetime =
    ## Creates a lifetime that deletes an entity after a specific time span
    Lifetime(timestamp: control.time.get + delta.float32)

proc lifetimes*(lifetimes: FullQuery[(Lifetime, )], time: GameTime, delete: Delete) {.depends(gameTime).} =
    ## System for deleting objects with a lifetime
    for eid, (lifetime, ) in lifetimes:
        if lifetime.timestamp <= time.get:
            delete(eid)

proc runTimers*(timers: FullQuery[(Timer, )], time: GameTime, delete: Delete) {.depends(gameTime, lifetimes).} =
    ## System for triggering timers
    for eid, (timer, ) in timers:
        if timer.timestamp <= time.get:
            log "Triggering timer: ", timer.name
            delete(eid)
            timer.action()
