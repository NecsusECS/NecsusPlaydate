import necsus, positioned, util, vmath, alignment, std/options

when defined(unittests):
  import ../../tests/stubs/graphics
else:
  import sprite

export alignment

type
  AutoAlignCtrl[T] = object
    findTargets: Query[(T, ptr Positioned)]
    findAnchorSprite: Lookup[(Positioned, Sprite)]
    findAnchorAnim: Lookup[(Positioned, Animation)]

  AutoAlign*[T] = Bundle[AutoAlignCtrl[T]]

proc resolveAnchor(
    control: AutoAlign, anchor: EntityId
): Option[tuple[pos: Positioned, width, height: int32]] =
  for (pos, entity) in control.findAnchorSprite(anchor).items:
    return some((pos, entity.width.int32, entity.height.int32))
  for (pos, entity) in control.findAnchorAnim(anchor).items:
    return some((pos, entity.width.int32, entity.height.int32))

proc align*[T](
    control: AutoAlign[T], anchor: EntityId, horizAlign, vertAlign: Alignment
) =
  ## Aligns the set of targets matched by a query for `T` to the anchor entity
  let details = control.resolveAnchor(anchor).orElse:
    log "Unable to align entities because the anchor could not be found: ", anchor
    return

  let anchorAlign = alignment2d(details, horizAlign, vertAlign)
  let newPos = details.pos.toIVec2 + ivec2(anchorAlign.x.int32, anchorAlign.y.int32)

  for (_, targetPos) in control.findTargets:
    targetPos.pos = newPos
