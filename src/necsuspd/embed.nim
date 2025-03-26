import std/[macros, genasts], util

proc buildEmbed(
    typ, path, exists, open, slurp, parse: NimNode;
    alwaysEmbed: bool;
): NimNode =
    ## Embeds content from a file into the nim binary for release builds
    let fullPath = genAst(path):
        getProjectPath() & "/../" & path

    let embedded = genAst(fullPath, typ, parse, slurp):
        block:
            const bin = toBinary(parse[typ](slurp(fullPath)))
            typ.fromBinary(bin)

    if alwaysEmbed:
        return embedded

    let dynLoad = genSym(nskProc, "load")

    let loadProc = genAst(typ, parse, open, dynLoad):
        proc dynLoad(path: string): typ =
            log "Dynamically loading from: ", path
            let file = open(path)
            try:
                let content = file.readString()
                assert(content != "")
                return parse[typ](content)
            finally:
                file.close()

    let build = genAst(path, fullPath, exists, embedded, dynLoad):
        block:
            if exists(path):
                dynLoad(path)
            else:
                log "Dynamic load source does not exist: ", path, " -- using embedded value"
                embedded

    return genAst(build, typ, loadProc):
        block:
            loadProc
            var built {.global.}: typ
            once:
                built = build
            built

when defined(unittests):
    macro embedData*(
        typ: typedesc;
        path: string;
        exists, open, slurp, parse: untyped;
        alwaysEmbed: static bool
    ): auto =
        buildEmbed(typ, path, exists, open, slurp, parse, alwaysEmbed)

else:
    import playdate/api

    proc openForRead(path: string): auto = playdate.file.open(path, kFileRead)

    proc fileExists(path: string): bool = playdate.file.exists(path)

    macro embedData*(typ: typedesc, path: string, parse: untyped): auto =
        buildEmbed(typ, path, bindSym("fileExists"), bindSym("openForRead"), bindSym("slurp"), parse, defined(release))
