import std/strutils

when defined(simulator) or defined(device):
  import playdate/api
else:
  import ../../tests/stubs/playdate_api

proc mkdirs*(path: string) =
  ## Creates all directories in a path
  var accumDir = newStringOfCap(path.len)
  for part in path.split("/"):
    if part == "" and accumDir == "":
      accumDir = "/"
    elif part != "":
      accumDir &= part
      accumDir &= "/"
      if not playdate.file.exists(accumDir):
        playdate.file.mkdir(accumDir)

proc copyFile*(srcPath, dstPath: string) =
  ## Copies a file from srcPath to dstPath using Playdate's file API
  let srcFile = playdate.file.open(srcPath, kFileRead)
  let dstFile = playdate.file.open(dstPath, kFileWrite)
  let content = srcFile.read()
  dstFile.write(content, content.len.uint)
