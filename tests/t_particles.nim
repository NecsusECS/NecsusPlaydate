import unittest, necsuspd/particles, stubs/graphics, vmath

proc chooseRandom(values: Slice[uint32]): uint32 =
  values.a

defineParticles(ParticleData, ParticleField, Color, Image, ImageData, chooseRandom)

suite "Particle System":
  proc emitter(ttl, spawnData, fieldData: int32): auto =
    check(spawnData == 123)
    check(fieldData == 456)
    return newParticle(3, vec2(0, 0), vec2(1, 1))

  const simpleSpawn = [
    newSpawner[int32, int32](
      2 .. 5, delay = 0, lifespan = 100, spawnData = 123, emitter
    )
  ]

  test "A particle system with a single emitter":
    let field = newField[int32, int32](simpleSpawn.allocate(), fieldData = 456)
    var image = newSprite("img", 5, 5).getImage

    field(image)
    check(image == [".XXXX", "XXXXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == ["XXXXX", "X.XXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == [".XXXX", "XXXXX", "XX.XX", "XXXXX", "XXXXX"])

    field(image)
    check(image == ["XXXXX", "X.XXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == [".XXXX", "XXXXX", "XX.XX", "XXXXX", "XXXXX"])

  test "A particle spawner with a lifespan":
    let field = newParticleField(
      int32,
      int32,
      fieldData = 456,
      [newSpawner(2 .. 5, delay = 0, lifespan = 1, spawnData = 123'i32, emitter)],
    )
    var image = newSprite("img", 5, 5).getImage

    field(image)
    check(image == [".XXXX", "XXXXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == ["XXXXX", "X.XXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == ["XXXXX", "XXXXX", "XX.XX", "XXXXX", "XXXXX"])

  test "Particles outside the field dimensions":
    proc emitter(ttl: int32, spawnData: Vec2, fieldData: int32): auto =
      newParticle(3, spawnData, vec2(0, 0))

    let field = newParticleField(
      Vec2,
      int32,
      fieldData = 0'i32,
      spawners = [
        newSpawner(2 .. 2, delay = 0, lifespan = 100, spawnData = vec2(3, 10), emitter),
        newSpawner(2 .. 2, delay = 0, lifespan = 100, spawnData = vec2(10, 3), emitter),
        newSpawner(2 .. 2, delay = 0, lifespan = 100, spawnData = vec2(3, -10), emitter),
        newSpawner(2 .. 2, delay = 0, lifespan = 100, spawnData = vec2(-10, 3), emitter),
      ],
    )
    var image = newSprite("img", 5, 5).getImage

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXXXX", "XXXXX", "XXXXX"])

  test "A particle spawner based on an input angle":
    let field = newParticleField(
      int32,
      int32,
      fieldData = 0'i32,
      spawners = [
        newSpawner(2 .. 2, delay = 0, lifespan = 100, spawnData = 0'i32) do(
          ttl, spawnData, fieldData: int32
        ) -> auto:
          newParticle(
            3 .. 3,
            vec2(3, 4),
            1.0'f32 .. 1.0'f32,
            90.0'f32 .. 90.0'f32,
            0.0'f32 .. 0.0'f32,
            0.0'f32 .. 0.0'f32,
          )
      ],
    )
    var image = newSprite("img", 5, 5).getImage

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXXXX", "XXXXX", "XXX.X"])

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXXXX", "XXX.X", "XXXXX"])

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXX.X", "XXXXX", "XXX.X"])

  test "A delayed particle spawner":
    let field = newParticleField(
      int32,
      int32,
      fieldData = 0'i32,
      spawners = [
        newSpawner(1 .. 1, delay = 2, lifespan = 3, spawnData = 0'i32) do(
          ttl, spawnData, fieldData: int32
        ) -> auto:
          newParticle(3, vec2(0, 0), vec2(1, 1))
      ],
    )
    var image = newSprite("img", 5, 5).getImage

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == [".XXXX", "XXXXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == [".XXXX", "X.XXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == [".XXXX", "X.XXX", "XX.XX", "XXXXX", "XXXXX"])

    field(image)
    check(image == ["XXXXX", "X.XXX", "XX.XX", "XXXXX", "XXXXX"])

  test "A spawner with a TTL":
    let field = newParticleField(
      int32,
      int32,
      fieldData = 0'i32,
      spawners = [
        newSpawner(1 .. 1, delay = 1, lifespan = 3, spawnData = 0'i32) do(
          ttl, spawnData, fieldData: int32
        ) -> auto:
          newParticle(3, vec2(0, float32(ttl + 2)), vec2(1, 0))
      ],
    )

    var image = newSprite("img", 5, 5).getImage

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXXXX", "XXXXX", "XXXXX"])

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXXXX", "XXXXX", ".XXXX"])

    field(image)
    check(image == ["XXXXX", "XXXXX", "XXXXX", ".XXXX", "X.XXX"])

    field(image)
    check(image == ["XXXXX", "XXXXX", ".XXXX", "X.XXX", "XX.XX"])

    field(image)
    check(image == ["XXXXX", "XXXXX", "X.XXX", "XX.XX", "XXXXX"])

  test "SpawnData and FieldData":
    type XCoord = distinct float32
    type YCoord = distinct float32

    proc dataEmitter(ttl: int32, spawnData: XCoord, fieldData: YCoord): Particle =
      newParticle(3, vec2(spawnData.float32, fieldData.float32), vec2(0, 1))

    let spawners = [
      newSpawner(2 .. 2, delay = 0, lifespan = 3, spawnData = XCoord(1.0), dataEmitter),
      newSpawner(2 .. 2, delay = 0, lifespan = 3, spawnData = XCoord(2.0), dataEmitter),
      newSpawner(2 .. 2, delay = 0, lifespan = 3, spawnData = XCoord(3.0), dataEmitter),
    ]

    block:
      let field = newParticleField(XCoord, YCoord, fieldData = YCoord(1.0), spawners)
      var image = newSprite("img", 5, 5).getImage

      field(image)
      check(image == ["XXXXX", "X...X", "XXXXX", "XXXXX", "XXXXX"])

    block:
      let field = newParticleField(XCoord, YCoord, fieldData = YCoord(0.0), spawners)
      var image = newSprite("img", 5, 5).getImage

      field(image)
      check(image == ["X...X", "XXXXX", "XXXXX", "XXXXX", "XXXXX"])
