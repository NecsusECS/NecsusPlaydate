import std/[os, strutils, parseopt, options], pixie, necsuspd/hebitmap

proc parseTableSuffix(base: string): Option[tuple[basename: string, w, h: int]] =
  let marker = "-table-"
  let idx = base.rfind(marker)
  if idx >= 0:
    let parts = base[idx + marker.len .. ^1].split('-')
    if parts.len == 2:
      try:
        return some((base[0 ..< idx], parseInt(parts[0]), parseInt(parts[1])))
      except ValueError:
        discard

proc imageToHEBitmap(img: Image): HEBitmap =
  let w = img.width
  let h = img.height
  let rowbytes = (w + 7) div 8
  var pixels = newSeq[uint8](rowbytes * h)
  var maskSeq = newSeq[uint8](rowbytes * h)
  var hasMask = false
  for y in 0 ..< h:
    for x in 0 ..< w:
      let c = img[x, y]
      let byteIdx = y * rowbytes + x div 8
      let bit = 1'u8 shl (7 - (x mod 8))
      if (c.r.int + c.g.int + c.b.int) div 3 >= 128:
        pixels[byteIdx] = pixels[byteIdx] or bit
      if c.a >= 128:
        maskSeq[byteIdx] = maskSeq[byteIdx] or bit
      else:
        hasMask = true
  result = newHEBitmap(
    int32(w), int32(h), pixels, int32(rowbytes), maskSeq, int32(rowbytes), hasMask
  )

proc sliceSheet(img: Image, fw, fh: int): ref seq[HEBitmap] =
  result = new(seq[HEBitmap])
  for row in 0 ..< img.height div fh:
    for col in 0 ..< img.width div fw:
      result[].add(imageToHEBitmap(img.subImage(col * fw, row * fh, fw, fh)))

proc parseArgs(): tuple[outDir, pngPath: string] =
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdLongOption:
      if p.key == "out":
        result.outDir = p.val
    of cmdShortOption:
      discard
    of cmdArgument:
      result.pngPath = p.key

  if result.pngPath == "":
    stderr.writeLine("Usage: create_hebmp [--out:<dir>] <image.png>")
    quit(1)
  if not result.pngPath.fileExists():
    stderr.writeLine("File not found: " & result.pngPath)
    quit(1)

proc main() =
  let (outDir, pngPath) = parseArgs()
  let (fileDir, name, _) = splitFile(pngPath)
  let targetDir = if outDir == "": fileDir else: outDir
  let img = readImage(pngPath)
  let suffix = parseTableSuffix(name)
  if suffix.isSome:
    let frames = sliceSheet(img, suffix.get().w, suffix.get().h)
    let outPath = targetDir / suffix.get().basename & ".hebs"
    writeFile(outPath, frames.toBytes())
    echo "Wrote " & outPath & " (" & $frames[].len & " frames)"
  else:
    let outPath = targetDir / name & ".hebi"
    writeFile(outPath, imageToHEBitmap(img).toBytes())
    echo "Wrote " & outPath

main()
