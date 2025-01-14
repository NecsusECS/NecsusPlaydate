import necsus, playdate/api, std/[options, strformat], util, loading

type
    AssetBagDef[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId] = ref object
        ## Defines the paths to various kinds of assets
        images: array[ImgId, string]
        sheets: array[SheetId, string]
        fonts: array[FontId, string]
        nineSlices: array[NineSliceId, string]
        midis: array[MidiId, string]
        sounds: array[SfxId, string]

    LoadTarget = enum LoadImage, LoadSheet, LoadFont, LoadNineSlice, LoadMidis, LoadSfx

    AssetLoadState = object
        ## Holds the partially loaded state of an asset
        total: int32
        nextOverallId: int32
        nextTarget: LoadTarget
        nextTargetId: int32

    AssetBag*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId] = ref object
        ## Loaded container of assets
        def: AssetBagDef[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]
        state: AssetLoadState
        images: array[ImgId, LCDBitmap]
        sheets: array[SheetId, LCDBitmapTable]
        fonts: array[FontId, LCDFont]
        nineSlices: array[NineSliceId, NineSlice]
        midis: array[MidiId, SoundSequence]
        sounds: array[SfxId, AudioSample]

template read(bag, bucket, key, callback: untyped): untyped =
    if bag.`bucket`[key].isNil:
        log "Loading asset: ", bag.def.`bucket`[key]
        bag.`bucket`[key] = callback(bag.def.`bucket`[key])
    bag.`bucket`[key]

proc asset*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: ImgId
): LCDBitmap =
    return read(assets.unwrap, images, key, playdate.graphics.newBitmap)

proc sheet*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: SheetId
): LCDBitmapTable =
    return read(assets.unwrap, sheets, key, playdate.graphics.newBitmapTable)

proc font*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: FontId
): LCDFont =
    return read(assets.unwrap, fonts, key, playdate.graphics.newFont)

proc newSequence(path: string): SoundSequence =
    result = playdate.sound.sequence.newSequence()
    result.loadMIDIFile(path)

proc midi*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: MidiId
): SoundSequence =
    return read(assets.unwrap, midis, key, newSequence)

proc sound*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: SfxId
): AudioSample =
    return read(assets.unwrap, sounds, key, playdate.sound.newAudioSample)

proc newNineSlice(path: string): auto = playdate.graphics.newBitmap(path).newNineSlice()

proc nineSlice*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: NineSliceId
): NineSlice =
    return read(assets.unwrap, nineSlices, key, newNineSlice)

proc defineAssetBag*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    images: array[ImgId, string],
    sheets: array[SheetId, string],
    fonts: array[FontId, string],
    nineSlices: array[NineSliceId, string],
    midis: array[MidiId, string],
    sounds: array[SfxId, string],
): AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId] =
    ## Defines the location of assets to be loaded
    return AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
        def: AssetBagDef[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
            images: images,
            sheets: sheets,
            fonts: fonts,
            nineSlices: nineSlices,
            midis: midis,
            sounds: sounds,
        ),
        state: AssetLoadState(total: images.len + sheets.len + fonts.len + nineSlices.len + midis.len)
    )

template createLoaders(task, bag, input, output, kind: untyped) =
    for key in kind:
        if bag.def.input[key].len > 0:
            execTask(task, $key & " " & bag.def.input[key], kind, key):
                discard bag.output(key)

proc buildAssetLoader*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    bag: AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]
): auto =
    ## Defines a system that registers loading tasks for all assets
    return proc (task: Bundle[LoadTasks]) =
        task.createLoaders(bag, images, asset, ImgId)
        task.createLoaders(bag, sheets, sheet, SheetId)
        task.createLoaders(bag, fonts, font, FontId)
        task.createLoaders(bag, nineSlices, nineSlice, NineSliceId)
        task.createLoaders(bag, midis, midi, MidiId)
        task.createLoaders(bag, sounds, sound, SfxId)