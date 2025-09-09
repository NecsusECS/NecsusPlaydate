import necsus, positioned, sprite, util, vmath, alignment

export alignment

type
  AutoAlignCtrl[T] = object
    findTargets: Query[(T, ptr Positioned)]
    findAnchor: Lookup[(Positioned, Sprite)]

  AutoAlign*[T] = Bundle[AutoAlignCtrl[T]]

proc align*[T](
    control: AutoAlign[T], anchor: EntityId, horizAlign, vertAlign: Alignment
) =
  ## Aligns the set of targets matched by a query for `T` to the anchor entity
  let (anchorPos, anchorSprite) = control.findAnchor(anchor).orElse:
    log "Unable to align entities because the anchor could not be found: ", anchor
    return

  let anchorAlign = alignment2d(anchorSprite, horizAlign, vertAlign)
  let newPos = anchorPos.toIVec2 + ivec2(anchorAlign.x.int32, anchorAlign.y.int32)

  for (_, targetPos) in control.findTargets:
    targetPos.pos = newPos
