import std/unittest, necsuspd/drawlayer, necsuspd/stubs/graphics

proc makeLCDItem(z: int16, visible = true): DrawItem =
  newDrawItem(newImage("t", 4, 4, kColorWhite), z, visible)

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
