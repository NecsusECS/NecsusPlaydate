import necsus, inputs

type
    CrankState = ref object
        lastUpdateTick: BiggestUInt
        fullRotations: int32
        previousAngle: CrankAngle

    CrankData* = object
        angle: Shared[CrankAngle]
        delta: Shared[CrankDelta]
        currentTickId: TickId
        state: Shared[CrankState]

proc getState(control: Bundle[CrankData]): var CrankState =
    control.state.getOrPut: CrankState(lastUpdateTick: control.currentTickId())

proc calculate(control: Bundle[CrankData], state: var CrankState): float32 =
    (360.0f32 * state.fullRotations.toFloat) + control.angle.get

proc recalculateRotations(control: Bundle[CrankData], state: var CrankState = control.getState): float32 =
    ## Performs a full recalculation of the crank state

    let newAngleByDelta = state.previousAngle + control.delta.get
    if newAngleByDelta >= 360:
        state.fullRotations += 1
    elif newAngleByDelta < 0:
        state.fullRotations -= 1

    state.lastUpdateTick = control.currentTickId()
    state.previousAngle = control.angle.get

    return control.calculate(state)

proc absoluteAngle*(control: Bundle[CrankData]): CrankAngle =
    var state = control.getState
    if control.currentTickId() != state.lastUpdateTick:
        return control.recalculateRotations(state)
    else:
        return control.calculate(state)
