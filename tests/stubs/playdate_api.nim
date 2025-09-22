import std/[tables, sequtils]

type
  PlaydateApi* = object
    file*: PlaydateFiles
    system*: PlaydateSystem

  PlaydateFiles* = object

  PlaydateSystem* = object

  PDFile* = ref object
    content, path: string

  FileOptions* = enum
    kFileRead
    kFileReadData
    kFileWrite
    kFileAppend

let playdate* = PlaydateApi()

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
