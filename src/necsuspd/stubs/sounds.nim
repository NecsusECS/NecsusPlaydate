type
  PlaydateSequences* = ref object

  PlaydateSounds* = ref object
    sequence*: PlaydateSequences

  SoundSequence* = ref object

  AudioSample* = ref object

proc newSequence*(_: PlaydateSequences): SoundSequence =
  result.new()

proc loadMIDIFile*(this: SoundSequence, path: string) =
  discard
