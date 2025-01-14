import time, necsus

type
    Debounce*[T] = object
        ## Uses a type as a flag for debouncing an action
        gameTime: GameTime
        at: Shared[(bool, float32, T)]

proc mark*[T](debounce: Bundle[Debounce[T]]) =
    ## Marks that an action has occurred
    debounce.at := (true, debounce.gameTime.get, default(T))

proc markIfUnmarked*[T](debounce: Bundle[Debounce[T]]) =
    ## Marks that an action has occurred
    if debounce.at.isEmpty or not debounce.at.get[0]:
        debounce.mark

proc unmark*[T](debounce: Bundle[Debounce[T]]) =
    ## Resets a debouncer to consider that an action has not yet occurred
    debounce.at := (false, 0.0'f32, default(T))

proc `<`*[T](delta: float32, debounce: Bundle[Debounce[T]]): bool =
    ## Requires that an action has occurred and it has been longer than `delta` since it happened
    let (occurred, time, _) = debounce.at.get
    return occurred and debounce.gameTime.get - time >= delta