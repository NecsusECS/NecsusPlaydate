import necsuspd/stubs/[sprites, graphics], necsuspd/sprite, necsuspd/anim

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
  sprite.newSheet(@[newImage(name, width, height, kColorBlack)], def, FirstLayer)

proc newDrawableAnim*(
    name: string, width, height: int, def: AnimationDef = newAnimationDef()
): (Drawable, Anim) =
  anim.newSheet(@[newImage(name, width, height, kColorBlack)], def, FirstLayer)

proc newDrawable*(name: string, width, height: int): Drawable =
  drawable.newBitmapDrawable(newImage(name, width, height, kColorBlack), FirstLayer, AnchorTopLeft)
