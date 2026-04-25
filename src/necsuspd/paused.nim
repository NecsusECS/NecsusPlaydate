import necsus, anim, util, util/stateflips, types

type
  PausedState* = distinct StateFlip ## Represents when an entity should be paused

  EvaluatePausedState* = object ## An event to force the evaluation of paused entities

proc pausedIn*[T: enum](states: set[T]): PausedState =
  ## Creates a PausedState instance; animation is paused when current state is in `states`
  PausedState(stateFlip(states))

proc pausedIn*[T: enum](states: varargs[T]): PausedState =
  ## Creates a PausedState instance; animation is paused when current state is in `states`
  PausedState(stateFlip(states))

template updatePaused(T, currentState, entities: typed) =
  for eid, (pausedState, entity) in entities:
    let flip = StateFlip(pausedState)
    if flip.typeId == getTypeId(T):
      let shouldPause = matchesState(flip.states, currentState)
      if shouldPause != entity.paused:
        log "Changing animation pause for ",
          eid, " to ", shouldPause, " for state ", currentState
        `paused=`(entity, shouldPause)

template definePausedStateSystems*(name: untyped, T: typed): untyped =
  ## Pauses animations when a specific game state is set
  proc evalPausedState(
      _: EvaluatePausedState, state: Shared[T], anims: FullQuery[(PausedState, Anim)]
  ) {.eventSys.} =
    updatePaused(T, state.get, anims)

  proc name(
      state: Shared[T], previous: Local[T], trigger: Outbox[EvaluatePausedState]
  ) {.depends(evalPausedState).} =
    if previous.isEmpty or previous != state.get:
      previous := state.get
      trigger(EvaluatePausedState())
