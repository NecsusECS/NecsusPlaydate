import necsus, sprite, playdate/api, util

type
  VisibleState*[T: enum] = object
    states: set[T]

  EvaluateVisibleState* = object

proc visibility*[T: enum](states: set[T]): VisibleState[T] =
  ## Creates a VisibleState instance
  return VisibleState[T](states: states)

proc visibility*[T: enum](states: varargs[T]): VisibleState[T] =
  ## Creates a VisibleState instance
  var fullList: set[T]
  for state in states:
    incl(fullList, state)
  return visibility(fullList)

proc isVisible*[T](visibility: VisibleState[T], state: Shared[T]): bool =
  return state.get in visibility.states

template updateVisility(visibleState, entities: typed) =
  for eid, (visibility, entity) in entities:
    let expect = visibleState in visibility.states
    if expect != entity.visible:
      log "Changing entity visibility for ", eid, " to ", expect
      entity.visible = expect

template defineVisibleStateSystems*(name: untyped, T, S: typed): untyped =
  ## Shows sprites only when a specific game state is set
  proc evalVisibleState(
      _: EvaluateVisibleState,
      state: Shared[T],
      sprites: FullQuery[(ptr VisibleState[T], Sprite)],
      anims: FullQuery[(ptr VisibleState[T], Animation[S])],
  ) {.eventSys.} =
    updateVisility(state.get, sprites)
    updateVisility(state.get, anims)

  proc name(
      state: Shared[T], previous: Local[T], trigger: Outbox[EvaluateVisibleState]
  ) {.depends(evalVisibleState).} =
    if previous.isEmpty or previous != state.get:
      previous := state.get
      trigger(EvaluateVisibleState())
