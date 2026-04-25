##
## Allows the user to present a multiple choice option to the user. Each
## choice is represented visually by an entity with an Animation. A component
## is used to determine which choices are grouped together.
##
import necsus, std/options, util, anim

type
  Chosen {.accessory.} = object ## Tag component that flags the currently selected value

  ChosenAnim* = tuple[active, inactive: AnimationDef]
    ## The animations to use when the choice is selected or deselected

  ChoseEvent*[T] = tuple[eid: EntityId, value: T]
    ## An event that is triggered when a choice is selected

  ChoiceControl[T] = object
    mark: Attach[(Chosen,)]
    unmark: Detach[(Chosen,)]
    chosen: FullQuery[(Chosen, T, Option[Anim], Option[Drawable], Option[ChosenAnim])]
    find: Lookup[(T, Option[Anim], Option[Drawable], Option[ChosenAnim])]
    notify: Outbox[ChoseEvent[T]]

  Choices*[T] = Bundle[ChoiceControl[T]]

proc chosen*[T](choices: Choices[T]): Option[T] =
  ## Returns the value of the first chosen choice, if any.
  assert(choices.chosen.len <= 1)
  for (_, value, _, _, _) in choices.chosen:
    return some(value)

template setAnimation(anim: Option[Anim], drawable: Option[Drawable], def: Option[ChosenAnim], body: untyped) =
  if anim.isSome and drawable.isSome and def.isSome:
    let it {.inject.} = def.unsafeGet
    change(anim.unsafeGet, drawable.unsafeGet, body)

proc choose*[T](choices: Choices[T], eid: EntityId): EntityId {.discardable.} =
  ## Returns the value of the first chosen choice, if any.
  for (value, anim, drawable, defs) in choices.find(eid).items:
    for existing, (_, _, existingAnim, existingDrawable, existingDefs) in choices.chosen:
      if existing == eid:
        return
      choices.unmark(existing)
      setAnimation(existingAnim, existingDrawable, existingDefs, it.inactive)

    choices.mark(eid, (Chosen(),))
    setAnimation(anim, drawable, defs, it.active)
    log "Choosing ", $T, " as ", eid
    choices.notify((eid, value))

  return eid

proc choose*(eid: EntityId, choices: Choices): EntityId {.discardable.} =
  ## Returns the value of the first chosen choice, if any.
  choose(choices, eid)
