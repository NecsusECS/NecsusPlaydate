##
## Represents a floating point value using an integer and a precision
##
import vmath, fixedpoint

export fixedpoint

const FPVecPrecision* {.intDefine.} = 6

type
  FPInt* = FPInt32[FPVecPrecision]
  FPVec2* = GVec2[FPInt]
  FPVec3* = GVec3[FPInt]
  FPVec4* = GVec4[FPInt]

proc fp*(
    value: SomeInteger, precision: static Natural = FPVecPrecision
): FPInt32[precision] =
  ## Creates a fixed point number
  FPInt32[precision](value shl precision)

proc fp*(
    value: SomeFloat, precision: static Natural = FPVecPrecision
): FPInt32[precision] =
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

proc cross*(a, b: GVec2): auto =
  ## Calculates the 2D "cross product" of two vectors, returning a scalar.
  ## This is equivalent to treating the 2D vectors as 3D vectors with a zero z-component
  ## and returning the z-component of the 3D cross product.
  return a.x * b.y - a.y * b.x

proc rayPointsAtLine*(origin, direction, pointA, pointB: GVec2): bool =
  ## Returns true if the ray defined by `origin` and `direction` intersects the
  ## line segment defined by [`pointA`, `pointB`].
  let segmentVector = pointB - pointA
  let offset = pointA - origin
  let denominator = cross(direction, segmentVector)

  if denominator != 0:
    let t: FPInt = cross(offset, segmentVector) / denominator
    let u: FPInt = cross(offset, direction) / denominator
    return (t >= 0) and (u >= 0) and (u <= 1)
  elif cross(offset, direction) != 0:
    # Parallel case
    return false
  else:
    # Collinear: check if ray overlaps the segment at all
    let projectionA = dot(pointA - origin, direction)
    let projectionB = dot(pointB - origin, direction)
    return projectionA >= 0 or projectionB >= 0

proc nudge*(base, towards: FPVec2, strength: FPInt = fp(0.2)): FPVec2 =
  ## Nudges a vector towards its direction
  result = base
  if towards.lengthSq > 0:
    result += towards.normalize() * strength

proc limitedAdjust*(current, preferred: FPVec2, maxDelta: FPInt): FPVec2 =
  ## Adjusts the current direction towards the preferred direction,
  ## but limits the maximum delta between them

  let delta = preferred - current
  let deltaLength = delta.length

  # If the delta is already within limits, just return the preferred direction
  return
    if deltaLength <= maxDelta:
      preferred
    else:
      # Scale the delta to the maximum allowed length and add to current
      current + (delta * (maxDelta / deltaLength))

proc rayPointsAtCircle*(origin, direction, center: GVec2, radius: auto): bool =
  ## Returns whether a ray starting at `origin` with direction `direction`
  ## intersects a circle centered at `center` with radius `radius`.
  let f = center - origin
  let dirLen2 = dot(direction, direction)

  if dirLen2 == 0:
    # Degenerate ray: it's just a point
    return dot(f, f) <= radius*radius

  let proj = dot(f, direction) / dirLen2

  if proj < 0:
    # Closest point is behind the origin
    return dot(f, f) <= radius*radius
  else:
    let dist2 = dot(f, f) - (dot(f, direction) * dot(f, direction)) / dirLen2
    return dist2 <= radius*radius
