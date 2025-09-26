import necsus, achievements, sprite, positioned, files, util, std/options
export achievements

type
  Awarded[T] = tuple[kind: T, state: AchievementState]
    ## Internal event to signal an achievement change

  AwardApi[T] = object ## Necsus API for granting achievements
    send: Outbox[Awarded[T]]

  Award*[T: enum] = Bundle[AwardApi[T]] ## External Necsus API for granting achievements

  ShowAwardPopup[T] = T ## An event that is triggered when an achievement is granted

  AwardPopup {.maxCapacity(10).} = object ## The entity tag for an achievement

  AwardPopupTimer {.maxCapacity(10).} = object
    ## The entity tag for an achievement timer

proc complete*[T: enum](api: Award[T], kind: T) =
  ## Awards an achievement
  api.send((kind, AchievementGranted.init().AchievementState))

proc progress*[T: enum](api: Award[T], kind: T, progress: int) =
  ## Progresses an achievement
  api.send((kind, AchievementInProgress.init(progress).AchievementState))

proc progress*[T: enum](
    grant: Award[T], kind: T, progress: int, max: int, step: int = 10
) =
  ## Progresses an achievement
  if progress in max .. (max + 3):
    grant.complete(kind)
  elif progress < max and progress mod step == 0:
    grant.progress(kind, progress)

proc copyFiles(srcFile, targetFile: Option[string]) =
  if srcFile.isSome and targetFile.isSome:
    log "Copying from ", srcFile.get, " to ", targetFile.get
    copyFile(srcFile.get, targetFile.get)

template buildAwardSystems*[T: enum](
    systemName: untyped,
    def: AppAchievementDef[T],
    Assets: typedesc,
    achievementImgAsset: enum,
    popupZIndex: enum,
    titleFont, subtitleFont: enum,
) =
  ## Creates a suite of systems for managing achievements

  proc progress*(grant: Award[T], kind: T, progress: int, step: int = 10) =
    ## Marks progress of an achievement
    grant.progress(kind, progress, def.achievements[kind].progressMax.get(), step)

  proc debugAchievements(
      key: DebugKey, trigger: Outbox[ShowAwardPopup[T]], nextAchievement: Local[T]
  ) {.eventSys.} =
    ## Maps a debug key to a granting an achievement
    if key == '\'':
      let next = nextAchievement.get()
      log "Triggering debug achievement: ", next
      trigger(next)
      if next == high(T):
        nextAchievement := low(T)
      else:
        nextAchievement := next.succ

  proc showAwardPop(
      event: ShowAwardPopup[T],
      assets: Shared[Assets],
      spawn: FullSpawn[(AwardPopup, Positioned, Sprite)],
      delete: Delete,
      moveTo: Bundle[MoveTo[AwardPopup]],
      timer: Bundle[TimerControl[AwardPopupTimer]],
  ) {.eventSys, depends(debugAchievements).} =
    ## Shows a notification for a granted achievement
    let sprite = assets.newAssetSprite(
      achievementImgAsset, AnchorTopMiddle, popupZIndex, absolutePos = true
    )

    stack(
      text(
        def.achievements[event].name,
        font = assets.font(titleFont),
        pad = (0'i32, 0'i32, 0'i32, -4'i32),
      ),
      text(
        def.achievements[event].descriptionLocked.get(
          def.achievements[event].description
        ),
        pad = (0'i32, 0'i32, 0'i32, 0'i32),
      ),
    )
    .pad(left = 36, top = 4)
    .draw(sprite.getImage, assets.font(subtitleFont))

    let AwardPopupY = -sprite.height - 10
    const AwardPopupX = 200
    let id = spawn.with(AwardPopup(), positioned(AwardPopupX, AwardPopupY), sprite)

    log "Showing achievement popup: ", id

    moveTo.move(id, ivec2(AwardPopupX, 3), 0.5, easeLinear, easeOutBack) do() -> void:
      timer.startTimer("Achievement popup timer", 2.0) do() -> void:
        moveTo.move(
          id, ivec2(AwardPopupX, AwardPopupY.int32), 0.3, easeLinear, easeInBack
        ) do() -> void:
          delete(id)

  proc systemName*(
      granted: Outbox[ShowAwardPopup[T]]
  ): EventSystemInstance[Awarded[T]] {.eventSys, depends(showAwardPop).} =
    ## Initialize achievements system. Sets up an event listener for when achievements are granted.

    var loaded = def.load()
    def.write(loaded)
    copyFiles(def.iconPath, def.iconTargetPath)
    copyFiles(def.cardPath, def.cardTargetPath)

    log "Achievements initialized: ", loaded

    return proc(event: Awarded[T]) =
      if not event.state.isAdvancement(loaded[event.kind]):
        log "Achievement is not an advancement: ", event, " vs ", loaded[event.kind]
        return

      log "Achievement updated: ", event
      loaded.advance(event.kind, event.state)
      def.write(loaded)

      if event.state.kind == AchievementGrantedKind:
        granted(event.kind)
