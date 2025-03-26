import strformat

type
  TreeSeqKind = enum
    Empty
    Single
    Double
    Repeat

  TreeSeq*[T] = ref object
    case kind: TreeSeqKind
    of Empty:
      discard
    of Single:
      value: T
    of Double:
      sizeCache: int32
      a, b: TreeSeq[T]
    of Repeat:
      sub: TreeSeq[T]
      count: int32

proc treeSeq*(T: typedesc): auto =
  return TreeSeq[T](kind: Empty)

proc treeSeq*(value: auto): auto =
  when value is TreeSeq:
    return value
  else:
    return TreeSeq[type(value)](kind: Single, value: value)

proc len*(tree: TreeSeq): int32 =
  case tree.kind
  of Empty:
    return 0
  of Single:
    return 1
  of Double:
    return tree.sizeCache
  of Repeat:
    return tree.sub.len * tree.count

proc `[]`*[T](tree: TreeSeq[T], index: SomeInteger): T =
  when compileOption("boundChecks"):
    if unlikely(index < 0 or index >= tree.len):
      raise newException(
        IndexDefect, fmt"TreeSeq index {index} is out of bounds (length is: {tree.len})"
      )

  case tree.kind
  of Empty:
    discard
  of Single:
    return tree.value
  of Double:
    if index < tree.a.len:
      return tree.a[index]
    else:
      return tree.b[index - tree.a.len]
  of Repeat:
    return tree.sub[index mod tree.sub.len]

proc repeat*[T](value: TreeSeq[T], repeat: SomeInteger): TreeSeq[T] =
  return TreeSeq[T](kind: Repeat, sub: value, count: repeat.int32)

proc treeSeq*(a: auto, b: auto): auto =
  let subA = a.treeSeq
  let subB = b.treeSeq
  return TreeSeq[type(subA[0])](
    kind: Double, a: subA, b: subB, sizeCache: subA.len + subB.len
  )

proc toTreeSeq*(values: openArray[auto], T: typedesc): TreeSeq[T] =
  result = treeSeq(T)
  for value in values:
    result = treeSeq(result, value.treeSeq)

iterator items*[T](tree: TreeSeq[T]): T =
  for i in 0 ..< tree.len:
    yield tree[i]
