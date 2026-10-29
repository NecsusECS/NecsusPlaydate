import
  necsus,
  achievements,
  drawable,
  positioned,
  files,
  util,
  import_playdate,
  suspend,
  std/options
export achievements

type
  Awarded[T] = tuple[kind: T, state: AchievementState]
    ## Internal event to signal an achievement change

  AwardApi[T] = object ## Necsus API for granting achievements
    send: Outbox[Awarded[T]]

  Award*[T: enum] = Bundle[AwardApi[T]] ## External Necsus API for granting achievements

  AwardsChanged = object
    ## Sent whenever the achievement data changes and needs writing to disk

  AwardStorage[T: enum] = Shared[Achievements[T]]
    ## The loaded achievement data, written to disk at most once per frame

  ShowAwardPopup[T] = T ## An event that is triggered when an achievement is granted

  AwardPopup {.maxCapacity(10).} = object ## The entity tag for an achievement

  AwardPopupTimer {.maxCapacity(10).} = object
    ## The entity tag for an achievement timer

proc complete*[T: enum](api: Award[T], kind: T) =
  ## Awards an achievement
  api.send((kind, AchievementGranted.init().AchievementState))

proc progress*[T: enum](
    grant: Award[T], kind: T, progress: int, max: int, step: int = 1
) =
  ## Progresses an achievement, granting it once `progress` reaches `max`.
  ## In-progress updates are only sent on multiples of `step`, so callers that
  ## report often can throttle them.
  if progress >= max:
    grant.complete(kind)
  elif progress mod step == 0:
    grant.send((kind, AchievementInProgress.init(progress).AchievementState))

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

  proc progress*(grant: Award[T], kind: T, progress: int, step: int = 1) =
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
      spawn: FullSpawn[(AwardPopup, Positioned, Drawable)],
      delete: Delete,
      moveTo: Bundle[MoveTo[AwardPopup]],
      timer: Bundle[TimerControl[AwardPopupTimer]],
  ) {.eventSys, depends(debugAchievements).} =
    ## Shows a notification for a granted achievement

    # Draw into a copy, to ensure we have an LCDBitmap and we keep the base image clean
    let img = assets.asset(achievementImgAsset).copy()

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
      .draw(img, assets.font(subtitleFont))

    let sprite =
      newBitmapDrawable(img, popupZIndex, AnchorTopMiddle, absolutePos = true)

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

  proc writeAwards(storage: AwardStorage[T]) =
    def.write(storage.get())

  proc flushAwards(changes: Inbox[AwardsChanged], storage: AwardStorage[T]) =
    ## Writes the achievement data at most once per frame, so several updates in
    ## one frame (like those made when a level ends) share a single write
    if changes.len > 0:
      storage.writeAwards()

  proc writeAwardsOnSuspend(_: AppSuspended, storage: AwardStorage[T]) {.eventSys.} =
    ## Writes the achievement data before the game is paused, locked or closed,
    ## in case changes from this frame haven't been written yet
    storage.writeAwards()

  proc systemName*(
      granted: Outbox[ShowAwardPopup[T]],
      changed: Outbox[AwardsChanged],
      storage: AwardStorage[T],
  ): EventSystemInstance[Awarded[T]] {.
      eventSys, depends(showAwardPop, flushAwards, writeAwardsOnSuspend)
  .} =
    ## Initialize achievements system. Sets up an event listener for when achievements are granted.

    storage := def.load()
    storage.writeAwards()
    copyFiles(def.iconPath, def.iconTargetPath)
    copyFiles(def.cardPath, def.cardTargetPath)

    log "Achievements initialized: ", storage.get()

    return proc(event: Awarded[T]) =
      let current = storage.get()[event.kind]
      if not event.state.isAdvancement(current):
        log "Achievement is not an advancement: ", event, " vs ", current
        return

      log "Achievement updated: ", event
      storage.getOrPut().advance(event.kind, event.state)
      changed(AwardsChanged())

      if event.state.kind == AchievementGrantedKind:
        granted(event.kind)
