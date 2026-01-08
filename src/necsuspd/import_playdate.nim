const LIVE_COMPILE* =
  defined(simulator) or defined(device) or defined(nimcheck) or defined(nimsuggest)

template importPlaydateApi*() =
  when LIVE_COMPILE:
    import playdate/api, playdate/util/initreqs
  else:
    import stubs/playdate_api
