import std/unittest, necsuspd/[drawlayer, hebitmap], necsuspd/stubs/graphics, vmath

proc makeLCDItem(z: int16, visible = true): DrawItem =
  return newDrawItem(newImage("t", 4, 4, kColorWhite), z, visible)

proc makeHEItem(z: int16, visible = true): DrawItem =
  return newDrawItem(fromLCDBitmap(newImage("t", 4, 4, kColorWhite)), z, visible)

suite "register / unregister":
  setup:
    resetDrawLayer()

  test "registered item appears in bucket":
    let item = makeLCDItem(0)
    register(item)
    check gDrawLayer[0].len == 1
    check gDrawLayer[0][0] == item

  test "unregister removes item from bucket":
    let item = makeLCDItem(0)
    register(item)
    unregister(item)
    check gDrawLayer[0].len == 0

  test "unregister nil is a no-op":
    unregister(nil)

  test "unregister item that was never registered is a no-op":
    let item = makeLCDItem(0)
    unregister(item)

  test "items at different zIndex land in correct buckets":
    let a = makeLCDItem(0)
    let b = makeLCDItem(2)
    register(a)
    register(b)
    check gDrawLayer[0][0] == a
    check gDrawLayer[2][0] == b

suite "drawSprites":
  setup:
    resetDrawLayer()
    resetFrameBuffer()

  test "hidden item is not drawn":
    let item = makeHEItem(0, visible = false)
    register(item)
    drawSprites()
    check framebufferRow(0)[0] == 'X'

  test "visible HE item is drawn to framebuffer":
    let item = makeHEItem(0, visible = true)
    register(item)
    drawSprites()
    check framebufferRow(0)[0 ..< 4] == "...."

  test "items drawn in ascending zIndex order":
    # z=1 white 4x1, z=0 black 4x1 at same position — z=1 should overwrite z=0
    let black = fromLCDBitmap(newImage("b", 4, 1, kColorBlack))
    let white = fromLCDBitmap(newImage("w", 4, 1, kColorWhite))
    let lo = newDrawItem(black, 0)
    let hi = newDrawItem(white, 1)
    register(lo)
    register(hi)
    drawSprites()
    check framebufferRow(0)[0 ..< 4] == "...."

  test "multiple items at same zIndex draw in insertion order":
    # Two 4-pixel items: first sets cols 0-3, second sets cols 4-7
    let bmp1 = fromLCDBitmap(newImage("a", 4, 1, kColorWhite))
    let bmp2 = fromLCDBitmap(newImage("b", 4, 1, kColorWhite))
    let a = newDrawItem(bmp1, 0)
    let b = newDrawItem(bmp2, 0, pos = ivec2(4, 0))
    register(a)
    register(b)
    drawSprites()
    check framebufferRow(0)[0 ..< 8] == "........"

  test "unregistered item is not drawn":
    let item = makeHEItem(0)
    register(item)
    unregister(item)
    drawSprites()
    check framebufferRow(0)[0] == 'X'
