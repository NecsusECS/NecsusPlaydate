import unittest, necsuspd/[drawable, anim], necsuspd/stubs/[sprites, graphics], vmath

type
  TestZIndex = enum
    Layer0

  TestSheet = enum
    Sheet0

suite "Drawable":
  test "newBitmapDrawable creates a drawable":
    let img = newImage("test", 16, 16, kColorBlack)
    let d = newBitmapDrawable(img, Layer0, AnchorTopLeft)
    check(d != nil)
    check(d.visible == true)

  test "newBlankDrawable creates a drawable":
    let d = newBlankDrawable(16, 16, Layer0, AnchorTopLeft)
    check(d != nil)

  test "visible can be toggled":
    let d = newBlankDrawable(16, 16, Layer0, AnchorTopLeft)
    d.visible = false
    check(d.visible == false)

  test "newSheet creates a drawable and animation":
    let def = animation(Sheet0, 0.1'f32, 0'i32 .. 2'i32, AnchorTopLeft)
    let frames = @[
      newImage("f0", 16, 16, kColorBlack),
      newImage("f1", 16, 16, kColorBlack),
      newImage("f2", 16, 16, kColorBlack),
    ]
    let (d, a) = newSheet(frames, def, Layer0)
    check(d != nil)
    check(a != nil)
    check(a.frame == 0)

  test "change updates frame and anchorOffset":
    let def = animation(Sheet0, 0.1'f32, 0'i32 .. 2'i32, AnchorTopLeft)
    let frames = @[
      newImage("f0", 16, 16, kColorBlack),
      newImage("f1", 16, 16, kColorBlack),
      newImage("f2", 16, 16, kColorBlack),
    ]
    let (d, a) = newSheet(frames, def, Layer0)
    let def2 = animation(Sheet0, 0.2'f32, 0'i32 .. 1'i32, AnchorMiddle)
    change(a, d, def2)
    check(a.frame == 0)
