import necsus, drawable, import_playdate, util, util/stateflips, types

type
  VisibleState* = distinct StateFlip

  EvaluateVisibleState* = object

proc visibility*[T: enum](states: set[T]): VisibleState =
  ## Creates a VisibleState instance
  VisibleState(stateFlip(states))

proc visibility*[T: enum](states: varargs[T]): VisibleState =
  ## Creates a VisibleState instance
  VisibleState(stateFlip(states))

proc isVisible*[T](visibility: VisibleState, state: Shared[T]): bool =
  let flip = StateFlip(visibility)
  assert(flip.typeId == getTypeId(T))
  return matchesState(flip.states, state.get)

template updateVisility(T, visibleState, entities: typed) =
  for eid, (visibility, entity) in entities:
    let flip = StateFlip(visibility)
    if flip.typeId == getTypeId(T):
      let expect = matchesState(flip.states, visibleState)
      if expect != entity.visible:
        log "Changing entity visibility for ",
          eid, " to ", expect, " for state ", visibleState
        entity.visible = expect

template defineVisibleStateSystems*(name: untyped, T: typed): untyped =
  ## Shows sprites only when a specific game state is set
  proc evalVisibleState(
      _: EvaluateVisibleState,
      state: Shared[T],
      drawables: FullQuery[(VisibleState, ptr Drawable)],
  ) {.eventSys.} =
    updateVisility(T, state.get, drawables)

  proc name(
      state: Shared[T], previous: Local[T], trigger: Outbox[EvaluateVisibleState]
  ) {.depends(evalVisibleState).} =
    if previous.isEmpty or previous != state.get:
      previous := state.get
      trigger(EvaluateVisibleState())
