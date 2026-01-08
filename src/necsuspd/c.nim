##
## Helper methods for raw c interop
##

import system/ansi_c, strformat

proc c_fopen(filename, mode: cstring): CFilePtr {.importc: "fopen", nodecl.}

proc c_fseek(
  f: CFilePtr, offset: clong, origin: cint
): cint {.importc: "fseek", header: "<stdio.h>", tags: [].}

const
  SEEK_SET = 0
  SEEK_END = 2

proc c_ftell(f: CFilePtr): csize_t {.importc: "ftell", header: "<stdio.h>", tags: [].}

proc c_fread(
  buf: cstring, size, n: csize_t, f: CFilePtr
): csize_t {.importc: "fread", header: "<stdio.h>", tags: [ReadIOEffect].}

proc c_fclose(file: CFilePtr) {.importc: "fclose", nodecl.}

proc c_readAll*(path: string): string =
  ## Reads the content of a file using ansi C methods

  var f = c_fopen(path, "rb")
  if f != nil:
    try:
      assert(c_fseek(f, 0, SEEK_END) == 0, fmt"fseek failed for {path}")
      let length = c_ftell(f)
      assert(c_fseek(f, 0, SEEK_SET) == 0, fmt"fseek failed for {path}")
      result.setLen(length)
      assert(c_fread(result, 1, length, f) == length, fmt"fread failed for {path}")
    finally:
      c_fclose(f)
