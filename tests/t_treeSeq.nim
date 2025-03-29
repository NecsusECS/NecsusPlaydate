import std/[unittest, sequtils]
import necsuspd/treeSeq

suite "TreeSeq":
  let empty = treeSeq(string)
  let single = "foo".treeSeq
  let double = treeSeq("a", "b")
  let repeat = "baz".treeSeq.repeat(3)

  let list = toTreeSeq([empty, single, double, repeat], string)

  let tree = treeSeq(1, treeSeq(2, treeSeq(3, 4)).repeat(2))

  test "Calculating length":
    check(empty.len == 0)
    check(single.len == 1)
    check(double.len == 2)
    check(repeat.len == 3)
    check(list.len == 6)
    check(tree.len == 7)

  test "Empty index access":
    expect IndexDefect:
      discard empty[0]
    expect IndexDefect:
      discard empty[-1]

  test "Single index access":
    check(single[0] == "foo")
    expect IndexDefect:
      discard single[1]
    expect IndexDefect:
      discard single[-1]

  test "Double index access":
    check(double[0] == "a")
    check(double[1] == "b")
    expect IndexDefect:
      discard double[2]
    expect IndexDefect:
      discard double[-1]

  test "Repeat index access":
    check(repeat[0] == "baz")
    check(repeat[1] == "baz")
    check(repeat[2] == "baz")
    expect IndexDefect:
      discard repeat[3]
    expect IndexDefect:
      discard repeat[-1]

  test "List index access":
    check(list[0] == "foo")
    check(list[1] == "a")
    check(list[2] == "b")
    check(list[3] == "baz")
    check(list[4] == "baz")
    check(list[5] == "baz")
    expect IndexDefect:
      discard list[6]
    expect IndexDefect:
      discard list[-1]

  test "Tree index access":
    check(tree[0] == 1)
    check(tree[1] == 2)
    check(tree[2] == 3)
    check(tree[3] == 4)
    check(tree[4] == 2)
    check(tree[5] == 3)
    check(tree[6] == 4)
    expect IndexDefect:
      discard tree[7]
    expect IndexDefect:
      discard tree[-1]

  test "Tree iteration":
    check(empty.toSeq.len == 0)
    check(single.toSeq == @["foo"])
    check(double.toSeq == @["a", "b"])
    check(repeat.toSeq == @["baz", "baz", "baz"])
    check(list.toSeq == @["foo", "a", "b", "baz", "baz", "baz"])
    check(tree.toSeq == @[1, 2, 3, 4, 2, 3, 4])
