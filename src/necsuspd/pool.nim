import necsus, std/[macros, strutils, strformat, deques]

when defined(simulator) or defined(playdate):
  import playdate/api

  template log(message: string) =
    when defined(poolLogging):
      logToConsole(playdate.system, message)

else:
  template log(message: string) =
    when defined(poolLogging):
      echo message

type
  ObjReset*[T: ref] = proc(obj: T) {.nimcall.}

  PoolStorage[T: ref] = object
    data: Deque[T]
    isInitialized: bool

  HandleObj[T: ref] = object
    returnPool*: ptr PoolStorage[T]
    value*: T
    reset*: ObjReset[T]

  Handle*[T: ref] = ref HandleObj[T]
    ## When this value is destroyed, the associated value will be added back to the pool

  Pooled*[T: ref] = tuple[value: T, handle: Handle[T]]

proc address(value: ref): string =
  "0x" & cast[uint64](addr value[]).toHex

proc `=destroy`[T](obj: HandleObj[T]) {.warning[Effect]: off.} =
  if obj.returnPool == nil:
    log("Dropping pooled overflow " & $T & ": " & obj.value.address)
    `=destroy`(obj.value)
  else:
    obj.returnPool[].data.addLast(obj.value)
    obj.reset(obj.value)
    log("Returning pooled " & $T & ": " & obj.value.address)

macro findResetSym(value: typed): untyped =
  ## In order to bind to the correct symbol, nim needs to resolve an actually function call. Otherwise,
  ## it gets goofy with aliases.
  value.expectKind({nnkCall})
  return value[0]

proc prepareApis(
    def, objType: NimNode
): tuple[builderImpl, callBuilder, poolingProc: NimNode] =
  ## Creates a builder proc that actually constructs new values for the pool
  let builderName = genSym(nskProc, "objBuilder")

  let builderImpl = def.copyNimTree()
  builderImpl[0] = builderName

  var poolingProc = newProc(def.name)
  var callBuilder = newCall(builderName)

  for variable in def.params[1 ..^ 1]:
    variable.expectKind(nnkIdentDefs)
    let param = genSym(nskParam, variable[0].strVal)
    poolingProc.params.add(nnkIdentDefs.newTree(param, variable[1], variable[2]))
    callBuilder.add(param)

  return (builderImpl, callBuilder, poolingProc)

proc setPooledReturnType(poolingProc, objType: NimNode) =
  poolingProc.params[0] = nnkBracketExpr.newTree(bindSym("Pooled"), objType)

proc logPooledAction*[T](value: T, action, name: string) =
  log(fmt"{action} pooled {name} {$T} " & value.address)

proc readFromPool(name, storage, objType, size, callBuilder: NimNode): NimNode =
  ## Creates the body of a proc that knows how to read a pooled value or construct a new value
  return quote:
    let reset = findResetSym(resetPooledValue(result.value))

    if unlikely(not `storage`.isInitialized):
      `storage`.isInitialized = true
      `storage`.data = initDeque[`objType`](`size`)
      for _ in 0 ..< `size`:
        var built = `callBuilder`
        reset(built)
        `storage`.data.addLast(built)
        built.logPooledAction("Created", `name`)

    result.handle = Handle[`objType`](reset: reset)

    if `storage`.data.len > 0:
      result.value = popFirst(`storage`.data)
      result.value.logPooledAction("Popped", `name`)
      result.handle.returnPool = addr `storage`
    else:
      result.value = `callBuilder`
      reset(result.value)
      result.value.logPooledAction("Created", `name`)

    assert(not result.value.isNil)

    restorePooledValue(result.value)

    result.handle.value = result.value

macro pooled*(size: int32, def: typed): untyped =
  ## Creates an object pool with the result of this function
  def.expectKind(nnkProcDef)

  var objType = def.params[0]
  var storage = genSym(nskVar, "poolStorage")

  var (builderImpl, callBuilder, poolingProc) = prepareApis(def, objType)

  poolingProc.setPooledReturnType(objType)
  poolingProc.body =
    readFromPool(def.name.strVal.newLit, storage, objType, size, callBuilder)

  result = quote:
    `builderImpl`
    var `storage`: PoolStorage[`objType`]
    `poolingProc`

  # echo result.repr

macro multiPooled*(size: int32, def: typed): untyped =
  def.expectKind(nnkProcDef)

  var objType = def.params[0]
  var storage = genSym(nskVar, "poolStorage")

  var (builderImpl, callBuilder, poolingProc) = prepareApis(def, objType)

  if def.params.len < 1:
    def.params.expectLen(2)

  poolingProc.params[1].expectKind(nnkIdentDefs)
  let keyType = poolingProc.params[1][1]
  let keySym = poolingProc.params[1][0]

  let poolName = def.name.strVal.newLit
  let readName = quote:
    `poolName` & "[" & $`keySym` & "]"

  poolingProc.setPooledReturnType(objType)
  poolingProc.body = readFromPool(
    readName, nnkBracketExpr.newTree(storage, keySym), objType, size, callBuilder
  )

  result = quote:
    `builderImpl`
    var `storage`: array[`keyType`, PoolStorage[`objType`]]
    `poolingProc`

  # echo result.repr

macro singleton*(def: typed): untyped =
  def.expectKind(nnkProcDef)

  var objType = def.params[0]
  var (builderImpl, callBuilder, singletonProc) = prepareApis(def, objType)
  singletonProc.params[0] = objType

  var storage = genSym(nskVar, "singletonStorage")
  var isSet = genSym(nskVar, "isSet")

  singletonProc.body = quote:
    if unlikely(not `isSet`):
      `storage` = `callBuilder`
      `isSet` = true
    return `storage`

  result = quote:
    `builderImpl`
    var `storage`: `objType`
    var `isSet`: bool
    `singletonProc`

  # echo result.repr
