import unittest, necsuspd/obfuscate

const keys = Keypad[3, 7](
    key1: [ 1, 2, 3 ],
    key2: [ 4, 5, 6, 7, 8, 9, 10 ]
)

suite "Obfuscating values":
    test "Obfuscate and deobfuscate":
        let input = "foo bar and baz"
        check(input.obfuscate(keys).deobfuscate(keys) == input)

        check(input.obfuscate(keys) == @[ 171.byte, 157, 230, 163, 31, 235, 229, 189, 160, 162, 52, 93, 197, 180, 108 ])
