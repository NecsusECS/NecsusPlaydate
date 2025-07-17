##
## Represents a floating point value using an integer and a precision
##
import vmath, fixedpoint

export fixedpoint

const FPVecPrecision* {.intDefine.} = 6

type
  FPVec2* = GVec2[FPInt32[FPVecPrecision]]
  FPVec3* = GVec3[FPInt32[FPVecPrecision]]
  FPVec4* = GVec4[FPInt32[FPVecPrecision]]

proc fp*(value: SomeInteger, precision: static Natural = FPVecPrecision): FPInt32[precision] =
  ## Creates a fixed point number
  FPInt32[precision](value shl precision)

proc fp*(value: SomeFloat, precision: static Natural = FPVecPrecision): FPInt32[precision] =
  ## Creates a fixed point number
  FPInt32[precision](int32(value * (1 shl precision)))

genVecConstructor(fpvec, FPVec, FPInt32[FPVecPrecision])

proc fpvec2*(x, y: SomeInteger): FPVec2 =
  fpvec2(x.fp32(FPVecPrecision), y.fp(FPVecPrecision))

proc toFPVec2*(ivec2: IVec2): FPVec2 =
  fpvec2(ivec2.x, ivec2.y)

template toFPVec2*(vec2: FPVec2): FPVec2 =
  vec2

proc toIVec2*(vec: FPVec2): IVec2 =
  ivec2(vec.x.toInt, vec.y.toInt)

proc toVec2*(vec: FPVec2): Vec2 =
  vec2(vec.x.toFloat, vec.y.toFloat)
