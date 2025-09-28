import std/[unittest, options], necsuspd/[aseprite, triggerBox], vmath

suite "Aseprite SpriteSheet Utilities":
  let sheet = SpriteSheet(
    frames:
      @[
        AseFrame(
          duration: 100,
          filename: "frame0.png",
          frame: (h: 32, w: 32, x: 0, y: 0),
          rotated: false,
          trimmed: false,
          sourceSize: (h: 32, w: 32),
          spriteSourceSize: (h: 32, w: 32, x: 0, y: 0),
        )
      ],
    meta: AseMeta(
      app: "aseprite",
      format: RGBA8888,
      frameTags: @[AseFrameTag(name: "Idle", direction: forward, color: "#FFFFFF")],
      image: "sprite.png",
      layers:
        @[
          AseLayer(
            blendMode: normal,
            color: "#000000",
            data: "",
            group: "",
            name: "Events",
            opacity: 255,
            cels: @[(frame: 0, data: "jump")],
          )
        ],
      scale: "1",
      size: (h: 32, w: 32),
      slices:
        @[
          AseSlice(
            color: "#FF0000",
            data: "",
            keys: @[AseSliceKey(bounds: (h: 10, w: 20, x: 5, y: 15), frame: 0)],
            name: "HitBox",
          )
        ],
      version: "1.0",
    ),
  )

  test "findTag finds tag by name":
    check sheet.findTag("Idle").isSome
    check sheet.findTag("idle").isSome
    check sheet.findTag("Missing").isNone

  test "eventFrames returns correct frames":
    let frames = sheet.eventFrames("jump")
    check frames.len == 1
    check frames[0] == 0

  test "findSlice and slice return correct slice":
    check sheet.findSlice("HitBox").isSome
    check sheet.slice("HitBox").name == "HitBox"

  test "firstKey returns first slice key":
    check sheet.slice("HitBox").firstKey(sheet).bounds ==
      (h: 10'i32, w: 20'i32, x: 5'i32, y: 15'i32)

  test "center returns correct IVec2":
    check center((h: 10'i32, w: 20'i32, x: 5'i32, y: 15'i32)) ==
      ivec2(5 + (20 div 2), 15 + (10 div 2))

  test "hitBox returns correct bounds":
    check sheet.hitBox == (h: 10'i32, w: 20'i32, x: 5'i32, y: 15'i32)

  test "anchorOffset falls back to hitBox if Anchor slice missing":
    check sheet.anchorOffset == ivec2(5 + (20 div 2), 15 + 10)

  test "sliceKeyAsOffset returns offset relative to anchor":
    check sheet.sliceKeyAsOffset("HitBox") ==
      center((h: 10'i32, w: 20'i32, x: 5'i32, y: 15'i32)) - sheet.anchorOffset

  test "animationTime returns correct duration for tag":
    type Anim = enum
      Idle

    # The Idle tag covers frame 0, which has duration 100
    check sheet.animationTime(Idle).get == 100

  test "getTriggerBox returns correct TriggerBox":
    type Z = enum
      Z0

    let tb = sheet.getTriggerBox("HitBox", Z0)
    check tb.width == 20
    check tb.height == 10
    check tb.offset == ivec2(5 - sheet.anchorOffset.x, 15 - sheet.anchorOffset.y)

  test "strideToSpeed computes correct speed":
    # Add a slice with two keys at different x positions and frames
    let strideSheet = SpriteSheet(
      frames:
        @[
          AseFrame(
            duration: 100,
            filename: "frame0.png",
            frame: (h: 32, w: 32, x: 0, y: 0),
            rotated: false,
            trimmed: false,
            sourceSize: (h: 32, w: 32),
            spriteSourceSize: (h: 32, w: 32, x: 0, y: 0),
          ),
          AseFrame(
            duration: 200,
            filename: "frame1.png",
            frame: (h: 32, w: 32, x: 0, y: 0),
            rotated: false,
            trimmed: false,
            sourceSize: (h: 32, w: 32),
            spriteSourceSize: (h: 32, w: 32, x: 0, y: 0),
          ),
        ],
      meta: AseMeta(
        app: "aseprite",
        format: RGBA8888,
        frameTags:
          @[
            AseFrameTag(
              name: "Stride", `from`: 0, to: 1, direction: forward, color: "#FFFFFF"
            )
          ],
        image: "stride.png",
        scale: "1",
        size: (h: 32, w: 32),
        slices:
          @[
            AseSlice(
              color: "#00FF00",
              data: "",
              keys:
                @[
                  AseSliceKey(bounds: (h: 10, w: 20, x: 10, y: 15), frame: 0),
                  AseSliceKey(bounds: (h: 10, w: 20, x: 30, y: 15), frame: 1),
                ],
              name: "StrideBox",
            )
          ],
        version: "1.0",
      ),
    )
    # Speed = (last.x - first.x) / totalMs * 1000 = (30 - 10) / (100 + 200) * 1000 = 20 / 300 * 1000 = 66.666...
    check abs(strideSheet.strideToSpeed("StrideBox") - 66.6667) < 0.01
