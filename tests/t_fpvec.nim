import unittest, necsuspd/fpvec

suite "rayPointsAtLine tests":
  test "ray hits segment normally":
    check rayPointsAtLine(fpvec2(0, 0), fpvec2(1, 1), fpvec2(0, 1), fpvec2(2, 1))

  test "ray misses segment (wrong direction)":
    check not rayPointsAtLine(fpvec2(0, 0), fpvec2(-1, -1), fpvec2(0, 1), fpvec2(2, 1))

  test "ray misses segment (segment behind origin)":
    check not rayPointsAtLine(fpvec2(0, 0), fpvec2(1, 0), fpvec2(-2, 1), fpvec2(-2, -1))

  test "ray collinear with segment and overlaps":
    check rayPointsAtLine(fpvec2(0, 0), fpvec2(1, 0), fpvec2(1, 0), fpvec2(3, 0))

  test "ray collinear with segment but pointing away":
    check not rayPointsAtLine(fpvec2(0, 0), fpvec2(-1, 0), fpvec2(1, 0), fpvec2(3, 0))

  test "ray collinear and starting inside segment":
    check rayPointsAtLine(fpvec2(2, 0), fpvec2(1, 0), fpvec2(1, 0), fpvec2(3, 0))

  test "ray intersects at segment endpoint":
    check rayPointsAtLine(fpvec2(0, 0), fpvec2(1, 0), fpvec2(1, 0), fpvec2(1, 2))

  test "degenerate segment (zero length), ray points at it":
    check rayPointsAtLine(fpvec2(0, 0), fpvec2(1, 1), fpvec2(1, 1), fpvec2(1, 1))

  test "degenerate segment (zero length), ray misses":
    check not rayPointsAtLine(fpvec2(0, 0), fpvec2(1, 0), fpvec2(1, 1), fpvec2(1, 1))

  test "ray origin is exactly at segment endpoint, points along segment":
    check rayPointsAtLine(fpvec2(1, 1), fpvec2(1, 0), fpvec2(1, 1), fpvec2(3, 1))

  test "ray grazes segment at endpoint":
    check rayPointsAtLine(fpvec2(0, 0), fpvec2(1, 1), fpvec2(1, 1), fpvec2(2, 1))

  test "ray is parallel but not collinear":
    check not rayPointsAtLine(fpvec2(0, 0), fpvec2(1, 0), fpvec2(0, 1), fpvec2(2, 1))

  test "ray is nearly parallel and intersects":
    check rayPointsAtLine(
      fpvec2(0, 0), fpvec2(1000, 1), fpvec2(500, 1), fpvec2(1500, 1)
    )
