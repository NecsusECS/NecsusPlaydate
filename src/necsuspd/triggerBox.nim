import necsus, vmath, positioned, vec_tools, bumpy, strformat, util

const enableDebugSprite = defined(simulator) and not defined(disableDebugSprite)

when enableDebugSprite:
  import sprite, playdate/api

type
  TriggerKind = enum
    TriggerBoxKind
    TriggerJoinKind

  TriggerBox* = object
    case kind: TriggerKind
    of TriggerBoxKind:
      offset: IVec2
      dimens: IVec2
      when enableDebugSprite:
        debugSprite: Sprite
    of TriggerJoinKind:
      a, b: ref TriggerBox

  AnyTriggerBox* = TriggerBox | ptr TriggerBox | ref TriggerBox

  DebugTriggers*[T] = proc(triggers: Query[(ptr T, Positioned)])

  OverlapBoxPtr* = tuple[box: ptr TriggerBox, pos: Positioned]

  OverlapBox* = tuple[box: TriggerBox, pos: Positioned]

  AnyOverlapBox* = OverlapBox | OverlapBoxPtr

  BoxBounds* = tuple[minX, maxX, minY, maxY: int32]

proc `$`*(box: AnyTriggerBox): string =
  case box.kind
  of TriggerBoxKind:
    return fmt"Box(dimens: {box.dimens}, offset: {box.offset})"
  of TriggerJoinKind:
    return fmt"Join{box.a}, {box.b})"

proc bounds*(trigger: AnyTriggerBox): BoxBounds =
  case trigger.kind
  of TriggerBoxKind:
    return (
      minX: trigger.offset.x,
      maxX: trigger.offset.x + trigger.dimens.x,
      minY: trigger.offset.y,
      maxY: trigger.offset.y + trigger.dimens.y,
    )
  of TriggerJoinKind:
    let a = trigger.a.bounds
    let b = trigger.b.bounds
    return (
      minX: min(a.minX, b.minX),
      maxX: max(a.maxX, b.maxX),
      minY: min(a.minY, b.minY),
      maxY: max(a.maxY, b.maxY),
    )

proc height*(bounds: BoxBounds): int32 =
  bounds.maxY - bounds.minY

proc height*(trigger: AnyTriggerBox): int32 =
  trigger.bounds.height

proc width*(bounds: BoxBounds): int32 =
  bounds.maxX - bounds.minX

proc width*(trigger: AnyTriggerBox): int32 =
  trigger.bounds.width

proc offset*(bounds: BoxBounds): IVec2 =
  ivec2(bounds.minX, bounds.minY)

proc offset*(trigger: AnyTriggerBox): IVec2 =
  trigger.bounds.offset

proc dimens*(bounds: BoxBounds): IVec2 =
  ivec2(bounds.width, bounds.height)

proc tLocation*(box: AnyOverlapBox, point: IVec2): Vec2 =
  # Calculates the percentage position of a point as it exists within a trigger box
  let bounds = box[0].bounds
  let relPos = point - box[1].toIVec2 - bounds.offset
  result = relPos.toVec2 / bounds.dimens.toVec2

proc triggerBox*(
    width, height: SomeInteger, zIndex: enum, offset: IVec2 = ivec2(0, 0)
): TriggerBox =
  result = TriggerBox(
    kind: TriggerBoxKind, dimens: ivec2(width.int32, height.int32), offset: offset
  )
  when enableDebugSprite:
    result.debugSprite =
      newBlankSprite(width, height, zIndex, AnchorTopLeft, kColorClear)

proc join*(a, b: AnyTriggerBox): TriggerBox =
  ## Combines two trigger boxes into one
  TriggerBox(kind: TriggerJoinKind, a: a.toRef, b: b.toRef)

proc rect(box: AnyTriggerBox, pos: Positioned): auto =
  ## Returns the exact rectangle for this trigger box
  let bounds = box.bounds
  let dimens = ivec2(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY).toVec2
  let offset = ivec2(bounds.minX, bounds.minY).toVec2
  return rect(pos.toVec2 + offset, dimens)

proc rect*(overlap: AnyOverlapBox): auto =
  ## Produce a rectangle that encompases all the trigger boxes
  rect(overlap[0], overlap[1])

proc overlaps[A: AnyTriggerBox, B: AnyTriggerBox](
    aBox: A, bBox: B, aPos, bPos: Positioned
): bool =
  ## Whether two trigger boxes overlap
  case aBox.kind
  of TriggerBoxKind:
    case bBox.kind
    of TriggerBoxKind:
      return overlaps(rect(aBox, aPos), rect(bBox, bPos))
    of TriggerJoinKind:
      return overlaps(aBox, bBox.a, aPos, bPos) or overlaps(aBox, bBox.b, aPos, bPos)
  of TriggerJoinKind:
    return overlaps(aBox.a, bBox, aPos, bPos) or overlaps(aBox.b, bBox, aPos, bPos)

proc overlaps[A: AnyTriggerBox, B](aBox: A, aPos: Positioned, b: B): bool =
  ## Whether some shape overlaps this trigger box
  when B is AnyOverlapBox:
    return overlaps(aBox, b[0], aPos, b[1])
  else:
    case aBox.kind
    of TriggerBoxKind:
      return overlaps(b, rect(aBox, aPos))
    of TriggerJoinKind:
      return overlaps(aBox.a, aPos, b) or overlaps(aBox.b, aPos, b)

proc overlaps*[A: AnyOverlapBox, B](a: A, b: B): bool =
  ## Whether some shape overlaps this trigger box
  return overlaps(a[0], a[1], b)

when enableDebugSprite:
  proc updateTriggerSprite(box: auto, pos: Positioned) {.used.} =
    case box.kind
    of TriggerJoinKind:
      updateTriggerSprite(box.a, pos)
      updateTriggerSprite(box.b, pos)
    of TriggerBoxKind:
      let bounds = rect(box, pos)
      let rectangle = PDRect(
        x: bounds.x.float32 + (bounds.w / 2),
        y: bounds.y.float32 + (bounds.h / 2),
        width: bounds.w.float32,
        height: bounds.h.float32,
      )
      `collideRect=`(box.debugSprite, rectangle)

template triggerDebugSystem*(name: untyped, TriggerBoxType: typedesc) =
  proc `name`*(triggers: Query[tuple[box: ptr TriggerBoxType, pos: Positioned]]) =
    when enableDebugSprite:
      for (box, pos) in triggers:
        updateTriggerSprite(box, pos)
