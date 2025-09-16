import json_schema_import, std/[options, json, strutils, macros, setutils], fungus, util

when defined(simulator) or defined(device):
  import playdate/api
else:
  import ../../tests/stubs/playdate_api

importJsonSchema(
  "achievements.schema.json",
  JsonSchemaConfig(rootTypeName: "AchievementData", typePrefix: "PD"),
)

adtEnum(AchievementState):
  AchievementLocked
  AchievementInProgress:
    int
  AchievementGranted:
    int

proc init*(_: typedesc[AchievementGranted]): AchievementGranted =
  AchievementGranted.init(playdate.system.getSecondsSinceEpoch().seconds.int)

type
  AnyAchievementState* =
    AchievementState or AchievementLocked or AchievementInProgress or AchievementGranted

  AchievementDef*[T: enum] = object
    ## Defines the fields required to define an achievement
    id*: T
    name*, description*: string
    descriptionLocked*: Option[string]
    icon*, iconLocked*: Option[string]
    isSecret*, progressIsPercentage*: bool
    progressMax*, scoreValue*: Option[int]

  AppAchievementDef*[T: enum] = object
    ## Defines the fields required for an application to support achievements
    gameID*, name*, author*, description*, version*: string
    iconPath*, cardPath*: Option[string]
    achievements*: array[T, AchievementDef[T]]

  Achievements*[T: enum] = array[T, AchievementState]
    ## Data about the achievements for the application

proc `==`*(a, b: AnyAchievementState): bool =
  match a:
  of AchievementLocked:
    return b.kind == AchievementLockedKind
  of AchievementInProgress as value:
    return
      b.kind == AchievementInProgressKind and
      b.AchievementInProgress.toInternal == value.toInternal
  of AchievementGranted as value:
    return
      b.kind == AchievementGrantedKind and
      b.AchievementGranted.toInternal == value.toInternal

template definePdxConst(name: untyped, default: string) =
  when not defined(name) and not defined(unittests):
    static:
      const errorMessage =
        "-d:" & astToStr(name) & "=... is not defined as a build option"
      if defined(device):
        error(errorMessage)
      else:
        warning(errorMessage)
  const name {.strdefine.}: string = default

definePdxConst(pdxBundleId, "com.example.game")
definePdxConst(pdxName, "Example Game")
definePdxConst(pdxAuthor, "John Doe")
definePdxConst(pdxDescription, "An example game")
definePdxConst(pdxVersion, "1.0")

proc defineAchievements*[T: enum](
    gameID: string = pdxBundleId,
    name: string = pdxName,
    author: string = pdxAuthor,
    description: string = pdxDescription,
    version: string = pdxVersion,
    iconPath: Option[string] = none(string),
    cardPath: Option[string] = none(string),
    achievements: openarray[AchievementDef[T]],
): AppAchievementDef[T] =
  ## Configures the achievements for the application
  result = AppAchievementDef[T](
    gameID: gameID,
    name: name,
    author: author,
    description: description,
    version: version,
    iconPath: iconPath,
    cardPath: cardPath,
  )

  var seen: set[T]
  for achievement in achievements:
    seen.incl(achievement.id)
    result.achievements[achievement.id] = achievement

  if complement(seen).card != 0:
    raiseAssert("Not all achievements are defined. Missing: " & $complement(seen))

proc achievement*[T: enum](
    id: T,
    name, description: string,
    descriptionLocked: Option[string] = none(string),
    icon: Option[string] = none(string),
    iconLocked: Option[string] = none(string),
    isSecret: bool = false,
    progressIsPercentage: bool = false,
    progressMax: Option[int] = none(int),
    scoreValue: Option[int] = none(int),
): AchievementDef[T] =
  ## Defines a single achievement
  AchievementDef[T](
    id: id,
    name: name,
    description: description,
    descriptionLocked: descriptionLocked,
    icon: icon,
    iconLocked: iconLocked,
    isSecret: isSecret,
    progressIsPercentage: progressIsPercentage,
    progressMax: progressMax,
    scoreValue: scoreValue,
  )

proc path*(def: AppAchievementDef): string =
  ## The on-disk path to the achievement data for the application
  "/Shared/Achievements/" & def.gameId & "/Achievements.json"

proc load*[T: enum](def: AppAchievementDef[T]): Achievements[T] =
  ## Fetches the achievement data from disk for the application
  let filePath = path(def)
  if playdate.file.exists(filePath):
    let data = playdate.file.open(filePath, kFileRead).readString().parseJson().jsonTo(
        PDAchievementData
      )

    for achievement in data.achievements:
      try:
        let id = parseEnum[T](achievement.id)
        result[id] =
          if achievement.grantedAt.isSome:
            AchievementGranted.init(achievement.grantedAt.get().int).AchievementState
          elif achievement.progress.isSome:
            AchievementInProgress.init(achievement.progress.get().int).AchievementState
          else:
            AchievementLocked.init().AchievementState
      except ValueError as e:
        log "Error parsing achievement data: " & e.msg

proc asPDAchievementData[T](
    def: AppAchievementDef[T], achievements: seq[PDAchievements]
): auto =
  return PDAchievementData(
    gameID: def.gameID,
    name: def.name,
    author: def.author,
    description: def.description,
    version: def.version,
    iconPath: def.iconPath,
    cardPath: def.cardPath,
    achievements: achievements,
  )

proc asPDAchievements[T](
    ach: AchievementDef[T], state: AchievementState
): PDAchievements =
  result = PDAchievements(
    name: ach.name,
    description: ach.description,
    descriptionLocked: ach.descriptionLocked,
    id: $ach.id,
    icon: ach.icon,
    iconLocked: ach.iconLocked,
    isSecret: some(ach.isSecret),
    progressMax: ach.progressMax.mapIt(it.BiggestInt),
    progressIsPercentage: some(ach.progressIsPercentage),
    scoreValue: ach.scoreValue.mapIt(it.BiggestInt),
  )
  match state:
  of AchievementGranted as completed:
    result.grantedAt = some(completed.toInternal.BiggestInt)
  of AchievementInProgress as progress:
    result.progress = some(progress.toInternal.BiggestInt)
  of AchievementLocked:
    discard

proc write*[T: enum](def: AppAchievementDef[T], states: array[T, AnyAchievementState]) =
  ## Updates the given achievements with new states
  var achievements = newSeqOfCap[PDAchievements](states.len)

  for id, state in states:
    achievements.add(def.achievements[id].asPDAchievements(state))

  let json = toJson(def.asPDAchievementData(achievements)).pretty

  playdate.file.open(def.path(), kFileWrite).write(json)

proc shouldUpdate(oldState, newState: AchievementState): bool =
  ## Returns whether a new achievement should replace an existing achievement
  match oldState:
  of AchievementGranted:
    return false
  of AchievementInProgress as oldProgress:
    match newState:
    of AchievementGranted:
      return true
    of AchievementInProgress as newProgress:
      return newProgress.toInternal > oldProgress.toInternal
    of AchievementLocked:
      return false
  of AchievementLocked:
    return true

proc save*[T: enum](
    def: AppAchievementDef[T], states: openarray[(T, AnyAchievementState)]
) =
  ## Updates the given achievements with new states
  var fullStates = load(def)
  for (id, state) in states:
    if fullStates[id].shouldUpdate(state.AchievementState):
      fullStates[id] = state.AchievementState
  write(def, fullStates)

proc save*[T: enum](def: AppAchievementDef[T], id: T, state: AnyAchievementState) =
  ## Updates a single achievement with a new state
  save(def, [(id, state)])
