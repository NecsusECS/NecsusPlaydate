import std/[tables, sequtils, streams], graphics, sprites, sounds

export graphics, sprites, sounds

type
  PlaydateApi* = ref object
    file*: PlaydateFiles
    system*: PlaydateSystem
    graphics*: PlaydateGraphics
    sprite*: PlaydateSprites
    sound*: PlaydateSounds

  PlaydateFiles* = ref object

  PlaydateSystem* = ref object

  PDFile* = ref object
    content, path: string
    mode: FileOptions

  MockWriteStream = ref object of Stream
    file: PDFile

  FileOptions* = enum
    kFileRead
    kFileReadData
    kFileWrite
    kFileAppend

  PDButton* = enum
    kButtonLeft = 1
    kButtonRight
    kButtonUp
    kButtonDown
    kButtonB
    kButtonA

  PDButtons* = set[PDButton]

  NineSlice* = ref object

let playdate* = PlaydateApi(
  graphics: pdGraphics,
  file: PlaydateFiles(),
  system: PlaydateSystem(),
  sprite: PlaydateSprites(),
  sound: PlaydateSounds(),
)

var mockFiles = initTable[string, string]()

template withMockFiles*(files: openarray[(string, string)], body: untyped) =
  assert(mockFiles.len == 0)
  for (path, content) in files:
    mockFiles[path] = content
  try:
    body
  finally:
    mockFiles.clear()

proc mkdir*(_: PlaydateFiles, path: string) =
  discard

proc exists*(_: PlaydateFiles, path: string): bool =
  mockFiles.hasKey(path)

proc open*(api: PlaydateFiles, path: string, options: FileOptions): PDFile =
  case options
  of kFileRead, kFileReadData:
    assert(api.exists(path), "File not found")
    return PDFile(path: path, content: mockFiles[path], mode: options)
  of kFileWrite:
    return PDFile(path: path, content: "", mode: options)
  of kFileAppend:
    return PDFile(path: path, content: mockFiles.getOrDefault(path), mode: options)

proc readString*(file: PDFile): string =
  file.content

proc read*(file: PDFile): seq[byte] =
  file.content.mapIt(it.ord.byte).toSeq

proc write*(file: PDFile, content: string): int {.raises: [IOError], discardable.} =
  mockFiles[file.path] = content

proc write*(
    file: PDFile, content: seq[byte], len: uint
): int {.raises: [IOError], discardable.} =
  var toWrite: string
  for i in 0 ..< len:
    toWrite &= content[i].chr
  write(file, toWrite)

proc mwsWriteData(
    s: Stream, buffer: pointer, bufLen: int
) {.nimcall, raises: [], tags: [], gcsafe.} =
  ## Appends to the mock file, flushing straight back so writes are immediately visible
  let file = MockWriteStream(s).file
  if bufLen > 0:
    let start = file.content.len
    file.content.setLen(start + bufLen)
    copyMem(addr file.content[start], buffer, bufLen)
    {.cast(gcsafe).}:
      mockFiles[file.path] = file.content

proc toStream*(file: PDFile): Stream =
  ## Wraps a mock file in a `std/streams` `Stream`, mirroring the real playdate file api
  return
    if file.mode in {kFileWrite, kFileAppend}:
      MockWriteStream(file: file, writeDataImpl: mwsWriteData)
    else:
      newStringStream(file.content)

proc getSecondsSinceEpoch*(
    _: PlaydateSystem
): tuple[seconds: uint, milliseconds: uint] =
  return (12345, 78910)

proc drawFPS*(_: PlaydateSystem, x, y: int) =
  discard

proc newNineSlice*(source: LCDBitmap): NineSlice =
  raiseAssert("Unsupported")

proc logToConsole*(_: PlaydateSystem, message: string) =
  echo message

proc getElapsedTime*(_: PlaydateSystem): float32 =
  discard

proc getCurrentTimeMilliseconds*(_: PlaydateSystem): uint32 =
  discard

proc setSerialMessageCallback*(_: PlaydateSystem, callback: proc(msg: string)) =
  discard
