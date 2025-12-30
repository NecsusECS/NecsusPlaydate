import playdate/api, std/[importutils, bitops], sprite

template eachBitInRow(
    bitmap: var BitmapData | BitmapDataObj, rowWords: int32, exec: untyped
) =
  ## Utility template used by `setMany` that handles iteration over the words in a row of pixels
  privateAccess(BitmapData)
  for relativeWordId in 0 ..< rowWords:
    # The index of the word within the final image
    let wordId = (y * bitmap.rowbytes) + relativeWordId

    # The actual bits in the word
    var word {.inject.} = bitmap.data[wordId]

    for relX in 0 ..< 8:
      let x {.inject.} = (relativeWordId * 8) + relX

      # The coordinate of the bit to manipulate within the word
      let bitId {.inject.} = 7 - relX

      exec

    bitmap.data[wordId] = word

proc setMany[W: static int32](
    image: var BitmapData | BitmapDataObj,
    mask: var BitmapData | BitmapDataObj,
    setMask: static bool,
    pixels: openarray[array[W, LCDSolidColor]],
) =
  ## Bulk sets an array of pixels. This is faster than individual pixel setting because it allows all the bounds
  ## checks to be done once.

  static:
    assert(W mod 8 == 0, "Pixel width must be divisible by 8, but was " & $W)

  # The number of 8 bit words in each row
  let rowWords = min(image.width.int32 + 7, W) div 8

  for y in 0 ..< min(image.height, pixels.len):
    image.eachBitInRow(rowWords):
      case pixels[y][x]
      of kColorBlack:
        word.clearBit(bitId)
      of kColorWhite:
        word.setBit(bitId)
      of kColorClear:
        discard
      of kColorXOR:
        word.flipBit(bitId)

    if setMask:
      mask.eachBitInRow(rowWords):
        case pixels[y][x]
        of kColorBlack, kColorWhite, kColorXOR:
          word.setBit(bitId)
        of kColorClear:
          word.clearBit(bitId)

proc setMany*[W: static int32](
    image: var BitmapData,
    mask: var BitmapData,
    pixels: openarray[array[W, LCDSolidColor]],
) =
  ## Bulk sets an array of pixels. This is faster than individual pixel setting because it allows all the bounds
  ## checks to be done once.
  if mask == nil:
    setMany(image, mask, false, pixels)
  else:
    setMany(image, mask, true, pixels)

proc setMany*[W: static int32](
    this: var LCDBitmap,
    pixels: openarray[array[W, LCDSolidColor]],
    skipBitmask: static bool = false,
) =
  ## Bulk sets an array of pixels. This is faster than individual pixel setting because it allows all the bounds
  ## checks to be done once.
  privateAccess(LCDBitmap)

  let data = this.getDataObj()

  if skipBitmask or this.getBitmapMask.isNil or this.getBitmapMask.resource.isNil:
    setMany(data, default(BitmapDataObj), false, pixels)
  else:
    var maskData = this.getBitmapMask.getDataObj()
    setMany(data, maskData, true, pixels)

template drawContext*(img: LCDBitmap, exec: untyped) =
  assert(img != nil)
  playdate.graphics.pushContext(img)
  try:
    exec
  finally:
    playdate.graphics.popContext()

template drawContext*(sprite: Sprite | ptr Sprite, exec: untyped) =
  sprite.markDirty()
  sprite.getImage.drawContext:
    exec

proc copyTo*(source, target: BitmapDataObj) =
  privateAccess(BitmapDataObj)
  assert(source.data != nil)
  assert(target.data != nil)

  let minRowLen = min(source.rowbytes, target.rowbytes)

  for y in 0 ..< min(source.height, target.height):
    for i in 0 ..< minRowLen:
      target.data[i + (y * target.rowbytes)] = source.data[i + (y * source.rowbytes)]

proc copyTo*(source: LCDBitmap, target: LCDBitmap) =
  source.getDataObj.copyTo(target.getDataObj)

  let srcMask = source.getBitmapMask
  let tgtMask = target.getBitmapMask
  if not srcMask.isNil and not tgtMask.isNil:
    copyTo(srcMask.getDataObj, tgtMask.getDataObj)

proc makePattern*(pattern: varargs[array[8, LCDSolidColor]]): LCDPattern =
  ## Creates a pattern from an array of colors.
  var clrs: array[8, uint8]
  var trnsp = [7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8, 7u8]
  for i, row in pattern:
    if i >= 8:
      break
    for j, color in row:
      case color
      of kColorWhite:
        clrs[i].setBit(7'u8 - j.uint8)
      of kColorBlack:
        discard
      of kColorClear, kColorXor:
        trnsp[i].clearBit(7'u8 - j.uint8)
  return makeLCDPattern(
    clrs[0],
    clrs[1],
    clrs[2],
    clrs[3],
    clrs[4],
    clrs[5],
    clrs[6],
    clrs[7],
    trnsp[0],
    trnsp[1],
    trnsp[2],
    trnsp[3],
    trnsp[4],
    trnsp[5],
    trnsp[6],
    trnsp[7],
  )
