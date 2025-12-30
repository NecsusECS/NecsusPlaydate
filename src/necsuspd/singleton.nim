import necsus, loading, visibleState, sprite

template createsSingletonSpawner*(
    name: untyped,
    entityTag: typed,
    assetBagType: typedesc,
    loadingState, zIndex: enum,
    initialAnimation: AnimationDef,
    visibility: VisibleState,
) =
  ## Creates a system for spawning a singleton entity
  proc `name`*(
      task: Bundle[LoadTasks],
      assets: Shared[assetBagType],
      create: Spawn[(typeof(entityTag), Animation, Positioned, VisibleState)],
  ) {.active(loadingState).} =
    task.execTask($typeof(entityTag), typeof(entityTag), 0):
      let sheet = assets.newSheet(initialAnimation, zIndex)
      sheet.visible = false
      set(create, (entityTag, sheet, positioned(0, 0), visibility))
