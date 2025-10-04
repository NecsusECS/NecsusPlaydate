import std/[options, macrocache, strformat, macros, tables]

type
  TypeId* = distinct int32
    ## A value that allows types to be compared at runtime, even if
    ## the specific name of the type isn't known

  EnumValue* = object
    ## A value for an enum that can be compared at runtime without
    ## needing to track the specific type of the enum itself
    typeId: TypeId
    ordinal: int32

const typeIds = CacheCounter("typeIds")

when not defined(release):
  var runtimeTypeIdNames: Table[int32, string]

proc `==`*(a, b: TypeId): bool {.borrow.}

proc getTypeId*(T: typedesc): TypeId =
  ## Returns the unique type ID for the geven type
  const id = typeIds.value.int32
  static:
    typeIds.inc

  when declared(runtimeTypeIdNames):
    runtimeTypeIdNames[id] = $T

  return id.TypeId

proc `$`*(value: TypeId): string =
  ## Returns the string representation of the type ID
  let id = value.int32
  when declared(runtimeTypeIdNames):
    if runtimeTypeIdNames.hasKey(id):
      return runtimeTypeIdNames[id]
  return fmt"TypeId#{id}"

proc `$`*(value: EnumValue): string =
  ## Returns the string representation of the type ID
  fmt"{value.typeId}@{value.ordinal}"

proc getEnumValue*(value: enum): EnumValue =
  ## Returns the enum value for the given type and value
  EnumValue(typeId: getTypeId(typeof(value)), ordinal: ord(value).int32)

proc ord*(value: EnumValue): int32 =
  ## Returns the ordinal value of the enum
  value.ordinal

proc typeId*(value: EnumValue): TypeId =
  ## Returns the type ID of the enum value
  value.typeId

func `==`*(a, b: EnumValue): bool =
  ## Compare two enum values for equality
  a.typeId == b.typeId and a.ordinal == b.ordinal

proc getAs*(value: EnumValue, typ: typedesc[enum]): Option[typ] =
  if value.typeId == getTypeId(typ):
    return some(typ(value.ordinal))

proc assertAs*(value: EnumValue, typ: typedesc[enum]): typ =
  ## Assert that the enum value is of the given type
  let value = getAs(value, typ)
  assert(value.isSome, fmt"{value} is not of type {$typ}")
  return value.unsafeGet
