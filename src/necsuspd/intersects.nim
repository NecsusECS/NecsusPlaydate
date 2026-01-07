import fpvec, fixedpoint, vmath, std/[options, strformat], fungus

adtEnum(Intersection):
  Point:
    FPVec2
  Segment:
    tuple[a, b: FPVec2]
  Circle:
    tuple[center: FPVec2, radius: FPInt]

proc `$`*(point: Point): string =
  fmt"point({point.toInternal})"

proc `$`*(segment: Segment): string =
  fmt"segment({segment.a}, {segment.b})"

proc `$`*(circ: Circle): string =
  fmt"circle({circ.center}, fp({circ.radius}))"

export Intersection, Point, Segment, Circle

proc point*(vec: FPVec2): Point {.inline.} =
  Point.init(vec)

proc segment*(a, b: FPVec2): Segment {.inline.} =
  Segment.init(a, b)

proc circle*(center: FPVec2, radius: FPInt): Circle {.inline.} =
  ## Creates a circle with a center at `center` and a radius of `radius`
  Circle.init(center, radius)

proc intersection*(point: Point, circle: Circle): Option[FPVec2] =
  ## Returns whether the point intersects the circle
  let distanceSquared = dot(point - circle.center, point - circle.center)
  let radiusSquared = circle.radius * circle.radius
  if distanceSquared == radiusSquared:
    return some(point.FPVec2)

proc intersection*(segment: Segment, circle: Circle): Option[FPVec2] =
  ## Returns the intersection point of the segment and the circle, if it exists.
  let delta = segment.b - segment.a

  # Handle degenerate segment where it's actually a point
  if delta.x == fp(0) and delta.y == fp(0):
    return Point.init(segment.a).intersection(circle)

  let offset = segment.a - circle.center

  # Quadratic coefficients: At^2 + Bt + C = 0
  let aCoeff = dot(delta, delta)
  let bCoeff = dot(offset, delta) * 2
  let cCoeff = dot(offset, offset) - circle.radius * circle.radius

  let discrim_p1 = bCoeff.toFP64 * bCoeff.toFP64
  let discrim_p2 = aCoeff.toFP64 * cCoeff.toFP64 * 4
  let discriminant = discrim_p1 - discrim_p2

  # No intersection
  if discriminant < 0:
    return none(FPVec2)

  # Tangent case
  if discriminant == 0:
    let t = -bCoeff / (fp(2) * aCoeff)
    return
      if t >= fp(0) and t <= fp(1):
        Point.init(segment.a + delta * t).intersection(circle)
      else:
        none(FPVec2)

  let sqrtDisc = sqrt(discriminant).toInt().fp()
  let twoA = fp(2) * aCoeff

  # t1 and t2 are the parametric positions along the segment where it intersects the circle.
  # If either is within [0, 1], the intersection point lies on the segment.
  let t1 = (-bCoeff - sqrtDisc) / twoA
  let t =
    if t1 >= fp(0) and t1 <= fp(1):
      t1
    else:
      let t2 = (-bCoeff + sqrtDisc) / twoA
      if t2 >= fp(0) and t2 <= fp(1):
        t2
      else:
        # Check if either endpoint is within the circle
        let radiusSq = circle.radius * circle.radius
        if dot(segment.a - circle.center, segment.a - circle.center) < radiusSq:
          return some(segment.a)
        elif dot(segment.b - circle.center, segment.b - circle.center) < radiusSq:
          return some(segment.b)
        return none(FPVec2)

  return some(segment.a + delta * t)
