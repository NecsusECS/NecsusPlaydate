import std/[options, macrocache, strformat, macros, tables, typetraits]

const enableNames = not defined(release)

type
  UnderlyingType = uint16

  TypeId* = object
    ## A value that allows types to be compared at runtime, even if
    ## the specific name of the type isn't known
    id: UnderlyingType
    when enableNames:
      name: string

  EnumValue* = object
    ## A value for an enum that can be compared at runtime without
    ## needing to track the specific type of the enum itself
    typeId: TypeId
    ordinal: UnderlyingType
    when enableNames:
      name: string

const nextTypeId = CacheCounter("nextTypeId")

const typeIds = CacheTable("typeIdsByHash")

macro findTypeId(name: static[string], node: typedesc): untyped =
  let key = node.getTypeImpl[1].signatureHash
  if key notin typeIds:
    typeIds[key] = nextTypeId.value.UnderlyingType.newLit
    inc nextTypeId
  return typeIds[key]

proc getTypeId*(T: typedesc): TypeId =
  ## Returns the unique type ID for the geven type
  const id = findTypeId($T, T)
  result = TypeId(id: id)
  when enableNames:
    result.name = $T

proc assertIs*[T](value: T, expected: TypeId) =
  ## Assert that the enum value is of the given type
  assert(T.getTypeId == expected, fmt"{$T} is not of type {$expected}")

proc `==`*(a, b: TypeId): bool =
  a.id == b.id

proc `$`*(value: TypeId): string =
  ## Returns the string representation of the type ID
  result = fmt"TypeId#{value.id}"
  when enableNames:
    result &= ":" & value.name

proc `$`*(value: EnumValue): string =
  ## Returns the string representation of the type ID
  when enableNames:
    let basename = value.name
  else:
    let basename = $value.ordinal
  return fmt"{value.typeId}:{basename}"

proc getEnumValue*(value: enum): EnumValue =
  ## Returns the enum value for the given type and value
  result =
    EnumValue(typeId: getTypeId(typeof(value)), ordinal: ord(value).UnderlyingType)
  when enableNames:
    result.name = $value

proc ord*(value: EnumValue): int32 =
  ## Returns the ordinal value of the enum
  value.ordinal.int32

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
  let output = getAs(value, typ)
  let expected = getTypeId(typ)
  assert(output.isSome, fmt"{value} is not of type {$typ} ({expected})")
  return output.unsafeGet
