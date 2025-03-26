import random/mersenne

type Keypad*[A, B: static int] = object
  key1*: array[A, byte]
  key2*: array[B, byte]

proc apply(
    byt: byte, i: int32, random: var MersenneTwister, keypad1, keypad2: openarray[byte]
): byte =
  when defined(noObfuscation):
    result = byt
  else:
    result =
      byt xor keypad1[i mod keypad1.len] xor keypad2[i mod keypad2.len] xor
      random.randomInt(byte)
  # echo i, " from ", byt, " to ", result

proc obfuscate*(value: string, keys: Keypad): seq[byte] =
  ## Encode a string
  var random = initMersenneTwister(value.len.uint32)
  result = newSeq[byte](value.len)
  for i, byt in value:
    result[i] = byt.byte.apply(i.int32, random, keys.key1, keys.key2)

proc deobfuscate*(value: seq[byte], keys: Keypad): string =
  ## Encode a string
  var random = initMersenneTwister(value.len.uint32)
  result = newString(value.len)
  for i, byt in value:
    result[i] = byt.apply(i.int32, random, keys.key1, keys.key2).char
