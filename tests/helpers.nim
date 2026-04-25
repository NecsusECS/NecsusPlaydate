import necsuspd/stubs/[sprites, graphics], necsuspd/anim
export anim

type
  TestZIndex* = enum
    FirstLayer

  TestAnimSheet* = enum
    SampleSheet

proc newAnimationDef*(id: int = 0): AnimationDef =
  return animation(SampleSheet, 0.1'f32, 0'i32 .. 0'i32, AnchorTopLeft)

proc newDrawableAnim*(
    name: string, width, height: int, def: AnimationDef = newAnimationDef()
): (Drawable, Anim) =
  newSheet(@[newImage(name, width, height, kColorBlack)], def, FirstLayer)

proc newDrawable*(name: string, width, height: int): Drawable =
  newBitmapDrawable(
    newImage(name, width, height, kColorBlack), FirstLayer, AnchorTopLeft
  )
