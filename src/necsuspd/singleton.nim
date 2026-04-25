import necsus, loading, visibleState, anim, paused

template createsSingletonSpawner*(
    name: untyped,
    entityTag: typed,
    assetBagType: typedesc,
    loadingState, zIndex: enum,
    initialAnimation: AnimationDef,
    visibility: VisibleState,
    pausedIn: PausedState,
) =
  ## Creates a system for spawning a singleton entity
  proc `name`*(
      task: Bundle[LoadTasks],
      assets: Shared[assetBagType],
      create:
        Spawn[(typeof(entityTag), Drawable, Anim, Positioned, VisibleState, PausedState)],
  ) {.active(loadingState).} =
    task.execTask($typeof(entityTag), typeof(entityTag), 0):
      let (sheet, sheetAnim) = assets.newSheet(initialAnimation, zIndex)
      sheet.visible = false
      set(create, (entityTag, sheet, sheetAnim, positioned(0, 0), visibility, pausedIn))

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
      create: Spawn[(typeof(entityTag), Drawable, Positioned, VisibleState)],
  ) {.active(loadingState).} =
    task.execTask($typeof(entityTag), typeof(entityTag), 0):
      let drawable = assets.newAssetDrawable(initialAsset, anchor, zIndex, absolutePos)
      drawable.visible = false
      set(create, (entityTag, drawable, positioned(0, 0), visibility))
