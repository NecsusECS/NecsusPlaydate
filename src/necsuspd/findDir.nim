import options, positioned, vmath, math, inputs

type
  FindDir* = enum
    FindLeft
    FindRight
    FindUp
    FindDown

  Found*[T] = tuple[pos: Positioned, value: T]

const directionVectors = [
  FindLeft: vec2(-1.0f, 0.0f),
  FindRight: vec2(1.0f, 0.0f),
  FindUp: vec2(0.0f, -1.0f),
  FindDown: vec2(0.0f, 1.0f),
]

const dotThreshold = 0.5f  # cos(60°) for 120° cone

proc isDirected(direction: FindDir, a, b: Positioned): bool =
  let directionVec = directionVectors[direction]
  let positionVec = (a.toVec2 - b.toVec2).normalize()
  let dotProduct = dot(directionVec, positionVec)
  return dotProduct >= dotThreshold

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
