import std/unittest, necsuspd/glow, necsuspd/stubs/graphics

suite "Dithered glow generation":
  test "Generate a glow image":
    let pulse = newGlowConfig(size = 15, frames = 5, color = kColorBlack).buildFrames()
    check pulse.len == 5

    #!fmt: off
    check pulse[3] == [
      "_______________",
      "______XXX______",
      "___XXX_X_X_____",
      "__XXXXXXXXX_X__",
      "__XXXXXX_X_X___",
      "_XXXXXXXX_X_X__",
      "_XXXXXXX_X_____",
      "_XXXXXXXXXX_X__",
      "_XXXXXXX_X_X___",
      "_XXXXXXXX_X_X__",
      "___XXX_X_X_X___",
      "__XXXXXXXXX_X__",
      "_______X_XXX___",
      "______X_X______",
      "_______________",
    ]
    #!fmt: on
