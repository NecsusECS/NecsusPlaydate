import necsuspd/files, std/unittest

suite "File operations":
  test "Extract filename":
    check extractFilename("/home/user/documents/report.txt") == "report.txt"
    check extractFilename("report.txt") == "report.txt"
    check extractFilename("") == ""
