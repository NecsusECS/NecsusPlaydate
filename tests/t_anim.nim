import std/unittest, necsuspd/[anim, types]

type
  Sheets = enum
    SheetA
    SheetB

  Category = enum
    First
    Second

  State = enum
    Normal
    Selected

suite "Animation definitions":
  test "toAnimationDefs wraps each object in its own ref":
    var objs: array[Category, array[State, AnimationDefObj]]
    objs[First][Normal] =
      AnimationDefObj(sheet: SheetA.getEnumValue, frames: @[frame(0, 0.1)])
    objs[Second][Selected] =
      AnimationDefObj(sheet: SheetB.getEnumValue, frames: @[frame(3, 0.2)])

    let defs = objs.toAnimationDefs()
    check($defs[First][Normal] == $objs[First][Normal])
    check(defs[Second][Selected].frames[0].cellId == 3)
    check(defs[Second][Selected].sheet == objs[Second][Selected].sheet)
    check(defs[First][Selected] != nil)
    check(cast[pointer](defs[First][Normal]) != cast[pointer](defs[First][Selected]))
