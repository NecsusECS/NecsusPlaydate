import import_playdate, std/bitops, std/importutils, vmath

const LCD_ROWSIZE* = 52'i32

type HEBitmap* = object
  data, mask: seq[uint8]
  rowbytes: int32
  boundsCoords, boundsSize, size: IVec2

proc size*(he: HEBitmap): IVec2 {.inline.} =
  he.size

proc bswap32*(n: uint32): uint32 {.importc: "__builtin_bswap32", nodecl, noSideEffect.}

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
  cast[ptr uint8](cast[int](p) + n.int)

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
  let dataSize: int32 = result.rowbytes * result.boundsSize.y
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
  let srcLen = int32(bitmapData.rowbytes) * int32(bitmapData.height)
  let srcPtr = cast[ptr UncheckedArray[uint8]](bitmapData.data)
  let maskBmp = src.getBitmapMask()
  if not maskBmp.isNil:
    var maskData = maskBmp.getDataObj()
    let maskLen = int32(maskData.rowbytes) * int32(maskData.height)
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
      result,
      toOpenArray(srcPtr, 0, srcLen - 1),
      int32(bitmapData.rowbytes),
      [],
      0'i32,
      false,
    )

template writePixelWord(framePtr, data, len: untyped) =
  if len < 32:
    data = clipRight(bswap32(framePtr[]), data, len)
  framePtr[] = bswap32(data)
  framePtr = advance(framePtr, 1)
  len -= 32

template drawLoop(
    frameStartArg, dataStartArg, maskStartArg: untyped,
    hasMask: static bool,
    body: untyped,
) =
  var frameStart = frameStartArg
  var dataStart = dataStartArg
  var maskStart = maskStartArg
  for _ in y1 ..< y2:
    var framePtr {.inject.} = cast[ptr uint32](frameStart)
    var dataPtr {.inject.} = cast[ptr uint32](dataStart)
    var maskPtr {.inject.}: ptr uint32 =
      when hasMask:
        cast[ptr uint32](maskStart)
      else:
        nil
    body
    frameStart = advanceU8(frameStart, LCD_ROWSIZE)
    dataStart = advanceU8(dataStart, rowbytes)
    when hasMask:
      maskStart = advanceU8(maskStart, rowbytes)

proc drawRowsRightShift(
    frameStartArg, dataStartArg, maskStartArg: ptr uint8,
    y1, y2, x1, x2: int32,
    shift, ogShiftMask: uint32,
    rowbytes: int32,
    hasMask: static bool,
) =
  drawLoop(frameStartArg, dataStartArg, maskStartArg, hasMask):
    var dataLeft = bswap32(framePtr[])
    var maskLeft = 0'u32
    var shiftMask = not shr32(0xFFFFFFFF'u32, cast[uint32](x1 mod 32))
    var len = x2 - x1 div 32 * 32

    while len > 0:
      let curData = bswap32(dataPtr[])
      let dataRight = shr32(curData, shift)
      var data = combineWords(dataLeft, dataRight, shiftMask)

      when hasMask:
        let curMask = bswap32(maskPtr[])
        let maskRight = shr32(curMask, shift)
        let mask = combineWords(maskLeft, maskRight, shiftMask)
        data = applyMask(bswap32(framePtr[]), data, mask)

      dataLeft = shl32(curData, 32'u32 - shift)
      when hasMask:
        maskLeft = shl32(curMask, 32'u32 - shift)
        maskPtr = advance(maskPtr, 1)

      dataPtr = advance(dataPtr, 1)
      writePixelWord(framePtr, data, len)
      shiftMask = ogShiftMask

proc drawRowsLeftShift(
    frameStartArg, dataStartArg, maskStartArg: ptr uint8,
    y1, y2, x1, x2: int32,
    shift, shiftMaskBase: uint32,
    rowbytes: int32,
    hasMask: static bool,
) =
  drawLoop(frameStartArg, dataStartArg, maskStartArg, hasMask):
    var dataLeft = shl32(bswap32(dataPtr[]), shift)
    var maskLeft =
      when hasMask:
        shl32(bswap32(maskPtr[]), shift)
      else:
        0'u32
    var clipLeftMask = not shr32(0xFFFFFFFF'u32, cast[uint32](x1 mod 32))
    var len = x2 - x1 div 32 * 32

    while len > 0:
      let fetchNext = (len + cast[int32](shift)) > 32
      var curData: uint32
      let dataRight: uint32 =
        if fetchNext:
          dataPtr = advance(dataPtr, 1)
          curData = bswap32(dataPtr[])
          shr32(curData, 32'u32 - shift)
        else:
          curData = bswap32(dataPtr[])
          bswap32(framePtr[])

      var data = combineWords(dataLeft, dataRight, shiftMaskBase)

      when hasMask:
        var curMask: uint32
        let maskRight: uint32 =
          if fetchNext:
            maskPtr = advance(maskPtr, 1)
            curMask = bswap32(maskPtr[])
            shr32(curMask, 32'u32 - shift)
          else:
            curMask = bswap32(maskPtr[])
            0'u32
        let mask = combineWords(maskLeft, maskRight, shiftMaskBase)
        data = applyMask(bswap32(framePtr[]), data, mask)

      if clipLeftMask != 0:
        data = (bswap32(framePtr[]) and clipLeftMask) or (data and not clipLeftMask)
        clipLeftMask = 0'u32

      dataLeft = shl32(curData, shift)
      when hasMask:
        maskLeft = shl32(curMask, shift)

      writePixelWord(framePtr, data, len)

proc draw*(bmp: HEBitmap, pos: IVec2, flipY: bool = false) =
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

  let numRows = y2 - y1
  let startRow =
    if flipY:
      offsetTop + numRows - 1
    else:
      offsetTop
  let rowStep =
    if flipY:
      -bmp.rowbytes
    else:
      bmp.rowbytes

  if (x1 div 32 * 32) <= drawPos.x:
    let shift = cast[uint32](drawPos.x mod 32)
    let ogShiftMask = not shr32(0xFFFFFFFF'u32, shift)
    let dataOffset = startRow * bmp.rowbytes
    let dataStart = cast[ptr uint8](addr bmp.data[dataOffset])
    if hasMask:
      drawRowsRightShift(
        frameStart,
        dataStart,
        cast[ptr uint8](addr bmp.mask[dataOffset]),
        y1,
        y2,
        x1,
        x2,
        shift,
        ogShiftMask,
        rowStep,
        true,
      )
    else:
      drawRowsRightShift(
        frameStart, dataStart, nil, y1, y2, x1, x2, shift, ogShiftMask, rowStep, false
      )
  else:
    var shift = cast[uint32](abs(drawPos.x) mod 32)
    if drawPos.x >= 0 and shift > 0:
      shift = 32'u32 - shift
    let shiftMaskBase = shl32(0xFFFFFFFF'u32, shift)
    let offset32 = x1 div 32 * 32 - drawPos.x
    let dataOffset = startRow * bmp.rowbytes + (offset32 div 32) * 4
    let dataStart = cast[ptr uint8](addr bmp.data[dataOffset])
    if hasMask:
      drawRowsLeftShift(
        frameStart,
        dataStart,
        cast[ptr uint8](addr bmp.mask[dataOffset]),
        y1,
        y2,
        x1,
        x2,
        shift,
        shiftMaskBase,
        rowStep,
        true,
      )
    else:
      drawRowsLeftShift(
        frameStart, dataStart, nil, y1, y2, x1, x2, shift, shiftMaskBase, rowStep, false
      )

  playdate.graphics.markUpdatedRows(y1, y2 - 1)

const HEBitmapMagic = 0x48454249'i32 # "HEBI"
const HEBitmapHeaderSize = 40

proc toBytes*(bmp: HEBitmap): seq[byte] =
  let dataLen = int32(bmp.data.len)
  let maskLen = int32(bmp.mask.len)
  result = newSeq[byte](HEBitmapHeaderSize + dataLen + maskLen)
  var magic = HEBitmapMagic
  copyMem(addr result[0],  addr magic,               4)
  copyMem(addr result[4],  addr bmp.size.x,          4)
  copyMem(addr result[8],  addr bmp.size.y,          4)
  copyMem(addr result[12], addr bmp.boundsCoords.x,  4)
  copyMem(addr result[16], addr bmp.boundsCoords.y,  4)
  copyMem(addr result[20], addr bmp.boundsSize.x,    4)
  copyMem(addr result[24], addr bmp.boundsSize.y,    4)
  copyMem(addr result[28], addr bmp.rowbytes,        4)
  copyMem(addr result[32], addr dataLen,             4)
  copyMem(addr result[36], addr maskLen,             4)
  if dataLen > 0:
    copyMem(addr result[HEBitmapHeaderSize], addr bmp.data[0], dataLen)
  if maskLen > 0:
    copyMem(addr result[HEBitmapHeaderSize + dataLen], addr bmp.mask[0], maskLen)

proc fromBytes*(bytes: openArray[byte]): HEBitmap {.raises: [ValueError].} =
  if bytes.len < HEBitmapHeaderSize:
    raise newException(ValueError, "buffer too small for HEBitmap header")
  var magic, sizeX, sizeY, bcX, bcY, bsX, bsY, rowbytes, dataLen, maskLen: int32
  copyMem(addr magic,    addr bytes[0],  4)
  copyMem(addr sizeX,    addr bytes[4],  4)
  copyMem(addr sizeY,    addr bytes[8],  4)
  copyMem(addr bcX,      addr bytes[12], 4)
  copyMem(addr bcY,      addr bytes[16], 4)
  copyMem(addr bsX,      addr bytes[20], 4)
  copyMem(addr bsY,      addr bytes[24], 4)
  copyMem(addr rowbytes, addr bytes[28], 4)
  copyMem(addr dataLen,  addr bytes[32], 4)
  copyMem(addr maskLen,  addr bytes[36], 4)
  if magic != HEBitmapMagic:
    raise newException(ValueError, "invalid HEBitmap magic")
  if dataLen < 0 or maskLen < 0:
    raise newException(ValueError, "invalid HEBitmap data lengths")
  if bytes.len < HEBitmapHeaderSize + dataLen + maskLen:
    raise newException(ValueError, "buffer too small for HEBitmap data")
  result.size = ivec2(sizeX, sizeY)
  result.boundsCoords = ivec2(bcX, bcY)
  result.boundsSize = ivec2(bsX, bsY)
  result.rowbytes = rowbytes
  result.data = newSeq[uint8](dataLen)
  if dataLen > 0:
    copyMem(addr result.data[0], addr bytes[HEBitmapHeaderSize], dataLen)
  result.mask = newSeq[uint8](maskLen)
  if maskLen > 0:
    copyMem(addr result.mask[0], addr bytes[HEBitmapHeaderSize + dataLen], maskLen)

const HEBitmapSeqMagic = 0x48454253'i32 # "HEBS"
const HEBitmapSeqHeaderSize = 8 # magic + count

proc toBytes*(bitmaps: ref seq[HEBitmap]): seq[byte] =
  let count = int32(bitmaps[].len)
  var chunks = newSeq[seq[byte]](count)
  var totalLen = HEBitmapSeqHeaderSize + count.int * 4
  for i in 0 ..< count:
    chunks[i] = bitmaps[i].toBytes()
    totalLen += chunks[i].len
  result = newSeq[byte](totalLen)
  var magic = HEBitmapSeqMagic
  copyMem(addr result[0], addr magic, 4)
  copyMem(addr result[4], addr count, 4)
  var pos = HEBitmapSeqHeaderSize
  for chunk in chunks:
    var chunkLen = int32(chunk.len)
    copyMem(addr result[pos], addr chunkLen, 4)
    pos += 4
    if chunkLen > 0:
      copyMem(addr result[pos], addr chunk[0], chunkLen)
      pos += chunkLen

proc seqFromBytes*(bytes: openArray[byte]): ref seq[HEBitmap] {.raises: [ValueError].} =
  if bytes.len < HEBitmapSeqHeaderSize:
    raise newException(ValueError, "buffer too small for HEBitmap seq header")
  var magic, count: int32
  copyMem(addr magic, addr bytes[0], 4)
  copyMem(addr count, addr bytes[4], 4)
  if magic != HEBitmapSeqMagic:
    raise newException(ValueError, "invalid HEBitmap seq magic")
  if count < 0:
    raise newException(ValueError, "invalid HEBitmap seq count")
  result = new(seq[HEBitmap])
  result[] = newSeq[HEBitmap](count)
  var pos = HEBitmapSeqHeaderSize
  for i in 0 ..< count:
    if pos + 4 > bytes.len:
      raise newException(ValueError, "buffer truncated reading HEBitmap seq entry")
    var chunkLen: int32
    copyMem(addr chunkLen, addr bytes[pos], 4)
    pos += 4
    if chunkLen < 0 or pos + chunkLen > bytes.len:
      raise newException(ValueError, "invalid HEBitmap seq entry length")
    result[i] = fromBytes(toOpenArray(bytes, pos, pos + chunkLen - 1))
    pos += chunkLen
