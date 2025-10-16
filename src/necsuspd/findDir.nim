import options, fpvec, math, inputs, vmath, util, fpvec

type
  FindDir* = enum
    FindLeft
    FindRight
    FindUp
    FindDown

  Found*[T] = tuple[pos: FPVec2, value: T]

const directionVectors = [
  FindLeft: fpvec2(-1, 0),
  FindRight: fpvec2(1, 0),
  FindUp: fpvec2(0, -1),
  FindDown: fpvec2(0, 1),
]

const dotThreshold = fp(0.15)

proc determineScore(direction: FindDir, a, b: FPVec2): Option[FPInt] =
  if a == b:
    return none(FPInt)

  let dotProduct = directionVectors[direction].dot(normalize(a - b))

  # Filter out elements outside the cone
  if dotProduct < dotThreshold:
    return none(FPInt)

  let distance = (a.toFPVec2 - b.toFPVec2).lengthSq

  # Use exponential penalty for angular deviation
  # Perfect alignment (dotProduct = 1.0) gets no penalty
  # Worse alignment gets exponentially higher penalty
  let angularDeviation = fp(1) - dotProduct
  let alignmentPenalty = fp(1) + angularDeviation * angularDeviation * fp(100)
  let score = distance * alignmentPenalty

  return some(score)

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
    elements: untyped, direction: FindDir, origin: FPVec2
): Option[Found[T]] =
  ## Returns the value
  var output: Option[Found[T]]
  var resultScore: FPInt = high(FPInt)
  for element in asIterator(elements):
    static:
      assert(element is Found[T])
    let (pos, _) = element
    direction.determineScore(pos, origin).withValue(score):
      if output.isNone or score < resultScore:
        output = some(element)
        resultScore = score
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
    elements: untyped, direction: PDButton, origin: FPVec2
): Option[Found[T]] =
  var output: Option[Found[T]]
  for dir in direction.asFindDir:
    output = findDir[T](elements, dir, origin)
  output
