type AppSuspended* = object
  ## Fired when the Playdate pauses, locks, or terminates the game, so
  ## buffered state can be persisted before play stops. Sent by
  ## `initNecsusPlaydate` to any app that listens for it.
