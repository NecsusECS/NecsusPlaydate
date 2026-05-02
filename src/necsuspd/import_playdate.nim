const LIVE_COMPILE* =
  defined(simulator) or defined(device) or defined(nimcheck) or defined(nimsuggest)

when LIVE_COMPILE:
  import playdate/api, playdate/lcdbitmap {.all.}
  export api
else:
  import stubs/playdate_api
  export playdate_api
