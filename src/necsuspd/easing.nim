import math, macros, strutils

type
  EasingFunc* = proc(progress: float32): float32
    ## Easing functions that describes the progress of a move

  EasingCalc*[T] = proc(a, b: T, progress: float32): T
    ## An easing function that calculates the position between two values

macro asCalc(easing: untyped): untyped =
  easing.expectKind(nnkProcDef)
  let originalName = easing.name
  let name = ident(originalName.strVal.replace("ease", "calc"))
  let boomerang = ident(originalName.strVal & "Boomerang")
  return quote:
    `easing`

    proc `boomerang`*(t: float32): float32 =
      return `originalName`(
        if t <= 0.5:
          t * 2
        else:
          2 - (2 * t)
      )

    proc `originalName`*[T](start, finish, progress: T): float32 =
      return `originalName`((progress - start) / (finish - start))

    proc `originalName`*[T](values: HSlice[T, T], progress: T): float32 =
      return `originalName`(values.a, values.b, progress)

    proc `name`*[T](a, b: T, t: float32): T =
      let diff: T = b - a
      let scalar: float32 = `originalName`(t)
      a + (diff * scalar)

    proc `name`*(kind: typedesc): EasingCalc[kind] =
      proc(a, b: kind, t: float32): kind =
        `name`[kind](a, b, t)

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

proc easeOutCubic(t: float32): float32 {.asCalc.} =
  1 - pow(1 - t, 3)

proc easeInQuint*(t: float32): float32 {.asCalc.} =
  t * t * t * t * t

proc easeInExpo*(t: float32): float32 {.asCalc.} =
  return
    if t == 0:
      0
    else:
      pow(2, 10 * t - 10)

proc easeOutExpo*(t: float32): float32 {.asCalc.} =
  return
    if t == 1:
      1
    else:
      1 - pow(2, -10 * t)

proc easeInBack*(t: float32): float32 {.asCalc.} =
  const c1 = 1.70158
  const c3 = c1 + 1
  return c3 * t * t * t - c1 * t * t

proc easeOutBack*(t: float32): float32 {.asCalc.} =
  const c1 = 1.70158
  const c3 = c1 + 1
  return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)

proc easeInOutBack*(t: float32): float32 {.asCalc.} =
  const c1 = 1.70158
  const c2 = c1 * 1.525
  return
    if t < 0.5:
      (pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
    else:
      (pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
