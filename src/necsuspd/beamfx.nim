import necsus, sprite, pool, vmath, import_playdate, fpvec, positioned

const BEAM_BATCH_SIZE = 4

type
  BeamDrawProc* =
    proc(img: LCDBitmap, step: uint, origin: IVec2, target: IVec2): bool
    ## Callback invoked each update cycle to (re)draw a beam sprite.
    ## Return true to keep the beam alive, false to delete the entity.
    ## step: monotonically increasing counter, also usable as an RNG seed;
    ## origin/target: beam endpoints in sprite-local pixel coordinates.

  BeamEvent* = object
    beamOrigin, beamTarget: FPVec2 ## world position of beam start
    draw: BeamDrawProc ## draw proc for this beam's visual style
    maskColor: LCDSolidColor ## mask color applied before the step-0 draw

proc beam*(origin, target: FPVec2, draw: BeamDrawProc, maskColor: LCDSolidColor = kColorBlack): BeamEvent =
  ## Generates a BeamEvent
  BeamEvent(beamOrigin: origin, beamTarget: target, draw: draw, maskColor: maskColor)

template makeBeamPool*(
    Name: untyped,
    poolSize: static int32,
    width, height: static int32,
    zIndex: typed,
) =
  ## Generates a complete beam effect system bound to a single sprite pool.
  ## Call once per project; firing BeamEvent invokes Name which creates the beam.
  ##
  ## Generates:
  ##   Name*            -- public eventSys; spawns a beam sprite from a BeamEvent
  ##   updateNameBeams* -- system that batch-redraws beams; deletes when draw returns false

  type `Name BeamState` {.maxCapacity(poolSize).} = ref object
    origin, target: IVec2
    step: uint
    draw: BeamDrawProc

  proc `Name Pool`(): Sprite {.pooled(poolSize).} =
    result = newBlankSprite(width, height, zIndex, AnchorMiddle)
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

  proc `Name`*(
      event: BeamEvent,
      spawn: Spawn[(`Name BeamState`, Positioned, Sprite, Handle[Sprite])],
  ) {.eventSys, depends(`update Name Beams`).} =
    let worldPos = (event.beamOrigin + event.beamTarget) / fp(2)
    let center = ivec2(width div 2, height div 2)
    let localOrigin = toIVec2(event.beamOrigin - worldPos) + center
    let localTarget = toIVec2(event.beamTarget - worldPos) + center
    let (sprite, handle) = `Name Pool`()
    sprite.getBitmapMask.clear(event.maskColor)
    let beam = `Name BeamState`(
      origin: localOrigin, target: localTarget, draw: event.draw, step: 1
    )
    discard event.draw(sprite.getImage, 0, localOrigin, localTarget)
    sprite.markDirty()
    spawn.with(beam, positioned(worldPos), sprite, handle)
