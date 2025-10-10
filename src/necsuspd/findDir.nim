import options, positioned, fpvec, math, inputs, vmath

type
  FindDir* = enum
    FindLeft
    FindRight
    FindUp
    FindDown

  Found*[T] = tuple[pos: Positioned, value: T]

const directionVectors = [
  FindLeft: fpvec2(-1, 0),
  FindRight: fpvec2(1, 0),
  FindUp: fpvec2(0, -1),
  FindDown: fpvec2(0, 1),
]

const dotThreshold = fp(0.5)  # cos(60°) for 120° cone

proc isDirected(direction: FindDir, a, b: Positioned): bool =
  let directionVec = directionVectors[direction]
  let positionVec = (a.toFPVec2 - b.toFPVec2).normalize()
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
  var resultDistance: FPInt
  for element in asIterator(elements):
    static:
      assert(element is Found[T])
    let (pos, _) = element
    if direction.isDirected(pos, origin) and pos != origin:
      let distance = (origin.toFPVec2 - pos.toFPVec2).lengthSq
      if distance > fp(0) and (output.isNone or distance < resultDistance):
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
