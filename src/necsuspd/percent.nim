import std/[strformat, math]

const SHIFT_RES = 12

const RESOLUTION = 2 ^ SHIFT_RES

type Percent* = distinct int32
    ## Integer math based percentages

proc percent*(num, denom: SomeInteger): Percent =
    ## Creates a percentage able to use integer math
    Percent((num shl SHIFT_RES) div denom)

proc percent*(percentage: SomeFloat): Percent =
    Percent(percentage * RESOLUTION.float32)

proc toFloat*(pct: Percent): float32 = int32(pct).toBiggestFloat / RESOLUTION.float32

proc `$`*(pct: Percent): string = fmt"{(pct.toFloat * 100):.2f}%"

proc `*`*[T: SomeInteger](value: T, versus: Percent): T =
    ## Calculate the percent of a value
    T(int32(versus) * int32(value) shr SHIFT_RES)

proc `*`*[T: SomeFloat](value: T, versus: Percent): T =
    ## Calculate the percent of a value
    int32(versus).T * value / RESOLUTION.float32

proc `*`*(a, b: Percent): Percent =
    ## Combines two percentages
    Percent(int32(a) * int32(b) shr SHIFT_RES)

template `*=`*(a: var Percent; b: Percent) =
    ## Combines a percentage
    a = a * b

template `*=`*(a: var Percent; b: SomeNumber) =
    ## Combines a percentage
    a = a * b

template `*=`*(a: var SomeNumber; b: Percent) =
    ## Combines a percentage
    a = a * b

proc `+`*(a, b: Percent): Percent =
    ## Combines two percentages
    Percent(int32(a) + int32(b))

proc invert*(pct: Percent): Percent =
    ## Combines two percentages
    Percent(RESOLUTION - int32(pct))

proc `^`*(pct: Percent, power: SomeInteger): Percent =
    ## Multiplies this percentage by itself a specific number of times
    if power == 0:
        result = Percent(RESOLUTION)
    else:
        result = pct
        for _ in 0..<(power - 1):
            result = result * pct

proc `==`*(a, b: Percent): bool {.borrow.}
proc `<=`*(a, b: Percent): bool {.borrow.}
proc `<`*(a, b: Percent): bool {.borrow.}

template `*`*[T](versus: Percent, value: T): T = value * versus
