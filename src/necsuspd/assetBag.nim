import
  necsus, std/[options, typetraits, strutils], util, loading, import_playdate, hebitmap

type
  AssetBagDef[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId] = ref object
    ## Defines the paths to various kinds of assets
    images: array[ImgId, string]
    sheets: array[SheetId, string]
    fonts: array[FontId, string]
    nineSlices: array[NineSliceId, string]
    midis: array[MidiId, string]
    sounds: array[SfxId, string]

  LoadTarget = enum
    LoadImage
    LoadSheet
    LoadFont
    LoadNineSlice
    LoadMidis
    LoadSfx

  AssetLoadState = object ## Holds the partially loaded state of an asset
    total: int32
    nextOverallId: int32
    nextTarget: LoadTarget
    nextTargetId: int32

  EitherState = enum
    EitherNone
    EitherA
    EitherB

  Either[A, B] = object
    case state: EitherState
    of EitherNone: discard
    of EitherA: a: A
    of EitherB: b: B

  AssetBag*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId] = ref object
    ## Loaded container of assets
    def: AssetBagDef[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]
    state: AssetLoadState
    images: array[ImgId, Either[LCDBitmap, HEBitmap]]
    sheets: array[SheetId, Either[LCDBitmapTable, HEBitmaps]]
    fonts: array[FontId, LCDFont]
    nineSlices: array[NineSliceId, NineSlice]
    midis: array[MidiId, SoundSequence]
    sounds: array[SfxId, AudioSample]

template read(bag, bucket, key, callback: untyped): untyped =
  if bag.`bucket`[key].isNil:
    log "Loading asset: ", bag.def.`bucket`[key]
    bag.`bucket`[key] = callback(bag.def.`bucket`[key])
  bag.`bucket`[key]

template loadEitherA(slot, path, loader: untyped): untyped =
  if slot.state != EitherA:
    log "Loading: ", path
    slot = typeof(slot)(state: EitherA, a: loader(path))
  slot.a

template loadEitherB(slot, path, suffix, fileBody, lcdBody: untyped): untyped =
  if slot.state != EitherB:
    let hePath {.inject.} = path & suffix
    if playdate.file.exists(hePath):
      log "Loading HE: ", hePath
      slot = typeof(slot)(state: EitherB, b: fileBody)
    else:
      log "Loading HE from LCD: ", path
      slot = typeof(slot)(state: EitherB, b: lcdBody)
  slot.b

template preloadEither(slot, path, suffix, heBody, lcdLoader: untyped) =
  if slot.state == EitherNone:
    let hePath {.inject.} = path & suffix
    if playdate.file.exists(hePath):
      log "Loading HE: ", hePath
      slot = typeof(slot)(state: EitherB, b: heBody)
    else:
      discard lcdLoader

proc loadHEBitmapFromFile(path: string): HEBitmap =
  fromBytes(playdate.file.open(path, kFileRead).read())

proc loadHESheetFromFile(path: string): HEBitmaps =
  seqFromBytes(playdate.file.open(path, kFileRead).read())

proc loadImage[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    bag: AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId], key: ImgId
): LCDBitmap =
  loadEitherA(bag.images[key], bag.def.images[key], playdate.graphics.newBitmap)

proc loadSheet(assets: auto, key: enum): LCDBitmapTable =
  loadEitherA(
    assets.sheets[key], assets.def.sheets[key], playdate.graphics.newBitmapTable
  )

proc preloadImage(bag: auto, key: enum) =
  preloadEither(
    bag.images[key],
    bag.def.images[key],
    ".hebi",
    loadHEBitmapFromFile(hePath),
    bag.loadImage(key),
  )

proc preloadSheet[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId], key: SheetId
) =
  preloadEither(
    assets.sheets[key],
    assets.def.sheets[key],
    ".hebs",
    loadHESheetFromFile(hePath),
    assets.loadSheet(key),
  )

proc asset*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: ImgId,
): LCDBitmap =
  assets.unwrap.loadImage(key)

proc heAsset*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId], key: ImgId
): HEBitmap =
  loadEitherB(assets.images[key], assets.def.images[key], ".hebi"):
    loadHEBitmapFromFile(hePath)
  do:
    assets.loadImage(key).fromLCDBitmap()

proc sheet*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId], key: SheetId
): LCDBitmapTable =
  assets.loadSheet(key)

proc heSheet*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId], key: SheetId
): HEBitmaps =
  loadEitherB(assets.sheets[key], assets.def.sheets[key], ".hebs"):
    loadHESheetFromFile(hePath)
  do:
    let table = assets.loadSheet(key)
    let count = table.getBitmapTableInfo().count
    var s = new seq[HEBitmap]
    s[] = newSeq[HEBitmap](count)
    for i in 0 ..< count:
      s[][i] = table.getBitmap(i).fromLCDBitmap()
    s

proc font*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: FontId,
): LCDFont =
  return read(assets.unwrap, fonts, key, playdate.graphics.newFont)

proc newSequence(path: string): SoundSequence =
  result = playdate.sound.sequence.newSequence()
  result.loadMIDIFile(path)

proc midi*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: MidiId,
): SoundSequence =
  return read(assets.unwrap, midis, key, newSequence)

proc sound*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: SfxId,
): AudioSample =
  return read(assets.unwrap, sounds, key, playdate.sound.newAudioSample)

proc newNineSlice(path: string): auto =
  playdate.graphics.newBitmap(path).newNineSlice()

proc nineSlice*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    assets: SharedOrT[AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]],
    key: NineSliceId,
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
    state: AssetLoadState(
      total: images.len + sheets.len + fonts.len + nineSlices.len + midis.len
    ),
  )

template createLoaders(task, bag, input, output, kind: untyped) =
  for key in kind:
    if bag.def.input[key].len > 0:
      execTask(task, $key & " " & bag.def.input[key], kind, key):
        when compiles(
          block:
            discard output(bag, key)
        ):
          discard output(bag, key)
        else:
          output(bag, key)

proc buildAssetLoader*[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId](
    bag: AssetBag[ImgId, SheetId, FontId, NineSliceId, MidiId, SfxId]
): auto =
  ## Defines a system that registers loading tasks for all assets
  return proc(task: Bundle[LoadTasks]) =
    task.createLoaders(bag, images, preloadImage, ImgId)
    task.createLoaders(bag, sheets, preloadSheet, SheetId)
    task.createLoaders(bag, fonts, font, FontId)
    task.createLoaders(bag, nineSlices, nineSlice, NineSliceId)
    task.createLoaders(bag, midis, midi, MidiId)
    task.createLoaders(bag, sounds, sound, SfxId)

proc findAssetBagKey*(path: string, typ: typedesc[enum], suffix: string = ""): typ =
  # Takes a string in the form "../source/images/map-background-1.png"
  # It strips the 'png', removes all the leading directories, then converts
  # from lower kebab case to upper camel case. So the result iS: MapBackground1
  # This will also strip the '-table-16-16' style suffixes added to the filename
  let filename = path[(path.rfind('/') + 1) .. ^1].removeSuffix(".png")
  var key = ""
  for part in filename.split('-'):
    if part == "table":
      break
    else:
      key.add(part.capitalizeAscii())
  return parseEnum[typ](key & suffix)
