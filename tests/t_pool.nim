import unittest
import necsuspd/pool

type
  PooledVal = ref object
    name: string
    resetCount: int
    restoreCount: int
    id: int
    key: PoolKey

  PoolKey = enum
    A
    B
    C
    D

proc resetPooledValue(value: PooledVal) =
  require(not value.isNil)
  check(value.restoreCount == value.resetCount)
  value.resetCount += 1

proc restorePooledValue(value: PooledVal) =
  require(not value.isNil)
  check(value.restoreCount == value.resetCount - 1)
  value.restoreCount += 1

var valuesConstructed = 0

proc getValue(initialName: string): PooledVal {.pooled(2).} =
  valuesConstructed += 1
  return PooledVal(name: initialName, id: valuesConstructed)

proc checkValue(
    pair: Pooled[PooledVal], name: string, id: int, counts: int
): Pooled[PooledVal] =
  let value = pair.value
  require(not value.isNil)
  require(value.id == id)
  require(value.name == name)
  require(value.resetCount == counts)
  require(value.restoreCount == counts)
  return pair

proc checkValue(
    pair: Pooled[PooledVal], name: string, key: PoolKey, id: int, counts: int
): Pooled[PooledVal] =
  discard pair.checkValue(name, id, counts)
  require(pair.value.key == key)
  return pair

var multiValueIds = 0

proc getMulti(key: PoolKey, initialName: string): PooledVal {.multiPooled(2).} =
  multiValueIds += 1
  return PooledVal(name: initialName, key: key, id: multiValueIds)

suite "Pooling values":
  test "Creating and initially accessing values in a pool":
    check(valuesConstructed == 0)

    let (value, handle) = getValue("foo").checkValue("foo", 1, 1)
    check(valuesConstructed == 2)

    let (value2, handle2) = getValue("bar").checkValue("foo", 2, 1)
    check(valuesConstructed == 2)

  test "Using previously constructed values":
    check(valuesConstructed == 2)

    let (value, handle) = getValue("baz").checkValue("foo", 2, 2)
    check(valuesConstructed == 2)

    let (value2, handle2) = getValue("qux").checkValue("foo", 1, 2)
    check(valuesConstructed == 2)

  test "Construct additional values as needed":
    check(valuesConstructed == 2)

    let (value, handle) = getValue("baz").checkValue("foo", 1, 3)
    check(valuesConstructed == 2)

    let (value2, handle2) = getValue("qux").checkValue("foo", 2, 3)
    check(valuesConstructed == 2)

    let (value3, handle3) = getValue("hork").checkValue("hork", 3, 1)
    check(valuesConstructed == 3)

  test "Multi-pooled values":
    check(multiValueIds == 0)

    let (value, handle) = getMulti(A, "foo").checkValue("foo", A, 1, 1)
    check(multiValueIds == 2)

    let (value2, handle2) = getMulti(B, "bar").checkValue("bar", B, 3, 1)
    check(multiValueIds == 4)

    let (value3, handle3) = getMulti(A, "baz").checkValue("foo", A, 2, 1)
    check(multiValueIds == 4)

  var singletonIds = 0

  proc getSingle(name: string): PooledVal {.singleton.} =
    singletonIds += 1
    return PooledVal(name: name, id: singletonIds)

  test "Singleton value":
    check(singletonIds == 0)

    let value = getSingle("foobar")
    check(value.name == "foobar")
    check(value.id == 1)
    check(singletonIds == 1)

    let value2 = getSingle("foobar")
    check(value2.name == "foobar")
    check(value2.id == 1)
    check(singletonIds == 1)
