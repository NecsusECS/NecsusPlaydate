import graphics

type
  LCDSprite* = ref object
    img: LCDBitmap
    hidden*: bool

  PlaydateSprites* = ref object

  PDRect* = object
    x*, y*, width*, height*: float

proc newSprite*(_: PlaydateSprites): LCDSprite =
  LCDSprite()

proc getImage*(sprite: LCDSprite): LCDBitmap =
  sprite.img

proc setImage*(sprite: LCDSprite, img: LCDBitmap, flip: LCDBitmapFlip) =
  sprite.img = img

proc setOpaque*(sprite: LCDSprite, value: bool) =
  discard

proc width*(this: LCDSprite): auto =
  this.img.width

proc height*(this: LCDSprite): auto =
  this.img.height

proc visible*(value: LCDSprite): bool =
  not value.hidden

proc `visible=`*(value: LCDSprite, flag: bool) =
  value.hidden = not flag

proc remove*(value: LCDSprite) =
  discard

proc add*(value: LCDSprite) =
  discard

proc removeSprites*(_: PlaydateSprites, sprites: openarray[LCDSprite]) =
  discard

proc drawSprites*(_: PlaydateSprites) =
  discard

proc zIndex*(value: LCDSprite): int16 =
  discard

proc `zIndex=`*(this: LCDSprite, zIndex: int16) =
  discard

proc moveTo*(this: LCDSprite, x, y: float) =
  discard

proc `collideRect=`*(this: LCDSprite, rect: PDRect) =
  discard

proc setDrawMode*(this: LCDSprite, mode: LCDBitmapDrawMode) =
  discard

proc bounds*(this: LCDSprite): PDRect =
  discard

proc markDirty*(this: LCDSprite) =
  discard
