import necsus, loading, visibleState, sprite, paused

template createsSingletonSpawner*(
    name: untyped,
    entityTag: typed,
    assetBagType: typedesc,
    loadingState, zIndex: enum,
    initialAnimation: AnimationDef,
    visibility: VisibleState,
    pausedIn: PausedState
) =
  ## Creates a system for spawning a singleton entity
  proc `name`*(
      task: Bundle[LoadTasks],
      assets: Shared[assetBagType],
      create: Spawn[(typeof(entityTag), Animation, Positioned, VisibleState, PausedState)],
  ) {.active(loadingState).} =
    task.execTask($typeof(entityTag), typeof(entityTag), 0):
      let sheet = assets.newSheet(initialAnimation, zIndex)
      sheet.visible = false
      set(create, (entityTag, sheet, positioned(0, 0), visibility, pausedIn))

template createSingletonSprite*(
    name: untyped,
    entityTag: typed,
    assetBagType: typedesc,
    loadingState, zIndex: enum,
    initialAsset: enum,
    visibility: VisibleState,
    anchor: AnchorPosition,
    absolutePos: bool,
) =
  ## Creates a system for spawning a singleton entity backed by a static Sprite
  proc `name`*(
      task: Bundle[LoadTasks],
      assets: Shared[assetBagType],
      create: Spawn[(typeof(entityTag), Sprite, Positioned, VisibleState)],
  ) {.active(loadingState).} =
    task.execTask($typeof(entityTag), typeof(entityTag), 0):
      let sprite = assets.newAssetSprite(initialAsset, anchor, zIndex, absolutePos)
      sprite.visible = false
      set(create, (entityTag, sprite, positioned(0, 0), visibility))
