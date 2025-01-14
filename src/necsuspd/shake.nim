import necsus, viewport, timer, vmath, util, rand

type
    Shake* {.maxCapacity(20).} = object
        xRange, yRange: Slice[int32]

    ViewPortShake* = object
        shake: Shake
        ttl*: float32

    CreateShake*[T] = object
        spawn: FullSpawn[(T, Shake, ViewPortTweak)]

proc shake*(offsetRange: Slice[int32]): auto =
    Shake(xRange: offsetRange, yRange: offsetRange)

proc shake*(offsetRange: Slice[int32], ttl: float32): auto =
    ViewPortShake(shake: shake(offsetRange), ttl: ttl)

proc shake*(minMax: int32, ttl: float32): auto =
    shake(-minMax..minMax, ttl)

proc getShakeValue(shake: Slice[int32]): int32 =
    return if shake.a != shake.b: random().rand(shake) else: 0

proc getOffset(shake: Shake): IVec2 =
    ivec2(shake.xRange.getShakeValue, shake.yRange.getShakeValue)

proc updateShake(shakes: Query[(Shake, ptr ViewPortTweak)]) =
    for (shake, value) in shakes:
        value[] = shake.getOffset()

proc shakeViewPort*(
    event: ViewPortShake,
    timer: Bundle[LifetimeControl],
    create: Spawn[(Lifetime, Shake, ViewPortTweak)]
) {.depends(updateShake), eventSys.} =
    log "Shaking viewport: ", event
    create.with(
        timer.newLifetime(event.ttl),
        event.shake,
        event.shake.getOffset()
    )

proc newShake*[T](control: Bundle[CreateShake[T]], shake: Shake): EntityId =
    control.spawn.with(default(T), shake, ViewPortTweak())