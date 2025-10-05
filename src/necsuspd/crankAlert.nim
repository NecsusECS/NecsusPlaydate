import necsus, playdate/api, sprite, positioned, util

type
  CrankMode* = enum
    CrankRequired
    CrankNotRequired

  CrankSprite {.maxCapacity(1).} = object

proc buildCrankAlerter*[Assets; SheetId: enum, Active: enum](
    crankSheetId: SheetId,
    zindex: enum,
    activeStates: set[Active] = {},
    initialState: CrankMode = CrankRequired,
): proc =
  return proc(
      assets: Shared[Assets],
      required: Shared[CrankMode],
      spawn: Spawn[(CrankSprite, Positioned, Animation)],
      activeState: Shared[Active],
  ): SystemInstance {.instanced.} =
    required := initialState
    var currentState = playdate.system.isCrankDocked()

    let anim = animation(crankSheetId, 0.1, 0'i32 .. 17'i32, AnchorBottomRight)
    var sheet = newSheet[SheetId](assets, anim, zIndex = zindex, absolutePos = true)
    sheet.sprite.visible = currentState
    spawn.with(CrankSprite(), positioned(LCD_COLUMNS, LCD_ROWS - 10), sheet)

    return proc() =
      let shouldShow =
        required == CrankRequired and playdate.system.isCrankDocked() and
        activeState.isSome and activeState.get in activeStates

      if shouldShow != currentState:
        currentState = shouldShow
        sheet.sprite.visible = currentState
