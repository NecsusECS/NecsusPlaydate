type Val*[T] = ref object ## Wrapper of a single value
  value: T

proc `:=`*[T](val: ptr Val[T] | var Val[T], value: sink T) {.inline.} =
  ## Assign a value into this val
  val.value = value

proc `<<`*[T](val: ptr Val[T] | var Val[T], value: sink T) {.inline.} =
  ## Assign a value into this val
  val.value = value

proc `==`*[T](val: ptr Val[T] | Val[T], value: T): bool {.inline.} =
  ## Assign a value into this val
  val.value == value

converter toVal*[T](value: sink T): Val[T] {.inline.} =
  ## Wraps a value in a T
  Val[T](value: value)

converter read*[T](value: Val[T] | ptr Val[T]): lent T {.inline.} =
  ## Reads the value from a Val
  value.value
