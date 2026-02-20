import macros, necsus, util, import_playdate, std/math

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
  when not defined(danger) and not defined(unittests):
    playdate.system.setSerialMessageCallback(
      proc(msg: string) =
        log "Debug message received: ", msg
        messages(msg)
    )

proc reportFPS*(delta: TimeDelta): SystemInstance =
  var times = newSeq[float]()
  return proc() =
    if times.len > 100:
      let fps = 100.0 / times.sum()
      playdate.system.logToConsole("FPS: " & $fps)
      times.setLen(0)
    times.add(delta())
