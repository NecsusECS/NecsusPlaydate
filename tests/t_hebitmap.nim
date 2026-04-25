import std/[unittest, importUtils], necsuspd/hebitmap, necsuspd/stubs/graphics, vmath

suite "bswap32":
  test "reverses byte order":
    check bswap32(0x12345678'u32) == 0x78563412'u32

  test "identity for zero":
    check bswap32(0x00000000'u32) == 0x00000000'u32

  test "identity for all ones":
    check bswap32(0xFFFFFFFF'u32) == 0xFFFFFFFF'u32

  test "single byte values":
    check bswap32(0xFF000000'u32) == 0x000000FF'u32
    check bswap32(0x000000FF'u32) == 0xFF000000'u32

suite "getBounds":
  test "full bounds when all pixels opaque (8x4, rowbytes=1)":
    var mask: seq[uint8] = @[0xFF'u8, 0xFF, 0xFF, 0xFF]
    let b = getBounds(mask, 1, 8, 4)
    check b == (ivec2(0, 0), ivec2(8, 4))

  test "empty mask returns zeros":
    var mask: seq[uint8] = @[0x00'u8, 0x00, 0x00, 0x00]
    let b = getBounds(mask, 1, 8, 4)
    check b == (ivec2(0, 0), ivec2(0, 0))

  test "single pixel at column 3, row 2 (8x4)":
    # rowbytes=1; pixel x=3 in row y=2 → byte[2], bit 7-3=4 → 0x10
    var mask = @[0x00'u8, 0x00, 0x10'u8, 0x00]
    let b = getBounds(mask, 1, 8, 4)
    check b == (ivec2(3, 2), ivec2(1, 1))

  test "partial rows trimmed (32x4, rowbytes=4)":
    # 32 wide image; only columns 8-15 in rows 1-2 are opaque
    var mask = newSeq[uint8](4 * 4)
    # row 1: byte index 1 (columns 8-15) = 0xFF
    mask[1 * 4 + 1] = 0xFF
    # row 2: byte index 1 (columns 8-15) = 0xFF
    mask[2 * 4 + 1] = 0xFF
    let b = getBounds(mask, 4, 32, 4)
    check b == (ivec2(8, 1), ivec2(8, 2))

suite "bufferAlign8_32":
  test "aligned copy: 8 pixels, all white":
    var src: seq[uint8] = @[0xFF'u8]
    var dst = newSeq[uint8](4)
    bufferAlign8_32(dst, 4, src, 1, ivec2(0, 0), ivec2(8, 1))
    check dst[0] == 0xFF
    check dst[1] == 0x00
    check dst[2] == 0x00
    check dst[3] == 0x00

  test "aligned copy: 8 pixels, alternating":
    var src: seq[uint8] = @[0xAA'u8]
    var dst = newSeq[uint8](4)
    bufferAlign8_32(dst, 4, src, 1, ivec2(0, 0), ivec2(8, 1))
    check dst[0] == 0xAA

  test "copies from offset column (x=3, w=5 from 8-wide src)":
    # src byte = 0b00011111 = 0x1F (bits 4-0 set, columns 3-7 white)
    var src: seq[uint8] = @[0x1F'u8]
    var dst = newSeq[uint8](4)
    bufferAlign8_32(dst, 4, src, 1, ivec2(3, 0), ivec2(5, 1))
    # dst bits 0-4 should be the 5 white pixels from src[3..7]
    # src col 3: bit 4 of 0x1F = 1 → dst bit 7 of byte 0
    # src col 4: bit 3 of 0x1F = 1 → dst bit 6 of byte 0
    # src col 5: bit 2 of 0x1F = 1 → dst bit 5 of byte 0
    # src col 6: bit 1 of 0x1F = 1 → dst bit 4 of byte 0
    # src col 7: bit 0 of 0x1F = 1 → dst bit 3 of byte 0
    check (dst[0] and 0xF8'u8) == 0xF8

  test "padding columns are zero":
    var src: seq[uint8] = @[0xFF'u8]
    var dst = newSeq[uint8](4)
    bufferAlign8_32(dst, 4, src, 1, ivec2(0, 0), ivec2(4, 1))
    # only 4 pixels copied, next 4 bits should be zero
    check dst[0] == 0xF0

suite "fromLCDBitmap":
  privateAccess(HEBitmap)
  test "all-white opaque 8x4 bitmap":
    let img = newImage("test", 8, 4, kColorWhite)
    let bmp = fromLCDBitmap(img)
    check bmp.size.x == 8
    check bmp.size.y == 4
    check bmp.boundsCoords.x == 0
    check bmp.boundsCoords.y == 0
    check bmp.boundsSize.x == 8
    check bmp.boundsSize.y == 4
    check bmp.rowbytes == 4
    # all white pixels → data bits all 1
    check bmp.data[0] == 0xFF
    check bmp.mask.len == 0

  test "all-black opaque 8x4 bitmap":
    let img = newImage("test", 8, 4, kColorBlack)
    let bmp = fromLCDBitmap(img)
    check bmp.data[0] == 0x00

  test "masked bitmap: single opaque pixel at (2,1) in 8x4":
    let img = newImage("img", 8, 4, kColorWhite)
    let mask = newImage("mask", 8, 4, kColorBlack)
    # kColorBlack in stubs = true = transparent → bit 0 in packed mask
    # To make pixel (2,1) opaque: set it to kColorWhite in mask
    # Wait: stub mask: true=transparent, false=opaque (kColorWhite)
    # newImage with kColorBlack → all true → all transparent
    # Set (2,1) to kColorWhite to make it opaque
    mask.set(2, 1, kColorWhite)
    img.setBitmapMask(mask)
    let bmp = fromLCDBitmap(img)
    check bmp.boundsCoords.x == 2
    check bmp.boundsCoords.y == 1
    check bmp.boundsSize.x == 1
    check bmp.boundsSize.y == 1
    check bmp.rowbytes == 4
    check bmp.mask.len == 4
    # The single opaque pixel → mask bit 0 of word = bit 7 of first byte = 0x80
    check bmp.mask[0] == 0x80
    # Source image is all white → data bit = 1
    check bmp.data[0] == 0x80

  test "rowbytes is always multiple of 4":
    for w in [1, 8, 16, 17, 32, 33]:
      let img = newImage("t", w, 1, kColorWhite)
      let bmp = fromLCDBitmap(img)
      check bmp.rowbytes == ((w + 31) div 32) * 4

suite "draw":
  setup:
    resetFrameBuffer()

  test "draws 8 white pixels at (0,0)":
    let img = newImage("t", 8, 1, kColorWhite)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(0, 0))
    let row = framebufferRow(0)
    check row[0 ..< 8] == "........"
    check row[8] == 'X'

  test "draws 8 white pixels at (4,0)":
    let img = newImage("t", 8, 1, kColorWhite)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(4, 0))
    let row = framebufferRow(0)
    check row[0 ..< 4] == "XXXX"
    check row[4 ..< 12] == "........"
    check row[12] == 'X'

  test "draws 8 black pixels at (0,0) - black overwrites black (no change)":
    let img = newImage("t", 8, 1, kColorBlack)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(0, 0))
    let row = framebufferRow(0)
    check row[0 ..< 8] == "XXXXXXXX"

  test "draws at correct row":
    let img = newImage("t", 8, 1, kColorWhite)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(0, 3))
    check framebufferRow(0)[0] == 'X'
    check framebufferRow(3)[0 ..< 8] == "........"

  test "clips when drawn partially off left edge":
    let img = newImage("t", 8, 1, kColorWhite)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(-4, 0))
    let row = framebufferRow(0)
    check row[0 ..< 4] == "...."
    check row[4] == 'X'

  test "does not draw when fully off screen":
    let img = newImage("t", 8, 1, kColorWhite)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(-8, 0))
    check framebufferRow(0)[0] == 'X'

  test "masked draw: only opaque pixels reach framebuffer":
    let img = newImage("img", 8, 1, kColorWhite)
    let mask = newImage("mask", 8, 1, kColorBlack)
    # Make pixels 0-3 opaque (kColorWhite = opaque in stubs)
    for x in 0 ..< 4:
      mask.set(x, 0, kColorWhite)
    img.setBitmapMask(mask)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(0, 0))
    let row = framebufferRow(0)
    check row[0 ..< 4] == "...."
    check row[4 ..< 8] == "XXXX"

  test "draws 32-pixel wide white bitmap at x=0":
    let img = newImage("t", 32, 1, kColorWhite)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(0, 0))
    let row = framebufferRow(0)
    check row[0 ..< 32] == "................................"
    check row[32] == 'X'

  test "draws 32-pixel wide white bitmap at x=16":
    let img = newImage("t", 32, 1, kColorWhite)
    let bmp = fromLCDBitmap(img)
    bmp.draw(ivec2(16, 0))
    let row = framebufferRow(0)
    check row[0 ..< 16] == "XXXXXXXXXXXXXXXX"
    check row[16 ..< 48] == "................................"
    check row[48] == 'X'
