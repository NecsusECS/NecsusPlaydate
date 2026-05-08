import std/options

type Either*[L, R] = object
  case isLeft*: bool
  of true:
    leftVal: L
  of false:
    rightVal: R

func left*[L](val: L, R: typedesc): Either[L, R] {.inline.} =
  Either[L, R](isLeft: true, leftVal: val)

func left*[L, R](val: L): Either[L, R] {.inline.} =
  left[L](val, R)

func right*[R](L: typedesc, val: R): Either[L, R] {.inline.} =
  Either[L, R](isLeft: false, rightVal: val)

func right*[L, R](val: R): Either[L, R] {.inline.} =
  right[R](L, val)

func isRight*[L, R](either: Either[L, R]): bool =
  not either.isLeft

func getLeft*[L, R](either: Either[L, R]): L =
  assert either.isLeft, "Either.getLeft called on a Right value"
  either.leftVal

func getRight*[L, R](either: Either[L, R]): R =
  assert not either.isLeft, "Either.getRight called on a Left value"
  either.rightVal

template leftOr*[L, R](either: Either[L, R], otherwise: L): L =
  if either.isLeft: either.leftVal else: otherwise

template leftOr*[L, R](either: Either[L, R]): L =
  leftOr(either, default(L))

template rightOr*[L, R](either: Either[L, R], otherwise: R): R =
  if either.isRight: either.rightVal else: otherwise

template rightOr*[L, R](either: Either[L, R]): R =
  rightOr(either, default(R))

template applyLeft*[L, R](either: Either[L, R], body: untyped) =
  ## Executes `body` with `it` bound to the left value when the Either is Left
  if either.isLeft:
    let it {.inject.} = either.leftVal
    body

template applyRight*[L, R](either: Either[L, R], body: untyped) =
  ## Executes `body` with `it` bound to the right value when the Either is Right
  if either.isRight:
    let it {.inject.} = either.rightVal
    body

template apply*[L, R](either: Either[L, R], ifLeft, ifRight: untyped): untyped =
  ## Returns `ifLeft` or `ifRight` depending on which side is present.
  ## Use `either.getLeft` / `either.getRight` inside the expressions.
  if either.isLeft:
    let it {.inject.} = either.leftVal
    ifLeft
  else:
    let it {.inject.} = either.rightVal
    ifRight

template apply*[L, R](either: Either[L, R], body: untyped): untyped =
  ## Applies the same body, but with the left or right value
  apply(either, body, body)

func toOption*[L, R](either: Either[L, R]): Option[R] =
  if either.isRight:
    some(either.rightVal)
  else:
    none(R)
