##
## Represents a floating point value using an integer and a precision
##
import macros, vmath

type
    FPInt32*[P: static Natural] = distinct int32
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

macro precision*(num: FPInt32): Natural =
    ## Returns the precision of a fixed point number
    let typ = num.getTypeInst
    typ.expectKind(nnkBracketExpr)
    typ[0].expectKind(nnkSym)
    typ[1].expectKind(nnkIntLit)
    return typ[1]

template defineMathOp(op: untyped) =
    proc `op`*(a, b: FPInt32): FPInt32 =
        assert(a.precision == b.precision)
        typeof(a)(`op`(a.int32, b.int32))

defineMathOp(`+`)
defineMathOp(`-`)

template defineCompareOp(op: untyped) =
    proc `op`*(a, b: FPInt32): bool =
        assert(a.precision == b.precision)
        return `op`(a.int32, b.int32)

defineCompareOp(`==`)
defineCompareOp(`<`)
defineCompareOp(`<=`)

template defineUnary(op: untyped) =
    proc `op`*(value: FPInt32): auto =
        return typeof(value)(`op`(value.int32))

defineUnary(`-`)
defineUnary(`abs`)

proc high(typ: typedesc[FPInt32]): typ =
    return typeof(result)(high(int32))

proc low(typ: typedesc[FPInt32]): typ =
    return typeof(result)(low(int32))

proc `*`*(a, b: FPInt32): FPInt32 =
    # Fixed point multipliation
    assert(a.precision == b.precision)
    return typeof(a)(a.int32.int64 * b.int32.int64 shr a.precision)

proc `/`*(a, b: FPInt32): FPInt32 =
    # Fixed point division
    assert(a.precision == b.precision)
    return typeof(a)(a.int32.int64 shl a.precision / b.int32.int64)

converter toInt32*(d: FPInt32): int32 = d.int32 shr d.precision

converter toFloat32*(d: FPInt32): float32 = d.int32 / (1 shl d.precision)

proc `$`*(d: FPInt32): string = $d.toFloat32

type
    FPVec2* = GVec2[FPInt32[8]]
    FPVec3* = GVec3[FPInt32[8]]
    FPVec4* = GVec4[FPInt32[8]]

genVecConstructor(fpvec, FPVec, FPInt32[8])