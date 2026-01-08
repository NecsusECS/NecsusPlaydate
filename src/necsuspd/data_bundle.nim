import import_playdate, std/[macros, jsonutils, json, strutils], util, json_schema_import
importPlaydateApi()

proc bundledData*(T: typedesc, path: static[string]): T =
  ## Copies the given path into the source directory at build time,
  ## then returns the parsed content
  const bundledPath = path.strip(chars = {'.', '/'}).replace("/", "_")

  static:
    const fullPath = getProjectPath() & "/../" & path
    const content = slurp(fullPath).parseJson.jsonTo(T).toBinary()
    writeFile(getProjectPath() & "/../source/" & bundledPath, content)

  log "Reading bundled data ", bundledPath
  assert(playdate != nil and playdate.file != nil)
  assert(playdate.file.exists(bundledPath), "File does not exist: " & bundledPath)
  var handle = playdate.file.open(bundledPath, kFileRead)
  return fromBinary(T, handle.readString())
