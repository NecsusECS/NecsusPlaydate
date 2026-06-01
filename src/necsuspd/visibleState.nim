import necsus, drawable, import_playdate, util, util/stateflips, types

type
  VisibleStateMode* = enum
    ShowAndHide
    OnlyHide
    OnlyShow

  VisibleState* = object
    mode*: VisibleStateMode
    states*: StateFlip

  EvaluateVisibleState* = object

proc visibility*[T: enum](states: set[T], mode = ShowAndHide): VisibleState =
  VisibleState(mode: mode, states: stateFlip(states))

proc visibility*[T: enum](states: varargs[T]): VisibleState =
  VisibleState(mode: ShowAndHide, states: stateFlip(states))

proc isVisible*[T](visibility: VisibleState, state: Shared[T]): bool =
  assert(visibility.states.typeId == getTypeId(T))
  return matchesState(visibility.states.states, state.get)

template defineVisibleStateSystems*(name: untyped, T: typed): untyped =
  ## Shows sprites only when a specific game state is set
  proc evalVisibleState(
      _: EvaluateVisibleState,
      state: Shared[T],
      drawables: FullQuery[(VisibleState, ptr Drawable)],
  ) {.eventSys.} =
    let visibleState = state.get
    for eid, (visibility, drawable) in drawables:
      if visibility.states.typeId != getTypeId(T):
        continue
      let expect = matchesState(visibility.states.states, visibleState)
      let newVisible =
        case visibility.mode
        of ShowAndHide: expect
        of OnlyHide: expect and drawable.visible
        of OnlyShow: expect or drawable.visible
      if newVisible != drawable.visible:
        log "Changing visibility for ",
          eid, " to ", newVisible, " for state ", visibleState
        drawable.visible = newVisible

  proc name(
      state: Shared[T], previous: Local[T], trigger: Outbox[EvaluateVisibleState]
  ) {.depends(evalVisibleState).} =
    if previous.isEmpty or previous != state.get:
      previous := state.get
      trigger(EvaluateVisibleState())
