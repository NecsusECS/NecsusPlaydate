import necsus, sprite, pool, vmath, import_playdate, fpvec, positioned

const BEAM_BATCH_SIZE = 4

type
  BeamDrawProc* = proc(img: LCDBitmap, step: uint, origin, target: IVec2): bool
    ## Callback invoked each update cycle to (re)draw a beam sprite.
    ## Return true to keep the beam alive, false to delete the entity.
    ## step: monotonically increasing counter, also usable as an RNG seed;
    ## origin/target: beam endpoints in sprite-local pixel coordinates.

  BeamEvent* = object
    beamOrigin, beamTarget: FPVec2 ## world position of beam start
    draw: BeamDrawProc ## draw proc for this beam's visual style
    maskColor: LCDSolidColor ## mask color applied before the step-0 draw

proc beam*(
    origin, target: FPVec2, draw: BeamDrawProc, maskColor: LCDSolidColor = kColorBlack
): BeamEvent =
  ## Generates a BeamEvent
  BeamEvent(beamOrigin: origin, beamTarget: target, draw: draw, maskColor: maskColor)

template makeBeamPool*(
    Name: untyped,
    zIndex: typed,
    maxBeamLength: static int32,
    poolSize: static int32 = 10,
    padding: static int32 = 10,
) =
  ## Generates a complete beam effect system bound to a single sprite pool.
  ## Call once per project; firing BeamEvent invokes Name which creates the beam.
  ##
  ## Generates:
  ##   Name*            -- public eventSys; spawns a beam sprite from a BeamEvent
  ##   updateNameBeams* -- system that batch-redraws beams; deletes when draw returns false
  ##
  ## maxBeamLength and height are the image dimensions; set to max_beam_length + 2*padding (square images work best).

  type `Name BeamState` {.maxCapacity(poolSize).} = ref object
    origin, target: IVec2
    step: uint
    draw: BeamDrawProc

  proc `Name Pool`(): Sprite {.pooled(poolSize).} =
    result = newBlankSprite(maxBeamLength, maxBeamLength, zIndex, AnchorMiddle)
    discard result.getImage.setBitmapMask()

  proc `update Name Beams`*(
      tick: TickId, beams: FullQuery[(`Name BeamState`, Sprite)], delete: Delete
  ) =
    let batchId = tick() mod BEAM_BATCH_SIZE
    for eid, (beam, sprite) in beams:
      if eid.uint64 mod BEAM_BATCH_SIZE == batchId:
        let keepAlive = beam.draw(sprite.getImage, beam.step, beam.origin, beam.target)
        sprite.markDirty()
        if keepAlive:
          beam.step += 1
        else:
          delete(eid)

  proc `Name BeamLocalOrigin`(delta: IVec2): IVec2 =
    ## Returns the sprite-local origin for a beam, placing it near the image
    ## edge/corner that the beam shoots away from, based on its direction octant.
    const near = padding.int32
    const far = (maxBeamLength - padding).int32
    const half = (maxBeamLength div 2).int32
    let ax = abs(delta.x)
    let ay = abs(delta.y)
    if ax * 12 <= ay * 5: # mostly vertical: |dy|/|dx| > 2.4 ≈ 1/tan(22.5°)
      ivec2(half, if delta.y < 0: far else: near)
    elif ay * 12 <= ax * 5: # mostly horizontal
      ivec2(if delta.x > 0: near else: far, half)
    else: # diagonal
      ivec2(if delta.x > 0: near else: far, if delta.y > 0: near else: far)

  proc `Name`*(
      event: BeamEvent,
      spawn: Spawn[(`Name BeamState`, Positioned, Sprite, Handle[Sprite])],
  ) {.eventSys, depends(`update Name Beams`).} =
    let delta = toIVec2(event.beamTarget - event.beamOrigin)
    const center = ivec2(maxBeamLength div 2, maxBeamLength div 2)
    let localOrigin = `Name BeamLocalOrigin`(delta)
    let localTarget = localOrigin + delta
    let worldPos = event.beamOrigin - toFPVec2(localOrigin - center)
    let (sprite, handle) = `Name Pool`()
    sprite.getBitmapMask.clear(event.maskColor)
    let beam = `Name BeamState`(
      origin: localOrigin, target: localTarget, draw: event.draw, step: 1
    )
    discard event.draw(sprite.getImage, 0, localOrigin, localTarget)
    sprite.markDirty()
    spawn.with(beam, positioned(worldPos), sprite, handle)
