import necsus, positioned, inputs, util, fpvec, std/options, vmath, fungus, findDir

when defined(unittests):
  import ../../tests/graphics_stub
else:
  import sprite

adtEnum(Selected):
  NoSelection
  EntitySelected:
    tuple[entityId: EntityId, position: FPVec2]

export Selected, NoSelection, EntitySelected, FindDir, PDButton

type
  Selectable* {.accessory.} = object
    ## A component that marks entities that are selectable

  CursorControlDirs = object ## A component that controls the cursor
    find: FullQuery[(Selectable, Positioned, Option[Sprite], Option[Animation])]
    notify: Outbox[Selected]
    selected: Local[EntitySelected]

  CursorControl* = Bundle[CursorControlDirs]

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

proc size(sprite: Option[Sprite], anim: Option[Animation]): FPVec2 =
  sprite.withValue(it):
    return fpvec2(it.width, it.height)
  anim.withValue(it):
    return fpvec2(it.width, it.height)
  return fpvec2(0, 0)

proc centroid[T](entity: (T, Positioned, Option[Sprite], Option[Animation])): FPVec2 =
  let (_, pos, sprite, anim) = entity
  return pos.toFPVec2 + (size(sprite, anim) / fpvec2(2, 2))

iterator eligible(bundle: CursorControl): (FPVec2, EntityId) =
  ## An iterator that returns the entities available when choosing a new cursor target
  for eid, entity in bundle.find:
    if bundle.selected.isEmpty or bundle.selected.get().entityId != eid:
      yield (entity.centroid, eid)

proc init*(control: CursorControl, startPos: FPVec2 = fpvec2(0, 0)) =
  ## Initializes the cursor position to the selectable element nearest the given position
  var nearest: Selected = NoSelection.init().Selected
  var dist: FPInt = high(FPInt)
  for (coord, eid) in control.eligible():
    let thisDist = distSq(startPos, coord)
    if thisDist < dist:
      nearest = EntitySelected.init(eid, coord)
      dist = thisDist
  control.select(nearest)

proc update*(control: CursorControl, dir: FindDir) =
  ## Updates the cursor's position in the direction of the given vector

  if control.selected.isEmpty:
    log "No current selection -- initializing cursor"
    control.init()
    return

  let current = control.selected.get().position.toFPVec2
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
