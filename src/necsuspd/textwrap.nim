import std/strutils

iterator textwrap*(text: string, maxWidth: int32, getWidth: proc (text: string): int32): string =
    ## Splits text into lines based on a width calculating function

    let spaceWidth = getWidth(" ")
    var currentWidth = 0
    var accum: string
    for word in text.splitWhitespace:
        # echo "Accum: ", accum
        # echo "  Current Width: ", currentWidth
        # echo "  New word: ", word
        if accum.len == 0:
            accum = word
        elif currentWidth + spaceWidth + getWidth(word) <= maxWidth:
            accum.add(" ")
            accum.add(word)
        else:
            yield accum
            accum = word

        currentWidth = getWidth(accum)

    if accum.len > 0:
        yield accum
