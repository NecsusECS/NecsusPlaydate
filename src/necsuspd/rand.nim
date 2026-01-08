import random/mersenne, import_playdate

importPlaydateApi()

var state: MersenneTwister = initMersenneTwister(123456)

var isset {.used.} = false

proc random*(): var MersenneTwister =
  when not defined(unittests):
    if unlikely(not isset and playdate != nil):
      state = initMersenneTwister(playdate.system.getSecondsSinceEpoch().seconds.uint32)
      isset = true
  return state

proc rand*[T: SomeNumber](rand: var MersenneTwister, outRange: HSlice[T, T]): T =
  ## Produces a random number within the given range
  assert outRange.a <= outRange.b
  let generated = rand.random() * (outRange.b - outRange.a).float64 + outRange.a.float64
  when T is SomeInteger:
    return T(generated.toInt)
  else:
    return generated

proc rand*(rand: var MersenneTwister, kind: typedesc): auto =
  ## Produces a random number within the given range
  let generated = rand.rand(low(kind).ord .. high(kind).ord)
  return kind(generated)

proc rand*[T](rand: var MersenneTwister, options: openarray[T]): T =
  ## Chooses a random value from an array of values
  return options[rand.randomInt(0, options.len - 1)]

export mersenne
