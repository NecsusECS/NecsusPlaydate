import std/[unittest, strformat, macros], necsuspd/embed

type
  Example = object
    foo: string

  StubFile = ref object
    content: string

proc closeStub(file: StubFile) =
  discard

proc readStub(file: StubFile): string =
  file.content

proc toBinary(example: Example): string =
  example.foo

proc fromBinary(typ: typedesc[Example], binary: string): Example =
  Example(foo: binary)

const relPath = "tests/embed/example.json"
const absPath = fmt"{getProjectPath()}/../{relPath}"

proc slurp(path: string): string =
  assert(path == absPath, fmt"Path was: {path}")
  return """{ "foo": "bar" }"""

suite "Embedding data":
  test "Statically loading a file":
    let embedded = embedData(Example, relPath, nil, slurp, nil, nil, nil, true)
    check(embedded == Example(foo: "bar"))

  test "Dynamically loading a file":
    proc exists(path: string): bool =
      assert(path == relPath)
      return true

    proc open(path: string): StubFile =
      assert(path == relPath)
      return StubFile(content: """{ "foo": "foobarbaz" }""")

    let embedded =
      embedData(Example, relPath, exists, slurp, open, readStub, closeStub, false)

    check(embedded == Example(foo: "foobarbaz"))

  test "Dynamically loading an absolute file":
    proc exists(path: string): bool =
      assert(path == relPath)
      return false

    proc open(path: string): StubFile =
      raiseAssert "Should not be called"

    let embedded =
      embedData(Example, relPath, exists, slurp, open, readStub, closeStub, false)

    check(embedded == Example(foo: "foobarbaz"))
