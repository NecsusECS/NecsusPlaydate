import unittest, necsuspd/boxelem, necsuspd/stubs/graphics, helpers

proc `==`*(a: BoxDimens, b: (int, int)): bool =
  return a == (b[0].int32, b[1].int32)

const loremIpsum =
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras molestie tempor odio ut sagittis."

let font = newFont("foo", height = 14, charWidth = 8)

proc checkGraphicActions(expected: varargs[string]) =
  let actions = graphicActions()
  checkpoint("Full set of found actions is:\n " & $actions)
  for i in 0 ..< max(actions.len, expected.len):
    let expect =
      if i < expected.len:
        expected[i]
      else:
        ""
    let actual =
      if i < actions.len:
        actions[i]
      else:
        ""
    checkpoint("Comparing index " & $i)
    require(actual == expect)

suite "Box Elem":
  test "A basic string should be written in the top left corner":
    text("foo").draw(newSprite("testImg", 100, 100), font)

    checkGraphicActions(
      "setFont(testImg, font.name: foo)",
      "drawMode(testImg, drawMode: kDrawModeFillBlack)",
      "drawText(testImg, text: foo, x: 2, y: 2)",
    )

  test "Changing the draw mode of text":
    text("foo", drawMode = kDrawModeFillWhite).draw(
      newSprite("testImg", 100, 100), font
    )

    checkGraphicActions(
      "setFont(testImg, font.name: foo)",
      "drawMode(testImg, drawMode: kDrawModeFillWhite)",
      "drawText(testImg, text: foo, x: 2, y: 2)",
    )

  test "Text wrapping":
    text(loremIpsum, wrap = true).draw(newSprite("testImg", 200, 100), font)

    checkGraphicActions(
      "setFont(testImg, font.name: foo)",
      "drawMode(testImg, drawMode: kDrawModeFillBlack)",
      "drawText(testImg, text: Lorem ipsum dolor sit, x: 2, y: 2)",
      "drawText(testImg, text: amet, consectetur, x: 2, y: 19)",
      "drawText(testImg, text: adipiscing elit. Cras, x: 2, y: 36)",
      "drawText(testImg, text: molestie tempor odio ut, x: 2, y: 53)",
      "drawText(testImg, text: sagittis., x: 2, y: 70)",
    )

  test "Right aligned text wrapping":
    text(loremIpsum, wrap = true, align = AlignRight).draw(
      newSprite("testImg", 300, 100), font
    )

    checkGraphicActions(
      "setFont(testImg, font.name: foo)",
      "drawMode(testImg, drawMode: kDrawModeFillBlack)",
      "drawText(testImg, text: Lorem ipsum dolor sit amet,, x: 82, y: 2)",
      "drawText(testImg, text: consectetur adipiscing elit. Cras, x: 34, y: 19)",
      "drawText(testImg, text: molestie tempor odio ut sagittis., x: 34, y: 36)",
    )

  test "Calculating the dimensions of text elements":
    check(text("Lorem ipsum").dimens(font) == (width: 92, height: 18))
    checkGraphicActions()

  test "Calculating the dimensions of wrapped elements":
    check(text(loremIpsum, wrap = true).dimens(font) == (width: 764, height: 18))
    checkGraphicActions()

  test "Calculating the dimensions of row elements":
    check(row(text("blah"), text("wakka")).dimens(font) == (width: 80, height: 18))
    checkGraphicActions()

  test "Calculating the dimensions of stack elements":
    check(stack(text("blah"), text("wakka")).dimens(font) == (width: 44, height: 36))
    checkGraphicActions()

  test "Calculating the dimensions of horizontal lines":
    check(horizLine(2).dimens(font) == (width: 4, height: 6))
    checkGraphicActions()

  test "Calculating the dimensions of padded text":
    check(pad(1, 2, 3, 4, text("1232")).dimens(font) == (width: 39, height: 25))
    checkGraphicActions()

  test "Drawing a blank element":
    blank(10, 20).draw(newSprite("testImg", 300, 100), font)
    checkGraphicActions()

  test "Calculating the dimensions of a blank":
    check(blank(50, 40).dimens(font) == (width: 50, height: 40))
    checkGraphicActions()

  test "Drawing an image element":
    img(newImage("foo", 10, 20, kColorWhite)).draw(newSprite("testImg", 300, 100), font)
    checkGraphicActions(
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: foo, x: 0, y: 0)",
    )

  test "Drawing a right aligned image element":
    img(newImage("foo", 10, 20, kColorWhite), align = AlignRight).draw(
      newSprite("testImg", 300, 100), font
    )
    checkGraphicActions(
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: foo, x: 290, y: 0)",
    )

  test "Drawing a center aligned image element":
    img(newImage("foo", 20, 20, kColorWhite), align = AlignCenter).draw(
      newSprite("testImg", 300, 100), font
    )
    checkGraphicActions(
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: foo, x: 140, y: 0)",
    )

  test "Stack of images":
    stack(
      img(newImage("foo", 20, 20, kColorWhite)),
      img(newImage("bar", 30, 30, kColorWhite), align = AlignCenter),
      img(newImage("baz", 40, 40, kColorWhite), align = AlignRight),
      img(newImage("qux", 10, 10, kColorWhite)),
    )
    .draw(newSprite("testImg", 300, 100), font)

    checkGraphicActions(
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: foo, x: 0, y: 0)",
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: bar, x: 135, y: 20)",
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: baz, x: 260, y: 50)",
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: qux, x: 0, y: 90)",
    )

  test "Calculating the dimensions of a bitmap":
    check(
      img(newImage("foo", 10, 20, kColorWhite)).dimens(font) == (width: 10, height: 20)
    )
    checkGraphicActions()

  test "Drawing rows of content":
    row(
      img(newImage("foo", 20, 20, kColorWhite)),
      img(newImage("bar", 30, 30, kColorWhite)),
      img(newImage("baz", 40, 40, kColorWhite)),
    )
    .draw(newSprite("testImg", 300, 100), font)

    checkGraphicActions(
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: foo, x: 0, y: 0)",
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: bar, x: 20, y: 0)",
      "drawMode(testImg, drawMode: kDrawModeCopy)",
      "drawBitmap(testImg, name: baz, x: 50, y: 0)",
    )

  test "Setting the max width of a box with text in it":
    maxWidth(200, text(loremIpsum, wrap = true)).draw(
      newSprite("testImg", 500, 100), font
    )
    checkGraphicActions(
      "setFont(testImg, font.name: foo)",
      "drawMode(testImg, drawMode: kDrawModeFillBlack)",
      "drawText(testImg, text: Lorem ipsum dolor sit, x: 2, y: 2)",
      "drawText(testImg, text: amet, consectetur, x: 2, y: 19)",
      "drawText(testImg, text: adipiscing elit. Cras, x: 2, y: 36)",
      "drawText(testImg, text: molestie tempor odio ut, x: 2, y: 53)",
      "drawText(testImg, text: sagittis., x: 2, y: 70)",
    )

    maxWidth(300, text(loremIpsum, wrap = true)).draw(
      newSprite("testImg", 500, 100), font
    )
    checkGraphicActions(
      "setFont(testImg, font.name: foo)",
      "drawMode(testImg, drawMode: kDrawModeFillBlack)",
      "drawText(testImg, text: Lorem ipsum dolor sit amet,, x: 2, y: 2)",
      "drawText(testImg, text: consectetur adipiscing elit. Cras, x: 2, y: 19)",
      "drawText(testImg, text: molestie tempor odio ut sagittis., x: 2, y: 36)",
    )

  test "Checking the dimens of a maxWidth element":
    check(maxWidth(1000, text(loremIpsum, wrap = true)).dimens(font) == (764, 18))
    checkGraphicActions()

    check(maxWidth(300, text(loremIpsum, wrap = true)).dimens(font) == (268, 52))
    checkGraphicActions()

    check(maxWidth(100, text(loremIpsum, wrap = true)).dimens(font) == (100, 154))
    checkGraphicActions()

  test "Forcing a minimum width":
    let elem = text("foo").minWidth(80)
    check(elem.dimens(font) == (80, 18))
    elem.draw(newSprite("testImg", 100, 100), font)
    checkGraphicActions(
      "setFont(testImg, font.name: foo)",
      "drawMode(testImg, drawMode: kDrawModeFillBlack)",
      "drawText(testImg, text: foo, x: 2, y: 2)",
    )

  test "Forcing a minimum width with a padding":
    let elem = pad(text("foo").minWidth(60), 10, 20, 30, 40)
    check(elem.dimens(font) == (90, 88))
    elem.draw(newSprite("testImg", 100, 100), font)
    checkGraphicActions(
      "setFont(testImg, font.name: foo)",
      "drawMode(testImg, drawMode: kDrawModeFillBlack)",
      "drawText(testImg, text: foo, x: 12, y: 32)",
    )
