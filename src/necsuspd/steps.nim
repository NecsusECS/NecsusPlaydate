import necsus, util

## Event-driven step sequencer tied to an enum. Each `advance` or `advanceViaTick`
## call in a startup system claims the next enum value in order; a debug assert
## catches declaration-order mismatches at startup.

type Step*[T: enum] = ref object
  ## Tracks progress through a sequence of steps defined by enum `T`.
  ## Create with `newStep`, then call `advance`/`advanceViaTick` in order.
  current: T
  nextDeclared: T
  onAdvance: proc(step: T)
  enterHandlers: array[T, proc()]

proc newStep*[T: enum](
    _: typedesc[T],
    onAdvance: proc(step: T) = proc(_: T) =
      discard,
): Step[T] =
  ## Creates a new Step sequencer for enum `T`. `onAdvance` is called with the
  ## new step value every time the current step changes, including via `advance`.
  Step[T](current: low(T), nextDeclared: low(T), onAdvance: onAdvance)

proc current*[T: enum](step: Step[T]): T =
  ## Returns the current step.
  step.current

proc advance*[T: enum](step: Step[T], to: T = succ(step.current)) =
  ## Jumps to `to` (default: next step) and calls `onAdvance` and any `onEnter` handler.
  log "Step[", $T, "] ", $step.current, " -> ", $to
  step.current = to
  step.onAdvance(to)
  if step.enterHandlers[to] != nil:
    step.enterHandlers[to]()

proc reenter*[T: enum](step: Step[T]) =
  ## Re-fires `onAdvance` and any `onEnter` handler for the current step without
  ## changing it. Use when external state may have changed without the step changing.
  log "Step[", $T, "] reenter ", $step.current
  step.onAdvance(step.current)
  if step.enterHandlers[step.current] != nil:
    step.enterHandlers[step.current]()

proc skip*[T: enum](step: Step[T], expected: T) =
  ## Advances `nextDeclared` past `expected` without registering any handler.
  ## Use for steps handled by custom event logic that can't go through `advance`.
  assert step.nextDeclared == expected,
    "Step declaration mismatch: expected " & $expected & " but nextDeclared is " &
      $step.nextDeclared
  log "Step[", $T, "] skip ", $expected
  step.nextDeclared = succ(step.nextDeclared)

template onEnter*[T: enum](step: Step[T], val: T, body: untyped) =
  ## Registers a callback that fires whenever `val` is entered (via `advance` or `reenter`).
  ## Does not affect step sequencing.
  step.enterHandlers[val] = proc() =
    log "Step[", $T, "] onEnter ", $val
    body

template advance*[T: enum, E](
    step: Step[T], fromStep: T, on: RegisterEventSystem[E], body: untyped
) =
  ## Advances the step when event `E` fires on `on` and the sequencer is on `expected`.
  ## Runs `body` on advance. The event type is inferred from `on`.
  let thisStep = step.nextDeclared
  assert thisStep == fromStep,
    "Step declaration mismatch: expected " & $fromStep & " but nextDeclared is " &
      $thisStep
  step.nextDeclared = succ(step.nextDeclared)
  on do(_: E) -> void:
    if step.current == thisStep:
      log "Step[", $T, "] event ", $E, " fired on ", $thisStep
      step.advance(succ(thisStep))
      body

template advance*[T: enum, E](step: Step[T], fromStep: T, on: RegisterEventSystem[E]) =
  ## Like `advance` with a body, but with no side effects on advance.
  advance(step, fromStep, on):
    discard

template advance*[T: enum, E](
    step: Step[T], fromStep: T, to: T, on: RegisterEventSystem[E], body: untyped
) =
  ## Advances to `to` (explicit destination) when event `E` fires and sequencer is on
  ## `fromStep`. Multiple calls with the same `fromStep` are allowed for branching.
  if step.nextDeclared == fromStep:
    step.nextDeclared = succ(fromStep)
  let toStep = to
  on do(_: E) -> void:
    if step.current == fromStep:
      log "Step[", $T, "] event ", $E, " fired on ", $fromStep, " -> ", $toStep
      step.advance(toStep)
      body

template advance*[T: enum, E](
    step: Step[T], fromStep: T, to: T, on: RegisterEventSystem[E]
) =
  ## Like `advance` with explicit `to`, but with no side effects on advance.
  advance(step, fromStep, to, on):
    discard

template advanceIf*[T: enum, E](
    step: Step[T],
    fromStep: T,
    on: RegisterEventSystem[E],
    condition: untyped,
    body: untyped,
) =
  ## Like `advance` but only advances when `condition` is true when the event fires.
  ## Runs `body` on advance. Does not advance if condition is false.
  let thisStep = step.nextDeclared
  assert thisStep == fromStep,
    "Step declaration mismatch: expected " & $fromStep & " but nextDeclared is " &
      $thisStep
  step.nextDeclared = succ(step.nextDeclared)
  on do(_: E) -> void:
    if step.current == thisStep and condition:
      log "Step[", $T, "] conditional event ", $E, " met on ", $thisStep
      step.advance(succ(thisStep))
      body

template advanceIf*[T: enum, E](
    step: Step[T], fromStep: T, on: RegisterEventSystem[E], condition: untyped
) =
  ## Like `advanceIf` with a body, but with no side effects on advance.
  advanceIf(step, fromStep, on, condition):
    discard

template advanceViaTick*[T: enum](
    step: Step[T], fromStep: T, on: RegisterSystem, body: untyped
) =
  ## Registers a tick system via `on` that advances when `body` returns true.
  let thisStep = step.nextDeclared
  assert thisStep == fromStep,
    "Step declaration mismatch: expected " & $fromStep & " but nextDeclared is " &
      $thisStep
  step.nextDeclared = succ(step.nextDeclared)
  on do() -> void:
    if step.current == thisStep:
      if body:
        log "Step[", $T, "] tick condition met on ", $thisStep
        step.advance(succ(thisStep))

template advanceViaTick*[T: enum](step: Step[T], fromStep: T, on: RegisterSystem) =
  ## Like `advanceViaTick` with a body, but advances unconditionally each tick.
  advanceViaTick(step, fromStep, on):
    true
