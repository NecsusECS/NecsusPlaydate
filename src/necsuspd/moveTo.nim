import positioned, time, necsus, vmath, vec_tools, easing

type
    MoveTo*[Filter] = object
        ## Bundle needed to attach a movement
        lookup: Lookup[(Positioned, Filter)]
        attach: Attach[(MovingTo, )]
        time: GameTime

    MovingTo* {.accessory.} = ref object
        ## Component that defines the movement behavior of an entity
        origin, target, delta: Vec2
        startTime, duration: float32
        easingX, easingY: EasingFunc
        onComplete: proc(): void

    MoveCallback = object
        ## Invokes a callback with the state of an easing calculation between two values
        update: proc (currentTime: float32): bool

    CallbackMoveTo*[T] = object
        ## Creates callback based movers
        spawn: Spawn[(MoveCallback, T)]
        time: GameTime

proc defaultOnComplete() = discard

proc move*[Filter](
    mover: Bundle[MoveTo[Filter]],
    eid: EntityId,
    target: IVec2,
    duration: float32,
    easingX, easingY: EasingFunc,
    onComplete: proc (): void = defaultOnComplete
) =
    ## Attaches a movement behavior to an entity
    for elem in mover.lookup(eid):
        mover.attach(eid, (
            MovingTo(
                origin: elem[0].toVec2,
                target: target.toVec2,
                delta: target.toVec2 - elem[0].toVec2,
                startTime: mover.time.getOrRaise,
                duration: duration,
                easingX: easingX,
                easingY: easingY,
                onComplete: onComplete,
            ),
        ))

proc move*[Filter](
    mover: Bundle[MoveTo[Filter]],
    eid: EntityId,
    target: IVec2,
    duration: float32,
    easing: EasingFunc,
    onComplete: proc (): void = defaultOnComplete
) =
    ## Attaches a movement behavior to an entity
    move(mover, eid, target, duration, easing, easing, onComplete)

template calculate(originValue, targetValue: typed; startTime, duration, currentTime: float32; exec: untyped): untyped =
    let progress {.inject.} = (currentTime - startTime) / duration
    if progress >= 1:
        (targetValue, true)
    elif progress <= 0:
        (originValue, false)
    else:
        (exec, false)

proc callback*[V, T](
    mover: Bundle[CallbackMoveTo[V]];
    origin, target: T;
    duration: float32;
    easing: EasingCalc[T];
    update: proc(value: T, isDone: bool): void;
) =
    ## Invokes a callback with easing based updates
    let startTime = mover.time.getOrRaise

    proc updateCallback(currentTime: float32): bool =
        let (newPos, isDone) = calculate(origin, target, startTime, duration, currentTime):
            easing(origin, target, progress)
        update(newPos, isDone)
        return isDone

    mover.spawn.with(MoveCallback(update: updateCallback), default(V))

proc calculate*(movement: MovingTo | ptr MovingTo, currentTime: float32): tuple[newPos: IVec2, isDone: bool] =
    ## Calculates the position for the given movement definition
    let (newPos, isDone) =
        calculate(movement.origin, movement.target, movement.startTime, movement.duration, currentTime):
            movement.origin + vec2(
                movement.delta.x * movement.easingX(progress),
                movement.delta.y * movement.easingY(progress)
            )
    return (newPos.toIVec2, isDone)

proc updateMoveTos*(
    movers: FullQuery[(ptr Positioned, ptr MovingTo)],
    done: Detach[(MovingTo, )],
    time: GameTime,
    callbacks: FullQuery[(ptr MoveCallback, )],
    delete: Delete,
) =
    let now = time.getOrRaise

    ## System for updating any elements moving between points
    for eid, (pos, movement) in movers:
        let (newPos, isDone) = calculate(movement, now)
        pos.pos = newPos
        if isDone:
            movement.onComplete()
            done(eid)

    for eid, (callback, ) in callbacks:
        if callback.update(now):
            delete(eid)
