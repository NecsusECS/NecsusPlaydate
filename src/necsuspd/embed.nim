import std/[macros, genasts, jsonutils, json], util, c

proc parseForEmbed[T](content: string): T =
  ## Parses the content of a file into a Nim object
  when compiles(parse(T, content) is T):
    return parse(T, content)
  else:
    return jsonTo(parseJson(content), T)

template dynLoad[T](path: string, open, readString, close: untyped): T =
  ## Opens and reads a file, returning the parsed content
  block:
    let file = open(path)
    try:
      let content = readString(file)
      assert(content != "")
      parseForEmbed[T](content)
    finally:
      close(file)

proc buildEmbed(
    typ, path: NimNode,
    exists, slurp, open, readString, close: NimNode,
    alwaysEmbed: bool,
): NimNode =
  ## Embeds content from a file into the nim binary for release builds
  let projPath = getProjectPath()

  let fullPath = genAst(path, projPath):
    projPath & "/../" & path

  result = genAst(fullPath, typ, slurp):
    block:
      log "Loading embedded data for ", fullPath
      const bin = toBinary(parseForEmbed[typ](slurp(fullPath)))
      typ.fromBinary(bin)

  if not alwaysEmbed:
    when not defined(device):
      result = genAst(path, fullPath, typ, exists, open, readString, close, result):
        block:
          let content = c_readAll(fullPath)
          if content != "":
            log "Dynamically loading from: ", fullPath
            parseForEmbed[typ](content)
          else:
            log "Dynamic load source does not exist: ", fullPath
            result

    result = genAst(path, typ, exists, open, readString, close, result):
      block:
        if exists(path):
          log "Dynamically loading from: ", path
          dynLoad[typ](path, open, readString, close)
        else:
          log "Dynamic load source does not exist: ", path
          result

when defined(unittests):
  macro embedDataTest*(
      typ: typedesc,
      path: string,
      exists, slurp, open, readString, close: untyped,
      alwaysEmbed: static bool,
  ): auto =
    buildEmbed(typ, path, exists, slurp, open, readString, close, alwaysEmbed)

else:
  import playdate/api

  proc openForRead(path: string): auto =
    assert(playdate != nil and playdate.file != nil)
    playdate.file.open(path, kFileRead)

  proc fileExists(path: string): bool =
    if playdate != nil and playdate.file != nil:
      result = playdate.file.exists(path)

  proc closeFile(file: SDFile) =
    file.close()

  macro embedData*(typ: typedesc, path: string): auto =
    buildEmbed(
      typ,
      path,
      bindSym("fileExists"),
      bindSym("slurp"),
      bindSym("openForRead"),
      bindSym("readString"),
      bindSym("closeFile"),
      defined(release),
    )
