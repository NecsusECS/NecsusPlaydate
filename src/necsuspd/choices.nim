##
## Allows the user to present a multiple choice option to the user. Each
## choice is represented visually by an entity with an Animation. A component
## is used to determine which choices are grouped together.
##
import necsus, std/options, util

when defined(unittests):
  import ../../tests/graphics_stub
else:
  import sprite

type
  Chosen {.accessory.} = object ## Tag component that flags the currently selected value

  ChosenAnim* = tuple[active, inactive: AnimationDef]
    ## The animations to use when the choice is selected or deselected

  ChoiceControl[T] = object
    mark: Attach[(Chosen,)]
    unmark: Detach[(Chosen,)]
    chosen: FullQuery[(Chosen, T, Animation, ChosenAnim)]

  Choices*[T] = Bundle[ChoiceControl[T]]

proc chosen*[T](choices: Choices[T]): Option[T] =
  ## Returns the value of the first chosen choice, if any.
  for (_, value, _, _) in choices.chosen:
    return some(value)

proc choose*(choices: Choices, eid: EntityId): EntityId {.discardable.} =
  ## Returns the value of the first chosen choice, if any.
  for existing, (_, _, anim, defs) in choices.chosen:
    choices.unmark(existing)
    anim.change(defs.inactive)

  choices.mark(eid, (Chosen(),))
  for (_, _, anim, defs) in choices.chosen:
    anim.change(defs.active)

  return eid

proc choose*(eid: EntityId, choices: Choices): EntityId {.discardable.} =
  ## Returns the value of the first chosen choice, if any.
  choose(choices, eid)
