import necsuspd/stubs/[sprites, graphics], necsuspd/sprite

type
  TestZIndex* = enum
    FirstLayer

  TestAnimSheet* = enum
    SampleSheet

proc newSprite*(name: string, width, height: int): Sprite =
  newBitmapSprite(newImage(name, width, height, kColorBlack), FirstLayer, AnchorTopLeft)

proc newAnimationDef*(id: int = 0): AnimationDef =
  return animation(SampleSheet, 0.1'f32, 0'i32 .. 0'i32, AnchorTopLeft)

proc newAnimation*(
    name: string, width, height: int, def: AnimationDef = newAnimationDef()
): Animation =
  newSheet(@[newImage(name, width, height, kColorBlack)], def, FirstLayer)
