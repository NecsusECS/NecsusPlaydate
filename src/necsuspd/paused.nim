import necsus, sprite, util, std/bitops, types

type
  StateType = uint64

  PausedState* = object ## Represents when an entity should be paused
    states: StateType
    typeId: TypeId

  EvaluatePausedState* = object ## An event to force the evaluation of paused entities

proc pausedIn*[T: enum](states: set[T]): PausedState =
  ## Creates a PausedState instance; animation is paused when current state is in `states`
  result.typeId = getTypeId(T)
  for value in states:
    const maxSize = sizeof(StateType) * 8
    assert(
      ord(value) <= maxSize,
      "State value exceeds maximum allowed" & $ord(value) & " vs " & $maxSize,
    )
    result.states.flipBit(value.ord.StateType)

proc pausedIn*[T: enum](states: varargs[T]): PausedState =
  ## Creates a PausedState instance; animation is paused when current state is in `states`
  var fullList: set[T]
  for state in states:
    incl(fullList, state)
  return pausedIn(fullList)

template updatePaused(T, currentState, entities: typed) =
  for eid, (pausedState, entity) in entities:
    if pausedState.typeId == getTypeId(T):
      let stateBit = 1.StateType shl currentState.ord.StateType
      let shouldPause = bitand(stateBit, pausedState.states) > 0
      if shouldPause != entity.paused:
        log "Changing animation pause for ",
          eid, " to ", shouldPause, " for state ", currentState
        `paused=`(entity, shouldPause)

template definePausedStateSystems*(name: untyped, T: typed): untyped =
  ## Pauses animations when a specific game state is set
  proc evalPausedState(
      _: EvaluatePausedState,
      state: Shared[T],
      anims: FullQuery[(PausedState, Animation)],
  ) {.eventSys.} =
    updatePaused(T, state.get, anims)

  proc name(
      state: Shared[T], previous: Local[T], trigger: Outbox[EvaluatePausedState]
  ) {.depends(evalPausedState).} =
    if previous.isEmpty or previous != state.get:
      previous := state.get
      trigger(EvaluatePausedState())
