import necsus, sprite, playdate/api, util, std/[bitops, strutils]

type
  StateType = uint32

  VisibleState* = object
    states: StateType
    typeId: int32

  EvaluateVisibleState* = object

proc visibility*[T: enum](states: set[T]): VisibleState =
  ## Creates a VisibleState instance
  result.typeId = getTypeId(T)
  for value in states:
    assert(ord(value) <= high(StateType).int)
    result.states.flipBit(value.ord.StateType)

proc visibility*[T: enum](states: varargs[T]): VisibleState =
  ## Creates a VisibleState instance
  var fullList: set[T]
  for state in states:
    incl(fullList, state)
  return visibility(fullList)

proc isVisible*[T](visibility: VisibleState, state: Shared[T]): bool =
  assert(visibility.typeId == getTypeId(T))
  return state.get in cast[set[T]](visibility.states)

template updateVisility(T, visibleState, entities: typed) =
  for eid, (visibility, entity) in entities:
    if visibility.typeId == getTypeId(T):
      let currentState = 1.StateType shl visibleState.ord.StateType
      let entityVisibility = visibility.states
      let expect = bitand(currentState, entityVisibility) > 0
      if expect != entity.visible:
        log "Changing entity visibility for ", eid, " to ", expect, " for state ", visibleState
        entity.visible = expect

template defineVisibleStateSystems*(name: untyped, T, S: typed): untyped =
  ## Shows sprites only when a specific game state is set
  proc evalVisibleState(
      _: EvaluateVisibleState,
      state: Shared[T],
      sprites: FullQuery[(VisibleState, Sprite)],
      anims: FullQuery[(VisibleState, Animation[S])],
  ) {.eventSys.} =
    updateVisility(T, state.get, sprites)
    updateVisility(T, state.get, anims)

  proc name(
      state: Shared[T], previous: Local[T], trigger: Outbox[EvaluateVisibleState]
  ) {.depends(evalVisibleState).} =
    if previous.isEmpty or previous != state.get:
      previous := state.get
      trigger(EvaluateVisibleState())
