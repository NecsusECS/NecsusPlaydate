import percent, necsus, util, std/[sets]

type
  LastLoadTick = BiggestUInt

  TaskKey = object
    typeId, taskId: int32

  AllTasksKey = TaskKey

  LoadTasks* = object
    allTasks: Shared[HashSet[AllTasksKey]]
    remainingTasks: Shared[HashSet[TaskKey]]
    lastTick: Shared[LastLoadTick]
    getTick: TickId

  LoadProgress* = object
    ## An event that gets triggered whenever the incremental load progress is updated
    total*, complete*, remaining*: int32
    progress*: Percent

  LoadingDone* = object ## Emitted when all the loading tasks are complete

proc buildLoader*[S](stateForLoading: S): auto =
  return proc(
      state: Shared[S],
      emitDone: Outbox[LoadingDone],
      emitProgress: Outbox[LoadProgress],
      tasks: Bundle[LoadTasks],
      done: Local[bool],
  ) =
    if not done.get and state == stateForLoading and tasks.allTasks.isSome:
      let total = tasks.allTasks.getOrRaise.len.int32
      let remaining = tasks.remainingTasks.getOrRaise.len.int32
      let complete = total - remaining
      emitProgress(
        LoadProgress(
          total: total,
          complete: complete,
          remaining: remaining,
          progress: percent(complete, total),
        )
      )

      if remaining <= 0:
        done := true
        emitDone(LoadingDone())
        log "Done with loading tasks"

proc shouldRunTask(control: Bundle[LoadTasks], taskId: TaskKey): bool =
  # Initialize the task trackers as necessary
  if control.allTasks.isEmpty:
    log "Beginning load tasks"
    control.remainingTasks := initHashSet[TaskKey]()
    control.allTasks := initHashSet[TaskKey]()

  # Register this task if it hasn't been seen before
  if not control.allTasks.getOrRaise.contains(taskId):
    control.allTasks.getOrRaise.incl(taskId)
    control.remainingTasks.getOrRaise.incl(taskId)

  # Only execute one task per tick
  if control.lastTick == control.getTick():
    return false

  if not control.remainingTasks.getOrRaise.contains(taskId):
    return false

  control.lastTick := control.getTick()
  control.remainingTasks.getOrRaise.excl(taskId)

  return true

proc buildKey(kind: typedesc, key: int32): auto =
  TaskKey(typeId: kind.getTypeId.int32, taskId: key)

template execTask*(
    control: Bundle[LoadTasks],
    label: string,
    kind: typedesc,
    key: Ordinal,
    body: untyped,
) =
  ## Executes a loading task
  if control.shouldRunTask(buildKey(kind, key.int32)):
    log "Executing load task: ", label
    body
