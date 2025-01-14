when not defined(unittests):
    import playdate/api
else:
    type
        PDButton* = enum kButtonLeft = 1, kButtonRight, kButtonUp, kButtonDown, kButtonB, kButtonA
        PDButtons* = set[PDButton]

type
    ButtonsHeld* = PDButtons
        ## Tracks buttons that are currently pushed

    ButtonPushed* = PDButton
        ## Messages for buttons newly pushed

    ButtonRelease* = PDButton
        ## Message for a button that was released

    CrankAngle* = float32
        ## The angle of the crank

    CrankDelta* = float32
        ## The change in the angle of the crank

when not defined(unittests):
    import necsus

    proc readInputs*(
        heldButtons: Shared[ButtonsHeld],
        sendPushed: Outbox[ButtonPushed],
        sendReleased: Outbox[ButtonRelease],
        crankAngle: Shared[CrankAngle],
        crankDelta: Shared[CrankDelta],
    ) =
        ## Reads and publishes the state of various inputs from the Playdate API
        let (current, pushed, released) = playdate.system.getButtonState()
        heldButtons.set(current)

        for button in pushed:
            sendPushed(button)

        for button in released:
            sendReleased(button)

        crankAngle.set(playdate.system.getCrankAngle())
        crankDelta.set(playdate.system.getCrankChange())
