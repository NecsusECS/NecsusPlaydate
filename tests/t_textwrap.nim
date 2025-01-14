import unittest, necsuspd/textwrap, sequtils

proc getWidth(text: string): int32 = text.len.int32 * 8

suite "Text wrapping":
    test "Short strings should not wrap":
        check(textwrap("foo bar baz", 100, getWidth).toSeq == @["foo bar baz"])

    test "Long strings should wrap at breaks":
        check(textwrap("foo bar baz and baz and qux and wakka wakka", 80, getWidth).toSeq == @[
            "foo bar",
            "baz and",
            "baz and",
            "qux and",
            "wakka",
            "wakka"
        ])

    test "Long words should not be split":
        check(textwrap("this_is_a_very_long_word", 80, getWidth).toSeq == @[ "this_is_a_very_long_word" ])
