import std/[tables, sequtils], graphics, sprites

export graphics, sprites

type
  PlaydateApi* = object
    file*: PlaydateFiles
    system*: PlaydateSystem
    graphics*: PlaydateGraphics
    sprite*: PlaydateSprites

  PlaydateFiles* = object

  PlaydateSystem* = object

  PDFile* = ref object
    content, path: string

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

const
  LCD_COLUMNS* = 400
  LCD_ROWS* = 240

let playdate* = PlaydateApi(graphics: pdGraphics)

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
  assert(api.exists(path), "File not found")
  return PDFile(path: path, content: mockFiles[path])

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

proc getSecondsSinceEpoch*(
    _: PlaydateSystem
): tuple[seconds: uint, milliseconds: uint] =
  return (12345, 78910)

proc drawFPS*(_: PlaydateSystem, x, y: int) =
  discard
