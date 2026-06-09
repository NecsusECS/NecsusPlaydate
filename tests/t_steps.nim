import unittest, necsus, necsuspd/steps

type
  Ev = object
  EvA = object
  EvB = object

  Phase = enum
    First
    Second
    Third
    Done

template fakeEventSystem(handler: untyped, E: typedesc): RegisterEventSystem[E] =
  proc(sys: DynamicEventSystem[E]) {.closure.} =
    handler = sys

template fakeTickSystem(system: untyped): RegisterSystem =
  proc(sys: DynamicSystem) {.closure.} =
    system = sys

suite "steps":
  test "advance: advances step and runs body when event fires":
    var advanceCalls = 0
    var eventBodyRan = false
    var handler: DynamicEventSystem[Ev]
    let step = newStep(Phase) do(_: Phase) -> void:
      inc advanceCalls
    step.advance(First, fakeEventSystem(handler, Ev)):
      eventBodyRan = true
    handler(Ev())
    check eventBodyRan
    check advanceCalls == 1

  test "advance: does not advance when on wrong step":
    var advanced = false
    var handler: DynamicEventSystem[Ev]
    let step = newStep(Phase) do(_: Phase) -> void:
      advanced = true
    step.advance(Second)
    advanced = false
    step.advance(First, fakeEventSystem(handler, Ev)): discard
    handler(Ev())
    check not advanced

  test "advanceViaTick: advances when body returns true":
    var tickBodyRan = false
    var advanceCalls = 0
    var tickSystem: DynamicSystem
    let step = newStep(Phase) do(_: Phase) -> void:
      inc advanceCalls
    step.advanceViaTick(First, fakeTickSystem(tickSystem)):
      tickBodyRan = true
      true
    tickSystem()
    check tickBodyRan
    check advanceCalls == 1

  test "advanceViaTick: does not advance when body returns false":
    var tickBodyRan = false
    var advanceCalls = 0
    var tickSystem: DynamicSystem
    let step = newStep(Phase) do(_: Phase) -> void:
      inc advanceCalls
    step.advanceViaTick(First, fakeTickSystem(tickSystem)):
      tickBodyRan = true
      false
    tickSystem()
    check tickBodyRan
    check advanceCalls == 0

  test "set: updates current and calls onAdvance":
    var advanceCalls = 0
    let step = newStep(Phase) do(_: Phase) -> void:
      inc advanceCalls
    step.advance(Second)
    check step.current == Second
    check advanceCalls == 1

  test "multiple steps advance in sequence":
    var advanceCalls = 0
    var handlerA: DynamicEventSystem[EvA]
    var handlerB: DynamicEventSystem[EvB]
    var tickSystem: DynamicSystem
    let step = newStep(Phase) do(_: Phase) -> void:
      inc advanceCalls
    step.advance(First, fakeEventSystem(handlerA, EvA)): discard
    step.advance(Second, fakeEventSystem(handlerB, EvB)): discard
    step.advanceViaTick(Third, fakeTickSystem(tickSystem)): true
    handlerA(EvA())
    handlerB(EvB())
    tickSystem()
    check advanceCalls == 3
    check step.current == Done

  test "onEnter fires when set reaches that step":
    var enterCalls = 0
    var advanceCalls = 0
    let step = newStep(Phase) do(_: Phase) -> void:
      inc advanceCalls
    step.onEnter(Second):
      inc enterCalls
    step.advance(Second)
    check enterCalls == 1
    check advanceCalls == 1

  test "onEnter fires when awaitEvent advances to that step":
    var enterCalls = 0
    var handler: DynamicEventSystem[Ev]
    let step = newStep(Phase)
    step.onEnter(Second):
      inc enterCalls
    step.advance(First, fakeEventSystem(handler, Ev))
    handler(Ev())
    check enterCalls == 1

  test "reenter fires onAdvance and onEnter without changing step":
    var reenterAdvance = 0
    var reenterEnter = 0
    var reenterStep: Phase
    let step = newStep(Phase) do(s: Phase) -> void:
      inc reenterAdvance
      reenterStep = s
    step.onEnter(First):
      inc reenterEnter
    step.advance(First)
    reenterAdvance = 0
    reenterEnter = 0
    step.reenter()
    check reenterAdvance == 1
    check reenterEnter == 1
    check reenterStep == First

  test "reenter with no onEnter registered does not crash":
    let step = newStep(Phase)
    step.reenter()
    check true

  test "advance (conditional): advances and runs body when condition is true":
    var conditionalAdvanced = false
    var conditionalBody = false
    var handler: DynamicEventSystem[Ev]
    let step = newStep(Phase) do(_: Phase) -> void:
      conditionalAdvanced = true
    step.advanceIf(First, fakeEventSystem(handler, Ev), true):
      conditionalBody = true
    handler(Ev())
    check conditionalAdvanced
    check conditionalBody

  test "advance (conditional): does not advance when condition is false":
    var conditionalAdvanced = false
    var handler: DynamicEventSystem[Ev]
    let step = newStep(Phase) do(_: Phase) -> void:
      conditionalAdvanced = true
    step.advanceIf(First, fakeEventSystem(handler, Ev), false)
    handler(Ev())
    check not conditionalAdvanced
