import playdate/api, vmath
import util, debug

proc getTime*(): float {.gcsafe.} =
  {.cast(gcsafe).}:
    playdate.system.getElapsedTime()

proc log*(message: string) {.gcsafe.} =
  {.cast(gcsafe).}:
    playdate.system.logToConsole(message)

template reportError(body: untyped) =
  try:
    body
  except Exception as e:
    playdate.system.error(e.msg & "\n" & e.getStackTrace)
    quit(e.msg & "\n" & e.getStackTrace)

template initNecsusPlaydate*(
    appTyp: typedesc, initNecsusApp: untyped, handle: untyped
) =
  var appInst {.inject.}: appTyp

  proc update(): int {.raises: [].} =
    reportError:
      appInst.tick()
    return 1

  proc handler(
      event {.inject.}: PDSystemEvent, keycode {.inject.}: uint
  ) {.raises: [].} =
    case event
    of kEventInit:
      log "Beginning playdate initialization"
      playdate.display.setRefreshRate(50)
      playdate.system.setPeripheralsEnabled(kAllPeripherals)
      playdate.system.setUpdateCallback(update)
      playdate.graphics.setDrawMode(kDrawModeWhiteTransparent)

      when defined(simulator):
        discard playdate.graphics.getDebugBitmap()

      reportError:
        log "Beginning app initialization"
        initNecsusApp
        handle
      log "Initialization done"
    of kEventTerminate:
      log "Shutting down"
      reportError:
        handle
        `=destroy`(appInst)
      log "Shutdown complete"
    of kEventKeyPressed:
      when compiles(sendDebugKey(appInst, DebugKey(keycode.char))):
        reportError:
          sendDebugKey(appInst, DebugKey(keycode.char))
      reportError:
        handle
    else:
      reportError:
        handle

  initSDK()
