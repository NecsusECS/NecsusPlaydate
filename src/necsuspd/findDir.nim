import options, positioned, vmath, math, inputs

type
  FindDir* = enum
    FindLeft
    FindRight
    FindUp
    FindDown

  Found*[T] = tuple[pos: Positioned, value: T]

const angleRanges = [
  FindLeft: degToRad(120f) .. degToRad(240f),
  FindRight: degToRad(-60f) .. degToRad(60f),
  FindUp: degToRad(210f) .. degToRad(330f),
  FindDown: degToRad(30f) .. degToRad(150f),
]

proc isDirected(direction: FindDir, a, b: Positioned): bool =
  let angle = a.toVec2.angle(b.toVec2)
  # echo direction, " for ", b.toIVec2, " to ", a.toIVec2, " is ", angle.radToDeg
  if angle in angleRanges[direction]:
    return true
  elif angle < 0:
    return (angle + 2 * PI) in angleRanges[direction]
  return false

template asIterator(elements: untyped): untyped =
  when compiles(
    block:
      for element in elements:
        discard
  ):
    elements
  else:
    elements()

template findDir*[T](
    elements: untyped, direction: FindDir, origin: Positioned
): Option[Found[T]] =
  ## Returns the value
  var output: Option[Found[T]]
  var resultDistance: float32
  for element in asIterator(elements):
    static:
      assert(element is Found[T])
    let (pos, _) = element
    if direction.isDirected(pos, origin) and pos != origin:
      let distance = distSq(origin.toVec2, pos.toVec2).abs
      if distance > 0 and (output.isNone or distance < resultDistance):
        output = some(element)
        resultDistance = distance
  output

proc asFindDir*(button: PDButton): Option[FindDir] =
  return
    case button
    of kButtonLeft:
      some(FindLeft)
    of kButtonRight:
      some(FindRight)
    of kButtonUp:
      some(FindUp)
    of kButtonDown:
      some(FindDown)
    else:
      return none(FindDir)

template findDir*[T](
    elements: untyped, direction: PDButton, origin: Positioned
): Option[Found[T]] =
  var output: Option[Found[T]]
  for dir in direction.asFindDir:
    output = findDir[T](elements, dir, origin)
  output
