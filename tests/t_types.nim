import unittest, options
import ../src/necsuspd/types

# Test enums for testing purposes
type
  Color = enum
    Red
    Green
    Blue

  Size = enum
    Small
    Medium
    Large

  Direction = enum
    North
    South
    East
    West

suite "TypeId tests":
  test "TypeId equality works":
    check getTypeId(Color) == getTypeId(Color)
    check getTypeId(Size) == getTypeId(Size)

  test "Different types have different TypeIds":
    check getTypeId(Color) != getTypeId(Size)
    check getTypeId(Size) != getTypeId(Direction)
    check getTypeId(Color) != getTypeId(Direction)

  test "TypeId is consistent across calls":
    check getTypeId(Color) == getTypeId(Color)
    check getTypeId(Size) == getTypeId(Size)

  test "TypeId as string":
    check $getTypeId(Color) == "TypeId#0:Color"
    check $getTypeId(Size) == "TypeId#1:Size"
    check $getTypeId(Direction) == "TypeId#2:Direction"

suite "EnumValue tests":
  test "getEnumValue creates correct EnumValue":
    let redValue = getEnumValue(Red)
    let greenValue = getEnumValue(Green)
    let smallValue = getEnumValue(Small)

    # Values from same enum type should have same TypeId but different ordinals
    check redValue.typeId == greenValue.typeId
    check redValue.ord != greenValue.ord

    # Values from different enum types should have different TypeIds
    check redValue.typeId != smallValue.typeId

  test "EnumValue equality works correctly":
    check getEnumValue(Red) == getEnumValue(Red)
    check getEnumValue(Green) == getEnumValue(Green)
    check getEnumValue(Small) == getEnumValue(Small)

  test "EnumValue inequality works correctly":
    check getEnumValue(Red) != getEnumValue(Green)
    check getEnumValue(Red) != getEnumValue(Blue)
    check getEnumValue(Red) != getEnumValue(Small)
    check getEnumValue(Small) != getEnumValue(Medium)

  test "EnumValues from different enum types are not equal":
    check getEnumValue(Red) != getEnumValue(Small)
    check getEnumValue(Green) != getEnumValue(Medium)
    check getEnumValue(Blue) != getEnumValue(Large)

  test "assertAs returns correct value when types match":
    check getEnumValue(Red).assertAs(Color) == Red
    check getEnumValue(Small).assertAs(Size) == Small

  test "assertAs raises assertion when types don't match":
    expect(AssertionError):
      discard getEnumValue(Red).assertAs(Size)
    expect(AssertionError):
      discard getEnumValue(Small).assertAs(Color)

  test "getAs returns Some when types match":
    check getEnumValue(Red).getAs(Color) == some(Red)
    check getEnumValue(Green).getAs(Color) == some(Green)
    check getEnumValue(Blue).getAs(Color) == some(Blue)
    check getEnumValue(Small).getAs(Size) == some(Small)
    check getEnumValue(Medium).getAs(Size) == some(Medium)
    check getEnumValue(Large).getAs(Size) == some(Large)

  test "getAs returns None when types don't match":
    check getEnumValue(Red).getAs(Size) == none(Size)
    check getEnumValue(Small).getAs(Color) == none(Color)
    check getEnumValue(North).getAs(Color) == none(Color)
    check getEnumValue(Red).getAs(Direction) == none(Direction)

  test "getAs round-trip conversion works":
    for color in [Red, Green, Blue]:
      check getEnumValue(color).getAs(Color) == some(color)

    for size in [Small, Medium, Large]:
      check getEnumValue(size).getAs(Size) == some(size)

    for direction in [North, South, East, West]:
      check getEnumValue(direction).getAs(Direction) == some(direction)
