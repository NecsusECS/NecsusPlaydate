import import_playdate, std/bitops, std/importutils, vmath

const LCD_ROWSIZE* = 52

type HEBitmap* = object
  data, mask: seq[uint8]
  rowbytes: int32
  boundsCoords, boundsSize, size: IVec2

proc size*(he: HEBitmap): IVec2 {.inline.} =
  he.size

proc bswap32*(n: uint32): uint32 {.inline.} =
  (n shr 24) or ((n shr 8) and 0xFF00'u32) or ((n shl 8) and 0xFF0000'u32) or (n shl 24)

proc shl32(n: uint32, s: uint32): uint32 {.inline.} =
  if s >= 32:
    0'u32
  else:
    n shl s

proc shr32(n: uint32, s: uint32): uint32 {.inline.} =
  if s >= 32:
    0'u32
  else:
    n shr s

proc advance(p: ptr uint32, n: int32): ptr uint32 {.inline.} =
  cast[ptr uint32](cast[uint](p) + cast[uint](n * 4))

proc advanceU8(p: ptr uint8, n: int32): ptr uint8 {.inline.} =
  cast[ptr uint8](cast[uint](p) + cast[uint](n))

proc getBit(src: openArray[uint8], byteIdx, bitIdx: int32): bool {.inline.} =
  testBit(src[byteIdx], BitsRange[uint8](7 - bitIdx))

proc setBit(dst: var seq[uint8], byteIdx, bitIdx: int32) {.inline.} =
  setBit(dst[byteIdx], BitsRange[uint8](7 - bitIdx))

proc clearBit(dst: var seq[uint8], byteIdx, bitIdx: int32) {.inline.} =
  clearBit(dst[byteIdx], BitsRange[uint8](7 - bitIdx))

proc combineWords(left, right, shiftMask: uint32): uint32 {.inline.} =
  (left and shiftMask) or (right and not shiftMask)

proc applyMask(frame, data, mask: uint32): uint32 {.inline.} =
  (frame and not mask) or (data and mask)

proc clipRight(frame, data: uint32, len: int32): uint32 {.inline.} =
  let clip = shl32(0xFFFFFFFF'u32, cast[uint32](32 - len))
  (data and clip) or (frame and not clip)

proc getBounds*(
    mask: openArray[uint8], rowbytes, width, height: int32
): tuple[coords, size: IVec2] =
  var minX = width
  var minY = height
  var maxX: int32 = 0
  var maxY: int32 = 0
  for y in 0 ..< height:
    for x in 0 ..< width:
      if getBit(mask, y * rowbytes + x div 8, x mod 8):
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x + 1)
        maxY = max(maxY, y + 1)
  if maxX == 0 and maxY == 0:
    return (ivec2(0, 0), ivec2(0, 0))
  return (ivec2(minX, minY), ivec2(maxX - minX, maxY - minY))

proc bufferAlign8_32*(
    dst: var seq[uint8],
    dstRowbytes: int32,
    src: openArray[uint8],
    srcRowbytes: int32,
    origin, size: IVec2,
) =
  let alignedWidth = dstRowbytes * 8
  for dstY in 0 ..< size.y:
    for dstX in 0 ..< alignedWidth:
      let dstByteIdx = dstY * dstRowbytes + dstX div 8
      let dstBitIdx = dstX mod 8
      if dstX < size.x:
        let srcX = origin.x + dstX
        let srcY = origin.y + dstY
        if getBit(src, srcY * srcRowbytes + srcX div 8, srcX mod 8):
          setBit(dst, dstByteIdx, dstBitIdx)
        else:
          clearBit(dst, dstByteIdx, dstBitIdx)
      else:
        clearBit(dst, dstByteIdx, dstBitIdx)

proc buildHEBitmap(
    result: var HEBitmap,
    srcPixels: openArray[uint8],
    srcRowbytes: int32,
    maskPixels: openArray[uint8],
    maskRowbytes: int32,
    hasMask: bool,
) =
  if hasMask:
    let b = getBounds(maskPixels, maskRowbytes, result.size.x, result.size.y)
    result.boundsCoords = b.coords
    result.boundsSize = b.size
  else:
    result.boundsCoords = ivec2(0, 0)
    result.boundsSize = result.size
  result.rowbytes = ((result.boundsSize.x + 31) div 32) * 4
  let dataSize = int(result.rowbytes * result.boundsSize.y)
  result.data = newSeq[uint8](dataSize)
  bufferAlign8_32(
    result.data, result.rowbytes, srcPixels, srcRowbytes, result.boundsCoords,
    result.boundsSize,
  )
  if hasMask:
    result.mask = newSeq[uint8](dataSize)
    bufferAlign8_32(
      result.mask, result.rowbytes, maskPixels, maskRowbytes, result.boundsCoords,
      result.boundsSize,
    )

proc fromLCDBitmap*(src: LCDBitmap): HEBitmap =
  assert(not src.isNil, "fromLCDBitmap called with nil LCDBitmap")
  result.size.x = int32(src.width)
  result.size.y = int32(src.height)
  privateAccess(PlaydateGraphics)
  var bitmapData = src.getDataObj()
  let srcLen = bitmapData.rowbytes * bitmapData.height
  let srcPtr = cast[ptr UncheckedArray[uint8]](bitmapData.data)
  let maskBmp = src.getBitmapMask()
  if not maskBmp.isNil:
    var maskData = maskBmp.getDataObj()
    let maskLen = maskData.rowbytes * maskData.height
    let maskPtr = cast[ptr UncheckedArray[uint8]](maskData.data)
    buildHEBitmap(
      result,
      toOpenArray(srcPtr, 0, srcLen - 1),
      int32(bitmapData.rowbytes),
      toOpenArray(maskPtr, 0, maskLen - 1),
      int32(maskData.rowbytes),
      true,
    )
  else:
    buildHEBitmap(
      result, toOpenArray(srcPtr, 0, srcLen - 1), int32(bitmapData.rowbytes), [], 0, false
    )

proc drawRowsRightShift(
    frameStartArg, dataStartArg, maskStartArg: ptr uint8,
    y1, y2, x1, x2: int32,
    shift, ogShiftMask: uint32,
    rowbytes: int32,
    hasMask: bool,
) =
  var frameStart = frameStartArg
  var dataStart = dataStartArg
  var maskStart = maskStartArg
  for _ in y1 ..< y2:
    var framePtr = cast[ptr uint32](frameStart)
    var dataPtr = cast[ptr uint32](dataStart)
    var maskPtr =
      if hasMask:
        cast[ptr uint32](maskStart)
      else:
        nil

    var dataLeft = bswap32(framePtr[])
    var maskLeft = 0'u32
    var shiftMask = not shr32(0xFFFFFFFF'u32, cast[uint32](x1 mod 32))
    var len = x2 - x1 div 32 * 32

    while len > 0:
      let dataRight = shr32(bswap32(dataPtr[]), shift)
      var data = combineWords(dataLeft, dataRight, shiftMask)

      if hasMask:
        let maskRight = shr32(bswap32(maskPtr[]), shift)
        let mask = combineWords(maskLeft, maskRight, shiftMask)
        data = applyMask(bswap32(framePtr[]), data, mask)

      if len < 32:
        data = clipRight(bswap32(framePtr[]), data, len)

      framePtr[] = bswap32(data)

      dataLeft = shl32(bswap32(dataPtr[]), 32'u32 - shift)
      if hasMask:
        maskLeft = shl32(bswap32(maskPtr[]), 32'u32 - shift)
        maskPtr = advance(maskPtr, 1)

      dataPtr = advance(dataPtr, 1)
      framePtr = advance(framePtr, 1)
      shiftMask = ogShiftMask
      len -= 32

    frameStart = advanceU8(frameStart, LCD_ROWSIZE)
    dataStart = advanceU8(dataStart, rowbytes)
    if hasMask:
      maskStart = advanceU8(maskStart, rowbytes)

proc drawRowsLeftShift(
    frameStartArg, dataStartArg, maskStartArg: ptr uint8,
    y1, y2, x1, x2: int32,
    shift, shiftMaskBase: uint32,
    rowbytes: int32,
    hasMask: bool,
) =
  var frameStart = frameStartArg
  var dataStart = dataStartArg
  var maskStart = maskStartArg
  for _ in y1 ..< y2:
    var framePtr = cast[ptr uint32](frameStart)
    var dataPtr = cast[ptr uint32](dataStart)
    var maskPtr =
      if hasMask:
        cast[ptr uint32](maskStart)
      else:
        nil

    var dataLeft = shl32(bswap32(dataPtr[]), shift)
    var maskLeft =
      if hasMask:
        shl32(bswap32(maskPtr[]), shift)
      else:
        0'u32
    var clipLeftMask = not shr32(0xFFFFFFFF'u32, cast[uint32](x1 mod 32))
    var len = x2 - x1 div 32 * 32

    while len > 0:
      let dataRight: uint32 =
        if (len + cast[int32](shift)) > 32:
          dataPtr = advance(dataPtr, 1)
          shr32(bswap32(dataPtr[]), 32'u32 - shift)
        else:
          bswap32(framePtr[])

      var data = combineWords(dataLeft, dataRight, shiftMaskBase)

      if hasMask:
        let maskRight: uint32 =
          if (len + cast[int32](shift)) > 32:
            maskPtr = advance(maskPtr, 1)
            shr32(bswap32(maskPtr[]), 32'u32 - shift)
          else:
            0'u32
        let mask = combineWords(maskLeft, maskRight, shiftMaskBase)
        data = applyMask(bswap32(framePtr[]), data, mask)

      if clipLeftMask != 0:
        data = (bswap32(framePtr[]) and clipLeftMask) or (data and not clipLeftMask)
        clipLeftMask = 0'u32

      if len < 32:
        data = clipRight(bswap32(framePtr[]), data, len)

      framePtr[] = bswap32(data)
      framePtr = advance(framePtr, 1)

      dataLeft = shl32(bswap32(dataPtr[]), shift)
      if hasMask:
        maskLeft = shl32(bswap32(maskPtr[]), shift)

      len -= 32

    frameStart = advanceU8(frameStart, LCD_ROWSIZE)
    dataStart = advanceU8(dataStart, rowbytes)
    if hasMask:
      maskStart = advanceU8(maskStart, rowbytes)

proc draw*(bmp: HEBitmap, pos: IVec2) =
  let drawPos = pos + bmp.boundsCoords

  let x1 = max(drawPos.x, 0'i32)
  let y1 = max(drawPos.y, 0'i32)
  let x2 = min(drawPos.x + bmp.boundsSize.x, int32(LCD_COLUMNS))
  let y2 = min(drawPos.y + bmp.boundsSize.y, int32(LCD_ROWS))
  let offsetTop = y1 - drawPos.y

  if x1 >= x2 or y1 >= y2:
    return

  let framebuf = cast[ptr uint8](playdate.graphics.getFrame())

  let frameStart = advanceU8(framebuf, y1 * LCD_ROWSIZE + (x1 div 32) * 4)
  let hasMask = bmp.mask.len > 0

  if (x1 div 32 * 32) <= drawPos.x:
    let shift = cast[uint32](drawPos.x mod 32)
    let ogShiftMask = not shr32(0xFFFFFFFF'u32, shift)
    let dataOffset = offsetTop * bmp.rowbytes
    let dataStart = cast[ptr uint8](unsafeAddr bmp.data[dataOffset])
    let maskStart =
      if hasMask:
        cast[ptr uint8](unsafeAddr bmp.mask[dataOffset])
      else:
        nil
    drawRowsRightShift(
      frameStart, dataStart, maskStart, y1, y2, x1, x2, shift, ogShiftMask,
      bmp.rowbytes, hasMask,
    )
  else:
    var shift = cast[uint32](abs(drawPos.x) mod 32)
    if drawPos.x >= 0 and shift > 0:
      shift = 32'u32 - shift
    let shiftMaskBase = shl32(0xFFFFFFFF'u32, shift)
    let offset32 = x1 div 32 * 32 - drawPos.x
    let dataOffset = offsetTop * bmp.rowbytes + (offset32 div 32) * 4
    let dataStart = cast[ptr uint8](unsafeAddr bmp.data[dataOffset])
    let maskStart =
      if hasMask:
        cast[ptr uint8](unsafeAddr bmp.mask[dataOffset])
      else:
        nil
    drawRowsLeftShift(
      frameStart, dataStart, maskStart, y1, y2, x1, x2, shift, shiftMaskBase,
      bmp.rowbytes, hasMask,
    )

  playdate.graphics.markUpdatedRows(y1, y2 - 1)
