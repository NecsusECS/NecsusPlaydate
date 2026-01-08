import vmath, necsus, import_playdate

importPlaydateApi()

export PDButton, PDButtons

type
  ButtonsHeld* = PDButtons ## Tracks buttons that are currently pushed

  ButtonPushed* = PDButton ## Messages for buttons newly pushed

  ButtonRelease* = PDButton ## Message for a button that was released

  CrankAngle* = float32 ## The angle of the crank

  CrankDelta* = float32 ## The change in the angle of the crank

proc asVector*(button: PDButton): IVec2 =
  ## Returns a button push as a vector
  case button
  of kButtonLeft:
    ivec2(-1, 0)
  of kButtonRight:
    ivec2(1, 0)
  of kButtonUp:
    ivec2(0, -1)
  of kButtonDown:
    ivec2(0, 1)
  of kButtonB, kButtonA:
    ivec2(0, 0)

const dpadButtons* = {kButtonUp, kButtonDown, kButtonLeft, kButtonRight}

template buildHeldButtonRepeater*(
    name: untyped, forButtons: set[PDButton], activeStates: typed
) =
  ## Builds a system that simulates button presses when a button is held down
  proc `name`(
      held: Shared[ButtonsHeld],
      trigger: Outbox[ButtonPushed],
      time: TimeElapsed,
      nextTriggerTime: Local[float32],
  ) {.active(activeStates).} =
    let buttons = held.get() * forButtons
    if buttons.card == 0:
      nextTriggerTime.clear
    elif nextTriggerTime.isEmpty:
      nextTriggerTime := time() + 0.2
    elif time() >= nextTriggerTime.get():
      nextTriggerTime := time() + 0.06
      for button in buttons:
        trigger(button)

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
