import std/[unittest, strformat, macros], necsuspd/embed

type
    Example = object
        foo: string

    StubFile = ref object
        content: string

proc parseExample[T](content: string): auto =
    static:
        assert(T is Example)
    return Example(foo: content)

proc close(file: StubFile) =
    discard

proc readString(file: StubFile): string = file.content

proc toBinary(example: Example): string = example.foo

proc fromBinary(typ: typedesc[Example], binary: string): Example = Example(foo: binary)

proc slurp(path: string): string =
    assert(path == fmt"{getProjectPath()}/../path/to/file.txt", fmt"Path was: {path}")
    return "bar"

suite "Embedding data":

    test "Statically loading a file":
        proc exists(path: string): bool = raiseAssert "Should not be called"

        proc open(path: string): StubFile = raiseAssert "Should not be called"

        let embedded = embedData(
            Example,
            "path/to/file.txt",
            exists,
            open,
            slurp,
            parseExample,
            true
        )

        check(embedded == Example(foo: "bar"))

    test "Dynamically loading a file":
        proc exists(path: string): bool =
            assert(path == "path/to/file.txt")
            return true

        proc open(path: string): StubFile =
            assert(path == "path/to/file.txt")
            return StubFile(content: "foobarbaz")

        let embedded = embedData(
            Example,
            "path/to/file.txt",
            exists,
            open,
            slurp,
            parseExample,
            false
        )

        check(embedded == Example(foo: "foobarbaz"))