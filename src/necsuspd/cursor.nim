import
  necsus,
  positioned,
  inputs,
  util,
  util/stateflips,
  fpvec,
  std/options,
  vmath,
  fungus,
  findDir,
  drawable,
  types

adtEnum(Selected):
  NoSelection
  EntitySelected:
    tuple[entityId: EntityId, position: FPVec2]

export Selected, NoSelection, EntitySelected, FindDir, PDButton

type
  Selectable* {.accessory.} = object
    ## A component that marks entities that are selectable

  SelectableState* {.accessory.} = distinct StateFlip

  EvaluateSelectableState* = object

  CursorControlDirs[T] = object ## A component that controls the cursor
    find: FullQuery[(T, Selectable, Positioned, Option[Drawable])]
    notify: Outbox[Selected]
    selected: Local[EntitySelected]

  CursorControl*[T] = Bundle[CursorControlDirs[T]]

proc entityId*(selected: Selected): Option[EntityId] =
  ## Returns the entity ID of the selected entity, or None if no entity is selected.
  if (selected: EntitySelected) from selected:
    return some(selected.entityId)

proc selection*(control: CursorControl): Selected =
  ## Returns the currently selected entity, or NoSelection if none is selected.
  return
    if control.selected.isSome:
      control.selected.getOrRaise().Selected
    else:
      NoSelection.init().Selected

proc select*(control: CursorControl, selected: Selected) =
  ## Triggers selection of a specific entity
  log "Selecting cursor as ", selected
  control.notify(selected)
  match selected:
  of NoSelection:
    control.selected.clear
  of EntitySelected as selected:
    control.selected := selected

proc size(drawable: Option[Drawable]): FPVec2 =
  drawable.withValue(it):
    return fpvec2(it.width, it.height)
  return fpvec2(0, 0)

proc centroid[A, B](entity: (A, B, Positioned, Option[Drawable])): FPVec2 =
  let (_, _, pos, drawable) = entity
  return pos.toFPVec2 + (size(drawable) / fpvec2(2, 2))

iterator eligible[T](bundle: CursorControl[T]): (FPVec2, EntityId) =
  ## An iterator that returns the entities available when choosing a new cursor target
  for eid, entity in bundle.find:
    if bundle.selected.isEmpty or bundle.selected.get().entityId != eid:
      yield (entity.centroid, eid)

proc init*[T](control: CursorControl[T], startPos: FPVec2 = fpvec2(0, 0)) =
  ## Initializes the cursor position to the selectable element nearest the given position.
  var nearest: Selected = NoSelection.init().Selected
  var dist: FPInt = high(FPInt)
  for eid, entity in control.find:
    let coord = entity.centroid
    let thisDist = distSq(startPos, coord)
    if thisDist < dist:
      nearest = EntitySelected.init(eid, coord)
      dist = thisDist
  control.select(nearest)

proc update*[T](control: CursorControl[T], dir: FindDir) =
  ## Updates the cursor's position in the direction of the given vector

  if control.selected.isEmpty:
    log "No current selection -- initializing cursor"
    control.init()
    return

  let current = control.selected.get().position.toFPVec2
  log "Updating cursor for: ", dir, " with current position: ", current

  let dir = findDir[EntityId](eligible[T](control), dir, current)
  if dir.isSome:
    let (newPosition, newEntityId) = dir.get()
    control.select(EntitySelected.init(newEntityId, newPosition).Selected)

proc update*[T](control: CursorControl[T], button: PDButton) =
  ## Updates the cursor's position and visibility based on a button event
  let found = button.asFindDir()
  if found.isSome:
    control.update(found.get())

template buildCursorUpdator*(name, typ: untyped, activeStates: set) =
  ## Creates a system that updates the cursor's position
  proc `name`(
      button: ButtonPushed, control: CursorControl[typ]
  ) {.active(activeStates), eventSys.} =
    control.update(button)

proc selectableState*[T: enum](states: set[T]): SelectableState =
  ## Creates a SelectableState component that marks an entity as selectable in the given states
  SelectableState(stateFlip(states))

proc selectableState*[T: enum](states: varargs[T]): SelectableState =
  ## Creates a SelectableState component that marks an entity as selectable in the given states
  SelectableState(stateFlip(states))

template defineSelectableStateSystems*(name: untyped, T: typed): untyped =
  ## Toggles the Selectable component on entities based on the current state
  proc evalSelectableState(
      _: EvaluateSelectableState,
      state: Shared[T],
      toAdd: FullQuery[(SelectableState, Not[Selectable])],
      toRemove: FullQuery[(SelectableState, Selectable)],
      attach: Attach[(Selectable,)],
      detach: Detach[(Selectable,)],
  ) {.eventSys.} =
    for eid, (selectState, _) in toAdd:
      let flip = StateFlip(selectState)
      if flip.typeId == getTypeId(T) and matchesState(flip.states, state.get):
        attach(eid, (Selectable(),))
    for eid, (selectState, _) in toRemove:
      let flip = StateFlip(selectState)
      if flip.typeId == getTypeId(T) and not matchesState(flip.states, state.get):
        detach(eid)

  proc name(
      state: Shared[T], previous: Local[T], trigger: Outbox[EvaluateSelectableState]
  ) {.depends(evalSelectableState).} =
    if previous.isEmpty or previous != state.get:
      previous := state.get
      trigger(EvaluateSelectableState())
