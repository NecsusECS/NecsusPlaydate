##
## Represents a floating point value using an integer and a precision
##
import macros, vmath, util

type FPInt32*[P: static Natural] = distinct int32
  ## 32-bit fixed point integer with P bits of precision

proc fp*(value: SomeInteger, precision: static Natural): FPInt32[precision] =
  ## Creates a fixed point number
  FPInt32[precision](value shl precision)

proc fp*(value: SomeFloat, precision: static Natural): FPInt32[precision] =
  ## Creates a fixed point number
  FPInt32[precision](int32(value * (1 shl precision)))

proc fp8*(value: SomeNumber): FPInt32[8] =
  ## Convert a number to a 8 bit fixed point
  fp(value, 8)

proc toInt32*(d: FPInt32): int32 =
  d.int32 shr d.precision

proc toFloat32*(d: FPInt32): float32 =
  d.int32 / (1 shl d.precision)

macro precision*(num: FPInt32): Natural =
  ## Returns the precision of a fixed point number
  let typ = num.getTypeInst
  typ.expectKind(nnkBracketExpr)
  typ[0].expectKind(nnkSym)
  typ[1].expectKind(nnkIntLit)
  return typ[1]

template `as`*(value: typed, prototype: FPInt32): typeof(prototype) =
  typeof(prototype)(fp(value, prototype.precision))

template defineMathOp(op: untyped) =
  proc `op`*(a, b: FPInt32): FPInt32 =
    assert(a.precision == b.precision)
    typeof(a)(`op`(a.int32, b.int32))

  proc `op`*(a: SomeInteger, b: FPInt32): FPInt32 =
    fp(a, b.precision) `op` b

  proc `op`*(a: FPInt32, b: SomeInteger): FPInt32 =
    a `op` fp(b, a.precision)

defineMathOp(`+`)
defineMathOp(`-`)

template defineFloatOp(op: untyped) =
  proc `op`*(a, b: FPInt32): typeof(a) {.inline.} =
    assert(a.precision == b.precision)
    fp(`op`(a.toFloat32, b.toFloat32), a.precision) as a

defineFloatOp(`arctan2`)

template defineCompareOp(op: untyped) =
  proc `op`*(a, b: FPInt32): bool {.inline.} =
    assert(a.precision == b.precision)
    return `op`(a.int32, b.int32)

defineCompareOp(`==`)
defineCompareOp(`<`)
defineCompareOp(`<=`)

template defineUnary(op: untyped) =
  proc `op`*(value: FPInt32): auto {.inline.} =
    return typeof(value)(`op`(value.int32))

defineUnary(`-`)
defineUnary(`abs`)

proc high(typ: typedesc[FPInt32]): typ =
  return typeof(result)(high(int32))

proc low(typ: typedesc[FPInt32]): typ =
  return typeof(result)(low(int32))

proc `*`*(a, b: FPInt32): FPInt32 {.inline.} =
  # Fixed point multipliation
  assert(a.precision == b.precision)
  typeof(a)(a.int32.int64 * b.int32.int64 shr a.precision)

proc `/`*(a, b: FPInt32): FPInt32 =
  # Fixed point division
  assert(a.precision == b.precision)
  return typeof(a)(a.int32.int64 shl a.precision / b.int32.int64)

proc `div`*(a, b: FPInt32): FPInt32 {.inline.} =
  a / b

proc almostEqual*(a, b: FPInt32): bool {.inline.} =
  abs(a.int32 - b.int32) <= 4

template defineInplace(op, baseOp: untyped) =
  proc `op`*(a: var FPInt32, b: FPInt32) =
    a = `baseOp`(a, b)

defineInplace(`+=`, `+`)
defineInplace(`-=`, `-`)
defineInplace(`*=`, `*`)
defineInplace(`/=`, `/`)

proc sqrt*(value: FPInt32): typeof(value) =
  ## Calculates the square root of a fixed point number without converting to a floating point
  assert(value.int32 >= 0, "Cannot take square root of negative number")

  const one = fp(1, value.precision).int32
  if value.int32 == one or value.int32 == 0:
    return value

  const half = 0.5 as value
  const epsilon = typeof(value)(8)

  # Use Newton's method
  result = value.toInt32.isqrt as value
  for i in 0 .. 10:
    let previous = result
    result = half * (result + value / result)
    if abs(result - previous) <= epsilon:
      break

proc `$`*(d: FPInt32): string =
  $d.toFloat32

proc toDegrees*(rad: FPInt32): auto =
  ## Convert radians to degrees.
  const half_circle = fp(180, rad.precision)
  const PI = int32(PI * (1 shl rad.precision))
  return typeof(rad)(rad * half_circle / PI)

const FPVecPrecision* {.intDefine.} = 6

type
  FPVec2* = GVec2[FPInt32[FPVecPrecision]]
  FPVec3* = GVec3[FPInt32[FPVecPrecision]]
  FPVec4* = GVec4[FPInt32[FPVecPrecision]]

genVecConstructor(fpvec, FPVec, FPInt32[FPVecPrecision])

proc fpvec2*(x, y: SomeInteger): FPVec2 =
  fpvec2(x.fp(FPVecPrecision), y.fp(FPVecPrecision))

proc toFPVec2*(ivec2: IVec2): FPVec2 =
  fpvec2(ivec2.x, ivec2.y)

proc toIVec2*(vec: FPVec2): IVec2 =
  ivec2(vec.x.toInt32, vec.y.toInt32)

proc toVec2*(vec: FPVec2): Vec2 =
  vec2(vec.x.toFloat32, vec.y.toFloat32)
