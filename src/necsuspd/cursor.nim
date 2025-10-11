import necsus, positioned, inputs, util, fpvec, std/options, vmath, fungus, findDir

adtEnum(Selected):
  NoSelection
  EntitySelected:
    tuple[entityId: EntityId, position: Positioned]

export Selected, NoSelection, EntitySelected, FindDir, PDButton

type
  Selectable* {.accessory.} = object
    ## A component that marks entities that are selectable

  CursorControlDirs = object ## A component that controls the cursor
    find: FullQuery[(Selectable, Positioned)]
    notify: Outbox[Selected]
    selected: Local[EntitySelected]

  CursorControl* = Bundle[CursorControlDirs]

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

proc init*(control: CursorControl, startPos: FPVec2 = fpvec2(0, 0)) =
  ## Initializes the cursor position to the selectable element nearest the given position
  var nearest: Selected = NoSelection.init().Selected
  var dist: FPInt = high(FPInt)
  for eid, (_, pos) in control.find:
    let thisDist = distSq(startPos, pos.toFPVec2)
    if thisDist < dist:
      nearest = EntitySelected.init(eid, pos)
      dist = thisDist
  control.select(nearest)

iterator eligible(bundle: CursorControl): (Positioned, EntityId) =
  ## An iterator that returns the entities available when choosing a new cursor target
  for eid, (_, pos) in bundle.find:
    if bundle.selected.isEmpty or bundle.selected.get().entityId != eid:
      yield (pos, eid)

proc update*(control: CursorControl, dir: FindDir) =
  ## Updates the cursor's position in the direction of the given vector

  if control.selected.isEmpty:
    log "No current selection -- initializing cursor"
    control.init()
    return

  let current = control.selected.get().position
  log "Updating cursor for: ", dir, " with current position: ", current

  for (newPosition, newEntityId) in findDir[EntityId](eligible(control), dir, current):
    control.select(EntitySelected.init(newEntityId, newPosition).Selected)

proc update*(control: CursorControl, button: PDButton) =
  ## Updates the cursor's position and visibility based on a button event
  let found = button.asFindDir()
  if found.isSome:
    control.update(found.get())

template buildCursorUpdator*(name: untyped, activeStates: set) =
  ## Creates a system that updates the cursor's position
  proc `name`(
      button: ButtonPushed, control: CursorControl
  ) {.active(activeStates), eventSys.} =
    control.update(button)
