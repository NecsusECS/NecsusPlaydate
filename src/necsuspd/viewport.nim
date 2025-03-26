import playdate/api, vmath, necsus, macros

type
  ViewPort* = IVec2 ## The upper left corner of the viewport

  ViewPortTweak* = IVec2 ## An adjustment to apply to the viewport

proc maxX*(viewport: ViewPort): int32 =
  ## Returns the X position on the right side of the screen
  viewport.x + LCD_COLUMNS.int32

proc maxY*(viewport: ViewPort): int32 =
  ## Returns the Y position on the right side of the screen
  viewport.y + LCD_ROWS.int32

template readFromShared(name) =
  proc `name`*(viewport: Shared[ViewPort]): auto =
    viewport.get().`name`

readFromShared(x)
readFromShared(y)
readFromShared(maxX)
readFromShared(maxY)

proc moveBy*(viewport: Shared[ViewPort], delta: IVec2) =
  ## Moves the viewport by a given delta
  viewport.getOrPut += delta
