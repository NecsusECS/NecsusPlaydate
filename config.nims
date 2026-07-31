# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config

# Playdate builds are always single-threaded (see playdate/build/config.nim).
# Match that here so `nim check` and the test suite reflect real builds.
switch("threads", "off")
