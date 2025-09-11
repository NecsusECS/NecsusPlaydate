import playdate/api, dither, math, sprite

type
  PrecalculatedFade* = ref object
    ## Precalculates a set of bitmap masks needed to fade out an image
    images: seq[LCDBitmap]

  FadeState* = distinct int

  GrayRectangle = object
    shade, width, height: int

const InitialFadeState* = FadeState(-1)

proc getPixel(rect: GrayRectangle, x, y: int): int =
  rect.shade

proc setPixel(bitmap: var BitmapDataObj, x, y, color: int) =
  if color < 128:
    bitmap.set(x, y, kColorBlack)

proc drawFade*(img: LCDBitmap, opacity: int) =
  var data = img.getDataObj()

  GrayRectangle(shade: opacity.clamp(0, 255), width: data.width, height: data.height).orderedDither(
    data, BlackAndWhiteIntPalette, Bayer4x4
  )

proc createFadePrecalculation*(
    baseMask: LCDBitmap, size: int, minOpacity: int = 0, maxOpacity: int = 255
): PrecalculatedFade =
  result = PrecalculatedFade(images: newSeq[LCDBitmap](size))
  for i in 0 ..< size:
    let gray =
      if i == 0:
        minOpacity
      elif i == (size - 1):
        maxOpacity
      else:
        minOpacity + (i * (maxOpacity - minOpacity) div (size - 1))
    # let gray = i * 255 div (size - 1)
    result.images[i] = baseMask.copy
    result.images[i].drawFade(gray)

proc full*(fade: PrecalculatedFade, sprite: Sprite) =
  discard sprite.getImage.setBitmapMask(fade.images[fade.images.len - 1])
  sprite.markDirty

proc draw*(
    fade: PrecalculatedFade, sprite: Sprite, existingValue: ptr FadeState, t: float32
) =
  let newIndex = round((fade.images.len - 1).float32 * t.clamp(0.0, 1.0)).toInt
  if existingValue.read.int != newIndex:
    existingValue[] = FadeState(newIndex)
    discard sprite.getImage.setBitmapMask(fade.images[newIndex])
    sprite.markDirty
