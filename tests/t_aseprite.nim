import std/[unittest, options], necsuspd/[aseprite, triggerBox], vmath

# Helper for creating an AseFrame
proc makeAseFrame(
    duration: int32 = 100,
    filename: string = "frame0.png",
    frame: AseRectangle = (h: 32'i32, w: 32'i32, x: 0'i32, y: 0'i32),
    rotated: bool = false,
    trimmed: bool = false,
    sourceSize: AseSize = (h: 32'i32, w: 32'i32),
    spriteSourceSize: AseRectangle = (h: 32'i32, w: 32'i32, x: 0'i32, y: 0'i32),
): AseFrame =
  AseFrame(
    duration: duration,
    filename: filename,
    frame: frame,
    rotated: rotated,
    trimmed: trimmed,
    sourceSize: sourceSize,
    spriteSourceSize: spriteSourceSize,
  )

# Helper for creating an AseLayer
proc makeAseLayer(
    blendMode: AseBlendMode = normal,
    color: string = "#000000",
    data: string = "",
    group: string = "",
    name: string = "Events",
    opacity: int32 = 255,
    cels: seq[AseCel] = @[(frame: 0, data: "jump")],
): AseLayer =
  AseLayer(
    blendMode: blendMode,
    color: color,
    data: data,
    group: group,
    name: name,
    opacity: opacity,
    cels: cels,
  )

# Helper for creating an AseSliceKey
proc makeAseSliceKey(h: int = 10, w: int = 20, x: int = 5, y: int = 15): AseSliceKey =
  AseSliceKey(bounds: (h: h.int32, w: w.int32, x: x.int32, y: y.int32), frame: 0)
    # frame will be set by makeAseSlice

# Helper for creating an AseSlice (now uses varargs for keys)
proc makeAseSlice(
    name: string = "HitBox",
    color: string = "#FF0000",
    data: string = "",
    keys: varargs[AseSliceKey],
): AseSlice =
  result = AseSlice(name: name, color: color, data: data, keys: @[])
  for i, k in keys:
    result.keys.add(AseSliceKey(bounds: k.bounds, frame: i.int32))

# Convenience helper for a single-key slice (legacy)
proc makeAseSliceWithKey(
    name: string = "HitBox",
    bounds: tuple[h, w, x, y: int] = (h: 10, w: 20, x: 5, y: 15),
    frame: int32 = 0,
    color: string = "#FF0000",
    data: string = "",
): AseSlice =
  makeAseSlice(
    name,
    color,
    data,
    makeAseSliceKey(h = bounds.h, w = bounds.w, x = bounds.x, y = bounds.y),
  )

# Helper for AseFrameTag
proc makeAseFrameTag(
    name: string = "Idle",
    direction: AseDirection = forward,
    color: string = "#FFFFFF",
    fromIdx: int32 = 0,
    toIdx: int32 = 0,
    data: string = "",
    repeat: string = "",
): AseFrameTag =
  AseFrameTag(
    name: name,
    direction: direction,
    color: color,
    `from`: fromIdx,
    to: toIdx,
    data: data,
    repeat: repeat,
  )

# Helper for SpriteSheet, allowing easy inline slices/tags
proc makeSpriteSheet(
    frames: seq[AseFrame] = @[makeAseFrame()],
    frameTags: seq[AseFrameTag] = @[makeAseFrameTag()],
    layers: seq[AseLayer] = @[makeAseLayer()],
    slices: seq[AseSlice] = @[makeAseSliceWithKey()],
    image: string = "sprite.png",
    size: AseSize = (h: 32'i32, w: 32'i32),
): SpriteSheet =
  SpriteSheet(
    frames: frames,
    meta: AseMeta(
      app: "aseprite",
      format: RGBA8888,
      frameTags: frameTags,
      image: image,
      layers: layers,
      scale: "1",
      size: size,
      slices: slices,
      version: "1.0",
    ),
  )

suite "Aseprite SpriteSheet Utilities":
  let sheet = makeSpriteSheet()

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
    check center((h: 10'i32, w: 20'i32, x: 5'i32, y: 15'i32)) == ivec2(15, 20)

  test "dimensions returns correct sprite dimensions":
    check sheet.dimensions() == ivec2(32, 32)

  test "hitBox returns correct bounds":
    check sheet.hitBox == (h: 10'i32, w: 20'i32, x: 5'i32, y: 15'i32)

  test "anchorOffset falls back to hitBox if Anchor slice missing":
    check sheet.anchorOffset == ivec2(15, 25)

  test "anchorPoint falls back to hitBox if Anchor slice missing":
    check sheet.anchorPoint == ivec2(1, 7)

  test "anchorPoint uses Anchor slice if present":
    let anchorSheet = makeSpriteSheet(
      slices =
        @[makeAseSliceWithKey(name = "Anchor", bounds = (h: 4, w: 6, x: 2, y: 3))]
    )
    check anchorSheet.anchorPoint == ivec2(11, 25)

  test "sliceKeyAsOffset returns offset relative to anchor":
    check sheet.sliceKeyAsOffset("HitBox") == ivec2(0, -5)

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
    check tb.offset == ivec2(-10, -10)

  test "strideToSpeed computes correct speed":
    # Add a slice with two keys at different x positions and frames
    let strideSheet = makeSpriteSheet(
      frames = @[makeAseFrame(), makeAseFrame(duration = 200, filename = "frame1.png")],
      frameTags = @[makeAseFrameTag(name = "Stride", fromIdx = 0, toIdx = 1)],
      image = "stride.png",
      slices =
        @[
          makeAseSlice(
            "StrideBox",
            "#00FF00",
            "",
            makeAseSliceKey(h = 10, w = 20, x = 10, y = 15),
            makeAseSliceKey(h = 10, w = 20, x = 30, y = 15),
          )
        ],
    )
    # Speed = (last.x - first.x) / totalMs * 1000 = (30 - 10) / (100 + 200) * 1000 = 20 / 300 * 1000 = 66.666...
    check abs(strideSheet.strideToSpeed("StrideBox") - 66.6667) < 0.01

  test "slicePoint functions return correct points with default anchor (BottomMiddle)":
    check sheet.slicePointFromTopLeft("HitBox") == some(ivec2(15, 25))
    check sheet.slicePointFromCenter("HitBox") == some(ivec2(-1, 9))

  test "slicePoint functions return correct points with AnchorTopLeft":
    let anchorSliceSheet = makeSpriteSheet(
      frames = sheet.frames,
      frameTags = sheet.meta.frameTags,
      layers = sheet.meta.layers,
      slices =
        @[
          makeAseSliceWithKey(
            name = "HitBox",
            bounds = (h: 10, w: 20, x: 5, y: 15),
            data = "AnchorTopLeft",
            color = "#00FF00",
          )
        ],
    )
    check anchorSliceSheet.slicePointFromTopLeft("HitBox") == some(ivec2(5, 15))
    check anchorSliceSheet.slicePointFromCenter("HitBox") == some(ivec2(-11, -1))

  test "slicePointFromTopLeft returns none for missing slice":
    check sheet.slicePointFromTopLeft("MissingSlice").isNone

  test "slicePointFromTopLeft and slicePointFromCenter use defaultAnchor parameter":
    # Create a slice with no anchor data (empty string), so it should use the defaultAnchor
    let noAnchorSheet = makeSpriteSheet(
      slices =
        @[
          makeAseSliceWithKey(
            name = "TestBox",
            bounds = (h: 10, w: 20, x: 5, y: 15),
            data = "", # No anchor specified
            color = "#00FF00",
          )
        ]
    )

    # Test with default anchor (AnchorBottomMiddle) - should be same as no parameter
    check noAnchorSheet.slicePointFromTopLeft("TestBox") ==
      noAnchorSheet.slicePointFromTopLeft("TestBox", AnchorBottomMiddle)

    # Test with different defaultAnchor (AnchorTopLeft)
    # With AnchorTopLeft, no offset should be added, so result should be (5, 15)
    check noAnchorSheet.slicePointFromTopLeft("TestBox", AnchorTopLeft) ==
      some(ivec2(5, 15))

    # Test slicePointFromCenter with defaultAnchor
    # AnchorTopLeft result (5, 15) minus sprite center (16, 16) = (-11, -1)
    check noAnchorSheet.slicePointFromCenter("TestBox", AnchorTopLeft) ==
      some(ivec2(-11, -1))

    # Test that explicit anchor data overrides defaultAnchor
    let explicitAnchorSheet = makeSpriteSheet(
      slices =
        @[
          makeAseSliceWithKey(
            name = "TestBox",
            bounds = (h: 10, w: 20, x: 5, y: 15),
            data = "AnchorTopLeft", # Explicit anchor
            color = "#00FF00",
          )
        ]
    )

    # Should return same result regardless of defaultAnchor since explicit anchor is specified
    check explicitAnchorSheet.slicePointFromTopLeft("TestBox", AnchorBottomMiddle) ==
      some(ivec2(5, 15))
    check explicitAnchorSheet.slicePointFromTopLeft("TestBox", AnchorTopLeft) ==
      some(ivec2(5, 15))

  test "slicePointFromCenter returns none for missing slice":
    check sheet.slicePointFromCenter("MissingSlice").isNone
