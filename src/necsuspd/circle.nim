##
## Taken from https://stackoverflow.com/questions/27755514/circle-with-thickness-drawing-algorithm
##

type
    CircleCanvas* = tuple[x, y, w, h: int32]
    CirclePoint* = tuple[x, y: int32]

iterator xLine*(x1, x2, y: int32, canvas: CircleCanvas): CirclePoint=
    if y >= canvas.y and y < (canvas.y + canvas.h):
        let xRange = max(x1, canvas.x)..min(canvas.x + canvas.w - 1, x2)
        # echo y, ", ", x1, "..", x2, " ", xRange
        for x in xRange:
            yield (x, y)

iterator yLine*(x, y1, y2: int32, canvas: CircleCanvas): CirclePoint =
    if x >= canvas.x and x < (canvas.x + canvas.w):
        let yRange = max(y1, canvas.y)..min(canvas.y + canvas.h - 1, y2)
        for y in yRange:
            yield (x, y)

template yieldAll(iter: untyped): untyped =
    for value in iter:
        yield value

iterator circlePixels*(x, y, inner, outer: int32, canvas: CircleCanvas): CirclePoint =
    ## Yield all the points to draw a circle
    var xo = outer
    var xi = inner
    var currentY: int32 = 0
    var erro = 1 - xo
    var erri = 1 - xi
    while xo >= currentY:
        yieldAll(xLine(x + xi, x + xo, y + currentY, canvas))
        yieldAll(yLine(x + currentY, y + xi, y + xo, canvas))
        yieldAll(xLine(x - xo, x - xi, y + currentY, canvas))
        yieldAll(yLine(x - currentY, y + xi, y + xo, canvas))
        yieldAll(xLine(x - xo, x - xi, y - currentY, canvas))
        yieldAll(yLine(x - currentY, y - xo, y - xi, canvas))
        yieldAll(xLine(x + xi, x + xo, y - currentY, canvas))
        yieldAll(yLine(x + currentY, y - xo, y - xi, canvas))

        inc(currentY)

        if erro < 0:
            inc(erro, 2 * currentY + 1)
        else:
            dec(xo)
            inc(erro, 2 * (currentY - xo + 1))

        if currentY > inner:
            xi = currentY
        elif erri < 0:
            inc(erri, 2 * currentY + 1)
        else:
            dec(xi)
            inc(erri, 2 * (currentY - xi + 1))

iterator circlePixels*(x, y, inner, outer: int32): CirclePoint =
    let canvas = (x - outer - 1, y - outer - 1, x + outer + 1, y + outer + 1)
    yieldAll(circlePixels(x, y, inner, outer, canvas))
