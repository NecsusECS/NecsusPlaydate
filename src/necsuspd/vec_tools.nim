import vmath, bumpy

proc toIVec2*(input: Vec2 | DVec2): IVec2 =
  ivec2(input.x.round.toInt.int32, input.y.round.toInt.int32)

proc toVec2*(vec: IVec2 | Vec2): Vec2 =
  when (vec is Vec2):
    vec
  else:
    vec2(vec.x.float32, vec.y.float32)

proc `*`*(a: IVec2, b: float32): IVec2 =
  (a.toVec2 * b).toIVec2

proc speedAngleVec*(speed: SomeNumber, degrees: SomeNumber): Vec2 =
  dir(degrees.float32.toRadians) * vec2(1, -1) * speed.float32

proc sqDistance*(point: Vec2, rect: Rect): float32 =
  ## Determines how far a point is from a rectangle
  let dx = min((rect.x - point.x) ^ 2, (point.x - (rect.x + rect.w)) ^ 2)
  let dy = min((rect.y - point.y) ^ 2, (point.y - (rect.y + rect.h)) ^ 2)
  return dx + dy
