import math, macros, strutils

type
    EasingFunc* = proc(progress: float32): float32
        ## Easing functions that describes the progress of a move

    EasingCalc*[T] = proc(a, b: T; progress: float32): T
        ## An easing function that calculates the position between two values

macro asCalc(easing: untyped): untyped =
    easing.expectKind(nnkProcDef)
    let originalName = easing.name
    let name = ident(originalName.strVal.replace("ease", "calc"))
    return quote:
        `easing`

        proc `originalName`*[T](start, finish, progress: T): float32 =
            return `originalName`((progress - start) / (finish - start))

        proc `name`*[T](a, b: T; t: float32): T =
            let diff: T = b - a
            let scalar: float32 = `originalName`(t)
            a + (diff * scalar)

        proc `name`*(kind: typedesc): EasingCalc[kind] =
            proc (a, b: kind; t: float32): kind = `name`[kind](a, b, t)

proc easeLinear*(t: float32): float32 {.asCalc.} =
    t

proc easeInOutSin*(t: float32): float32 {.asCalc.} =
    -(cos(PI * t) - 1) / 2

proc easeOutSin*(t: float32): float32 {.asCalc.} =
    sin((t * PI) / 2)

proc easeInSin*(t: float32): float32 {.asCalc.} =
    1 - cos((t * PI) / 2)

proc easeInCubic*(t: float32): float32 {.asCalc.} =
    t * t * t

proc easeInQuint*(t: float32): float32 {.asCalc.} =
    t * t * t * t * t