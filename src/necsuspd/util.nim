import std/[macros, options, strutils, macrocache, importutils, setutils], types, import_playdate

importPlaydateApi()

export types

macro log*(args: varargs[typed]): untyped =
  ## Logs a message, assuming logging is enabled
  result = newStmtList()

  if not defined(noLogging):
    let msg = genSym(nskVar, "msg")

    result.add quote do:
      var `msg`: string

    if not defined(unittests):
      result.add quote do:
        if playdate != nil and playdate.system != nil:
          {.cast(gcsafe).}:
            `msg` &= $playdate.system.getElapsedTime()
          `msg` &= " "

    for arg in args:
      result.add quote do:
        `msg` &= $`arg`

    if defined(unittests):
      result.add quote do:
        echo `msg`
    else:
      result.add quote do:
        {.cast(gcsafe).}:
          if playdate == nil or playdate.system == nil:
            echo `msg`
          else:
            playdate.system.logToConsole(`msg`)

template orElse*[T](value: Option[T], otherwise: untyped): T =
  let resolved = value
  if resolved.isSome: resolved.get else: otherwise

template mapIt*[T](value: Option[T], action: untyped): untyped =
  block:
    type InnerType = typeof(
      (
        block:
          var it {.inject.}: typeof(value.get())
          action
      )
    )

    var result: Option[InnerType]
    if value.isSome:
      let it {.inject.} = value.get()
      result = some(action)
    result

template applyIt*[T](value: Option[T], action: untyped): void =
  block:
    if value.isSome:
      let it {.inject.} = value.get()
      action

template flatMapIt*[T](value: Option[T], action: untyped): untyped =
  block:
    type InnerType = typeof(
      (
        block:
          var it {.inject.}: typeof(value.get())
          action.get()
      )
    )

    var result: Option[InnerType]
    if value.isSome:
      let it {.inject.} = value.get()
      result = action
    result

template filterIt*[T](value: Option[T], action: untyped): Option[T] =
  block:
    var result: Option[T]
    if value.isSome:
      let it {.inject.} = value.get()
      if action:
        result = value
    result

template fallback*[T](value: Option[T], otherwise: Option[T]): Option[T] =
  block:
    var result: Option[T]
    if value.isSome:
      result = value
    else:
      result = otherwise
    result

proc next*[T: Ordinal](value: T): T =
  ## Returns the next value of an ordinal, wrapping on overflow
  if value == high(T):
    low(T)
  else:
    succ(value)

proc prev*[T: Ordinal](value: T): T =
  ## Returns the previous value, wrapping on underflow
  if value == low(T):
    high(T)
  else:
    pred(value)

proc precursors*[T: enum](value: T): set[T] =
  ## All the enum values that come before a given value
  for entry in T.low .. T.high:
    if entry >= value:
      break
    result.incl(entry)

iterator flatten*[T](source: openArray[T]): auto =
  ## Flattens an arbitrarily nested sequence
  when T isnot seq:
    for element in source:
      yield element
  else:
    for each in source:
      for e in flatten(each):
        yield e

iterator items*[T](option: Option[T]): T =
  if option.isSome:
    yield option.unsafeGet

template withValue*[T](source: Option[T], varname, ifExists: untyped) =
  ## Reads a value from an Option, assigns it to a variable, and calls `ifExists` when it is `some`.
  ## If the value is `none`, it calls `ifAbsent`.
  privateAccess(Option)
  let local {.cursor.} = source
  if local.isSome:
    template varname(): auto {.inject, used.} =
      local.val

    ifExists

template arrayRepeat*(kind: typedesc, size: static[int32], values: untyped): untyped =
  ## Repeats an array with repeated values
  var output: array[size, kind]
  for it {.inject.} in 0 ..< size:
    output[it] = values
  output

proc arrayLen(typ: NimNode): int32 =
  ## Returns the length of an array based on the type

  typ.expectKind({nnkBracketExpr})
  typ[0].expectKind({nnkSym})
  if typ[0].strVal != "array":
    error("Expecting an array", typ)

  let keys = typ[1]
  keys.expectKind({nnkBracketExpr})
  keys[0].expectKind({nnkSym})
  if keys[0].strVal != "range":
    error("Expecting an array with a ranged ", keys)
  keys[1].expectKind({nnkIntLit})
  keys[2].expectKind({nnkIntLit})
  return keys[2].intVal.int32 - keys[1].intVal.int32 + 1.int32

macro arrayConcat*(arrays: varargs[typed]): untyped =
  ## Concatenates multiple arrays
  result = nnkBracket.newTree()
  for entry in arrays:
    for i in 0 ..< (entry.getType.arrayLen):
      result.add(nnkBracketExpr.newTree(entry, i.newLit))

func removeSuffix*(input, suffix: string): string =
  ## Removes a suffix from a string
  result = input
  result.removeSuffix(suffix)

proc copy*[T](input: T): T =
  ## Copies a value
  when T is ref or T is ptr:
    if unlikely(input == nil):
      result = nil
    else:
      result = T()
      result[] = input[]
  else:
    result = input

proc extractAssignments(node: NimNode): seq[tuple[varname, vartyp, varexpr: NimNode]] =
  case node.kind
  of nnkAsgn:
    result = @[(node[0], newEmptyNode(), node[1])]
  of nnkIdentDefs:
    result = @[(node[0], node[1], node[2])]
  of nnkStmtList, nnkLetSection, nnkConstSection, nnkVarSection:
    for child in node:
      result.add(extractAssignments(child))
  else:
    node.expectKind(nnkAsgn)

macro releaseConst*(node: untyped): untyped =
  ## Converts a 'let' statement to a 'const' when release builds are enabled
  result = newTree(if defined(release): nnkConstSection else: nnkLetSection)
  let defKind = if defined(release): nnkConstDef else: nnkIdentDefs
  for (varname, vartyp, varexpr) in extractAssignments(node):
    result.add(newTree(defKind, varname, vartyp, varexpr))

template semiStaticRead*(path: string): string =
  ## Converts a readFile to a staticRead when releases are enabled
  when defined(release):
    staticRead(path)
  else:
    readFile(path)

proc `[]`*[N: Ordinal, T](
    fn: (proc(): array[N, T]) | (proc(): seq[T]), index: N
): T {.inline.} =
  ## Helper for reading an index from an array returned by a builder
  fn()[index]

proc `[]`*[N: Ordinal, T](fn: proc(): ref array[N, T], index: N): T {.inline.} =
  ## Helper for reading an index from an array returned by a builder
  fn()[][index]

template `from`*[T](variable: untyped, source: Option[T]): bool =
  ## Reads a value from an Option, assigns it to a variable, and returns boolean if the option had a 'some'
  source.isSome and (let variable: T = unsafeGet(source); true)

macro emptyEnum*(): untyped =
  ## Defines an enum without any entries
  return nnkEnumTy.newTree(newEmptyNode())

proc emptyArray*[T, V](): array[T, V] =
  ## Creates an array of a specific type without any values
  discard

template unroll*(i0, name0: untyped, iter: typed, body0: untyped): untyped =
  ## Unrolls a loop

  macro unrollImpl(i, name, body) =
    result = newStmtList()
    var j: int32 = 0
    for value in iter:
      result.add(
        newBlockStmt(
          newStmtList(
            newConstStmt(name, value.newLit), newConstStmt(i, j.newLit), body.copy()
          )
        )
      )
      j += 1

  unrollImpl(i0, name0, body0)

proc toRef*[T](value: T): ref =
  ## Converts a value to a ref
  when T is ref:
    return value
  elif T is ptr:
    return value[].toRef
  else:
    result = new(T)
    result[] = value

proc isqrt*(n: SomeInteger): SomeInteger =
  ## See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2)
  assert(n >= 0, "sqrt input should be non-negative")

  var x = n
  result = 0

  var d: int32 = 1 shl 30
  while d > n:
    d = d shr 2

  while d != 0:
    if x >= result + d:
      x -= result + d
      result = (result shr 1) + d
    else:
      result = result shr 1
    d = d shr 2

proc len*(kind: typedesc[enum]): int32 =
  ## Returns the number of entries in an enum
  const size = fullSet(kind).card.int32
  return size
