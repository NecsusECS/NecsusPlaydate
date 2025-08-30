import macros, necsus, playdate/api, util

type
  DebugKey* = char ## A single key pressed by the user.

  DebugInput* = string ## A message received from the debug input handler.

macro debugSys*(system: typed): untyped =
  ## Pragma for a system that only needs to operate when debug mode is enabled
  if not defined(playdate):
    system
  else:
    let name = system.name
    quote:
      proc `name`*() =
        discard

proc debugInputHandler*(messages: Outbox[DebugInput]) {.startupSys.} =
  ## Attaches a handler for debug input messages.
  when not defined(danger):
    playdate.system.setSerialMessageCallback(
      proc(msg: string) =
        log "Debug message received: ", msg
        messages(msg)
    )
