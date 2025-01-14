import vmath, sequtils, std/importutils, util, vec_tools, rand

type
    Particle* = object
        ## An individual particle being rendered
        location: IVec2
        velocity: IVec2
        acceleration: IVec2
        lifespan: int32

    ParticleProc*[S, F] = proc(ttl: int32, spawnData: S, fieldData: F): Particle {.nimcall.}
        ## Callback to generate a single particle

    ParticleSpawner*[S, F] = object
        ## Determines the rules for spawning a new particle
        initialDelay: int32
        rate: Slice[uint32]
        nextParticle: int32
        lifespan, initialLifespan: int32
        spawnData: S
        emitter: ParticleProc[S, F]

    GetRandom = proc (values: Slice[uint32]): uint32

proc maxParticleCount(spawners: openarray[ParticleSpawner]): int32 =
    for spawner in spawners:
        result += (spawner.lifespan + 1) div spawner.rate.a.int32

const SHIFT_RES = 7

proc applyResolution(vec: IVec2 | Vec2): IVec2 =
    when vec is IVec2:
        return ivec2(vec.x shl SHIFT_RES, vec.y shl SHIFT_RES)
    else:
        const RESOLUTION = 2 ^ SHIFT_RES
        return toIVec2(vec * vec2(RESOLUTION.float32, RESOLUTION.float32))

proc newParticle*(lifespan: int32; location, velocity: Vec2 | IVec2; acceleration: Vec2 | IVec2 = vec2(0, 0)): Particle =
    ## Creates a single particle
    Particle(
        lifespan: lifespan,
        location: location.applyResolution,
        velocity: velocity.applyResolution,
        acceleration: acceleration.applyResolution
    )

proc asVec2(speed: Slice[SomeNumber], degrees: Slice[SomeNumber]): Vec2 =
    speedAngleVec(random().rand(speed), random().rand(degrees))

proc newParticle*(
    lifespan: Slice[SomeInteger],
    location: Vec2 | IVec2,
    velSpeed: Slice[float32],
    velDegrees: Slice[float32],
    accelSpeed: Slice[float32],
    accelDegrees: Slice[float32],
): Particle =
    ## Creates a new particle from an angle range and a velocity
    newParticle(
        random().rand(lifespan).int32,
        location.toVec2,
        asVec2(velSpeed, velDegrees),
        asVec2(accelSpeed, accelDegrees)
    )

proc reset(spawner: var ParticleSpawner) =
    spawner.nextParticle = spawner.initialDelay + 1
    spawner.lifespan = spawner.initialLifespan

proc newSpawner*[S, F](
    rate: Slice[SomeInteger],
    delay, lifespan: int32,
    spawnData: S = default(S),
    emitter: ParticleProc[S, F]
): ParticleSpawner[S, F] =
    ## Creates a particle spawner
    result = ParticleSpawner[S, F](
        rate: rate.a.uint32..rate.b.uint32,
        emitter: emitter,
        initialDelay: delay,
        spawnData: spawnData,
        initialLifespan: lifespan + delay
    )
    result.reset

proc update(particle: var Particle) =
    particle.velocity += particle.acceleration
    particle.location += particle.velocity

template forEachDeleting(list: typed; i, code: untyped): untyped =
    ## Iterates through a list of values and executes a block of code, deleting any thing that returns false
    var i = 0
    while i < list.len:
        if list[i].lifespan > 0:
            list[i].lifespan -= 1
            code
            i += 1
        else:
            list[i] = list.pop()

template defineParticles*(
    ParticleData, ParticleField: untyped;
    LCDSolidColor, LCDBitmap, BitmapDataObj: typedesc;
    nextRandom: GetRandom
) =

    type
        ParticleDataObj[S; F] = object
            ## Pre-allocated data
            spawners: seq[ParticleSpawner[S, F]]
            particles: seq[Particle]

        ParticleData*[S; F] = ref ParticleDataObj[S, F]

        ParticleField* = proc(image: var LCDBitmap): void
            ## A callbck that runs a single tick within a particle field

    proc `=copy`[S, F](a: var ParticleDataObj[S, F], b: ParticleDataObj[S, F]) {.error.}

    proc resetPooledValue*(data: ParticleData) =
        discard

    proc restorePooledValue*(data: ParticleData) =
        data.particles.setLen(0)
        for spawner in data.spawners.mitems:
            spawner.nextParticle = spawner.initialDelay + 1
            spawner.lifespan = spawner.initialLifespan

    proc setPixel(field: var BitmapDataObj, particle: var Particle) =
        let x = particle.location.x shr SHIFT_RES
        let y = particle.location.y shr SHIFT_RES
        const color: LCDSolidColor = LCDSolidColor.kColorWhite
        field.setPixel(x.int, y.int, color)

    proc runParticles(particles: var seq[Particle], field: var BitmapDataObj) =
        forEachDeleting(particles, i):
            particles[i].update()
            setPixel(field, particles[i])

    proc runSpawn[S; F](
        fieldData: F,
        spawners: var seq[ParticleSpawner[S, F]],
        particles: var seq[Particle],
        field: var BitmapDataObj
    ) =
        privateAccess(ParticleSpawner)
        privateAccess(Particle)
        for spawner in spawners.mitems:
            if spawner.lifespan > 0:
                spawner.nextParticle -= 1
                spawner.lifespan -= 1

                if spawner.nextParticle <= 0:
                    spawner.nextParticle = nextRandom(spawner.rate).int32
                    var particle: Particle = spawner.emitter(spawner.lifespan, spawner.spawnData, fieldData)
                    setPixel(field, particle)
                    particle.lifespan -= 1

                    assert(particles.len < particles.capacity)
                    particles.add(particle)

    proc allocate*[S, F](spawners: openArray[ParticleSpawner[S, F]];): ParticleData[S, F] =
        return ParticleData[S, F](
            spawners: spawners.toSeq,
            particles: newSeqOfCap[Particle](spawners.maxParticleCount)
        )

    proc newField*[S; F](data: ParticleData[S, F], fieldData: F): ParticleField =
        ## Returns a particle runner
        var data = data
        return proc(img: var LCDBitmap) =
            clear(img, LCDSolidColor.kColorBlack)
            var dataObj = img.getDataObj()
            runParticles(data.particles, dataObj)
            runSpawn[S, F](fieldData, data.spawners, data.particles, dataObj)

            # for row in field:
            #     var rowStr: string
            #     for pixel in row:
            #         case pixel:
            #         of LCDSolidColor.kColorBlack: rowStr &= "X"
            #         of LCDSolidColor.kColorWhite: rowStr &= "."
            #         else: rowStr &= " "
            #     echo rowStr
            # echo ""

    proc newParticleField*(
        S, F: typedesc,
        fieldData: F;
        spawners: openArray[ParticleSpawner[S, F]]
    ): ParticleField =
        let alloced = allocate(spawners)
        newField[S, F](alloced, fieldData)

when not defined(unittests):
    import playdate/api, sprite, necsus

    proc nextRandom(values: Slice[uint32]): uint32 = random().rand(values)

    proc setPixel*(view: var BitmapView, x, y: int, color: LCDSolidColor) {.inline.} =
        set(view, x, y, color)

    defineParticles(ParticleData, ParticleField, LCDSolidColor, LCDBitmap, BitmapDataObj, nextRandom)

    proc updateParticles*(particles: Query[(Sprite, ParticleField)]) =
        for (sprite, particle) in particles:
            var image = sprite.getBitmapMask
            particle(image)
            sprite.markDirty