import std/[options, macrocache]

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

proc `==`*(a, b: TypeId): bool {.borrow.}

func getTypeId*(T: typedesc): TypeId =
  ## Returns the unique type ID for the geven type
  const id = typeIds.value
  static:
    typeIds.inc

  return id.int32.TypeId

func getEnumValue*(value: enum): EnumValue =
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

func getAs*(value: EnumValue, typ: typedesc[enum]): Option[typ] =
  if value.typeId == getTypeId(typ):
    return some(typ(value.ordinal))
