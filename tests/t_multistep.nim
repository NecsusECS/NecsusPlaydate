import unittest, necsus, necsuspd/[multistep]

type
    TestStep1 = object
    TestStep2 = object
    TestStep3 = object
    TestStep4 = object
    TestStep5 = object
    TestStep6 = object
    TestStep7 = object
    TestStep8 = object
    TestStep9 = object
    TestStep10 = object

runSystemOnce do (steps: MultiStep[TestStep1]) -> void:
    test "Basic step execution":
        var stepExecuted = [ false, false, false ]
        steps.step:
            stepExecuted[0] = true

        steps.step:
            stepExecuted[1] = true

        steps.step:
            stepExecuted[2] = true

        check(stepExecuted == [ true, true, true ])

runSystemOnce do (steps: MultiStep[TestStep2]) -> void:
    test "Maybe step execution: false":
        var stepExecuted = false
        steps.maybeStep(false):
            check(false)
        steps.step:
            stepExecuted = true
        check(stepExecuted)

runSystemOnce do (steps: MultiStep[TestStep3]) -> void:
    test "Maybe step execution: true":
        var stepExecuted = [ false, false ]
        steps.maybeStep(true):
            stepExecuted[0] = true

        steps.step:
            stepExecuted[1] = true

        check(stepExecuted == [ true, true ])

runSystemOnce do (steps: MultiStep[TestStep4]) -> void:
    test "Nested steps":
        var stepExecuted = [ false, false ]
        steps.step:
            stepExecuted[0] = true
            steps.step:
                stepExecuted[1] = true

        check(stepExecuted == [ true, true ])

runSystemOnce do (steps: MultiStep[TestStep5]) -> void:
    test "Await button steps: no input":
        steps.awaitButton({ kButtonA }, debounce = 0.0)
        steps.step:
            check(false)

runSystemOnce do (steps: MultiStep[TestStep6], pushed: Outbox[ButtonPushed]) -> void:
    test "Await button steps: with input":
        pushed(kButtonA)
        var stepExecuted = false
        steps.awaitButton({ kButtonA }, debounce = 0.0)
        steps.step:
            stepExecuted = true
        check(stepExecuted)

runSystemOnce do (steps: MultiStep[TestStep7]) -> void:
    test "Await delay steps: not long enough":
        steps.await(1.0)
        steps.step:
            check(false)

runSystemOnce do (steps: MultiStep[TestStep8]) -> void:
    test "Await delay steps: time met":
        var stepExecuted = false
        steps.await(0.0)
        steps.step:
            stepExecuted = true
        check(stepExecuted)

runSystemOnce do (steps: MultiStep[TestStep9]) -> void:
    test "Resetting":
        var stepExecuted = 0
        for i in 0..<3:
            steps.step:
                stepExecuted += 1
            steps.reset
        check(stepExecuted == 3)

runSystemOnce do (steps: MultiStep[TestStep10]) -> void:
    test "Final step execution":
        var stepExecuted = 0
        for i in 0..<3:
            steps.step:
                stepExecuted += 1

            steps.finalStep:
                stepExecuted += 1

        check(stepExecuted == 6)
