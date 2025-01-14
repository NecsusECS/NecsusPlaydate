import necsus, util, std/[macros, tables]

when not defined(unittests):
    import playdate/api, inputs
else:
    type
        PDButton* = enum kButtonA, kButtonB, kButtonUp, kButtonDown, kButtonLeft, kButtonRight
        ButtonPushed* = PDButton

type
    MultiStepState[T] = object
        nextIndex: int32
        lastExecuteTime: float32

    MultiStepControl[T] = object
        state: Local[MultiStepState[T]]
        buttons: Inbox[ButtonPushed]
        time: TimeElapsed

    MultiStep*[T] = Bundle[MultiStepControl[T]]

    StepId* = distinct int32

var steps {.compileTime.} = initTable[string, int32]()

proc `$`*(stepId: StepId): string = $int32(stepId)

proc shouldExec(steps: MultiStep, index: StepId): bool =
    return index.int32 == steps.state.getOrPut().nextIndex

proc advance(steps: MultiStep) =
    steps.state.getOrPut().nextIndex += 1
    steps.state.getOrPut().lastExecuteTime = steps.time()

macro signature(typeNode: typedesc): untyped =
    let typ = typeNode.getTypeInst
    typ.expectKind(nnkBracketExpr)
    return typ[1].signatureHash.newLit

proc stepId(typ: typedesc): StepId =
    let hash = typ.signature
    let current = steps.getOrDefault(hash)
    steps[hash] = current + 1
    return StepId(current)

template buildStep[T](index: StepId, steps: MultiStep[T], condition: bool, action: untyped) =
    if steps.shouldExec(index):
        if condition:
            action
        else:
            log "Condition not met for multi-step ", $T, " #", index, "... skipping"
            steps.advance()

template maybeStep*[T](steps: MultiStep[T], condition: bool, action: untyped) =
    const index = stepId(T)
    buildStep(index, steps, condition):
        log "Executing multi-step ", $T, " #", index
        steps.advance()
        action

template step*[T](steps: MultiStep[T], action: untyped) =
    maybeStep(steps, true, action)

template done*[T](steps: MultiStep[T]) =
    maybeStep(steps, true):
        discard

template awaitButton*[T](steps: MultiStep[T], triggers: set[PDButton], debounce: float32 = 0.2, condition: bool = true) =
    const index = stepId(T)
    buildStep(index, steps, condition):
        for event in steps.buttons:
            if event in triggers and steps.time() - steps.state.getOrPut().lastExecuteTime >= debounce:
                log "Executing awaitButton multi-step ", $T, " #", index
                steps.advance()

template await*[T](steps: MultiStep[T], delay: float32, condition: bool = true) =
    const index = stepId(T)
    buildStep(index, steps, condition):
        if steps.time() - steps.state.getOrPut().lastExecuteTime >= delay:
            log "Executing await multi-step ", $T, " #", index
            steps.advance()

proc reset*[T](steps: MultiStep[T]) =
    steps.state := default(MultiStepState[T])

template finalStep*[T](steps: MultiStep[T], action: untyped) =
    const index = stepId(T)
    buildStep(index, steps, true):
        log "Executing final multi-step ", $T, " #", index
        steps.reset()
        action
