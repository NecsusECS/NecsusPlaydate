import macros

type
    DebugKey* = char

macro debugSys*(system: typed): untyped =
    ## Pragma for a system that only needs to operate when debug mode is enabled
    if not defined(playdate):
        system
    else:
        let name = system.name
        quote:
            proc `name`*() = discard
