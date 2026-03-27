import std/bitops, ../types

type
  StateType* = uint64

  StateFlip* = object
    states*: StateType
    typeId*: TypeId

proc buildStateMask[T: enum](states: set[T]): StateType =
  for value in states:
    const maxSize = sizeof(StateType) * 8
    assert(
      ord(value) <= maxSize,
      "State value exceeds maximum allowed: " & $ord(value) & " vs " & $maxSize,
    )
    result.flipBit(value.ord.StateType)

proc stateFlip*[T: enum](states: set[T]): StateFlip =
  ## Builds a StateFlip from a set of enum values
  StateFlip(typeId: getTypeId(T), states: buildStateMask(states))

proc stateFlip*[T: enum](states: varargs[T]): StateFlip =
  ## Builds a StateFlip from a list of enum values
  var fullList: set[T]
  for state in states:
    incl(fullList, state)
  stateFlip(fullList)

proc matchesState*[T: enum](mask: StateType, state: T): bool =
  ## Returns true if the given state matches any bit in the mask
  let currentBit = 1.StateType shl state.ord.StateType
  bitand(currentBit, mask) > 0
