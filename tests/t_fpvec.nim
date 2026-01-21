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

suite "rayPointsAtCircle":
  test "Ray points directly at circle and hits":
    check rayPointsAtCircle(fpvec2(0, 0), fpvec2(1, 0), fpvec2(5, 0), 1.0.fp)

  test "Ray points away from circle":
    check not rayPointsAtCircle(fpvec2(0, 0), fpvec2(-1, 0), fpvec2(5, 0), 1.0.fp)

  test "Ray starts inside circle":
    check rayPointsAtCircle(fpvec2(5, 0), fpvec2(1, 0), fpvec2(5, 0), 1.0.fp)

  test "Ray grazes circle tangentially":
    check rayPointsAtCircle(fpvec2(0, 1), fpvec2(1, 0), fpvec2(5, 0), 1.0.fp)

  test "Degenerate ray inside circle":
    check rayPointsAtCircle(fpvec2(5, 0), fpvec2(0, 0), fpvec2(5, 0), 1.0.fp)

  test "Degenerate ray outside circle":
    check not rayPointsAtCircle(fpvec2(0, 0), fpvec2(0, 0), fpvec2(5, 0), 1.0.fp)

  test "Ray hits only with larger radius":
    check rayPointsAtCircle(fpvec2(0, 0), fpvec2(1, 0), fpvec2(5, 2), 3.0)

suite "rayPointsTowards":
  test "Ray points directly at target (minDot = 1)":
    check rayPointsTowards(fpvec2(0, 0), fpvec2(1, 0), fpvec2(10, 0), 1.0.fp)

  test "Ray points away from target (minDot = -1)":
    check rayPointsTowards(fpvec2(0, 0), fpvec2(-1, 0), fpvec2(10, 0), -1.0.fp)
    check not rayPointsTowards(fpvec2(0, 0), fpvec2(-1, 0), fpvec2(10, 0), -0.99.fp)

  test "Ray is perpendicular to target (minDot = 0)":
    check rayPointsTowards(fpvec2(0, 0), fpvec2(0, 1), fpvec2(10, 0), 0.0.fp)
    check not rayPointsTowards(fpvec2(0, 0), fpvec2(0, 1), fpvec2(10, 0), 0.5.fp)

  test "Degenerate direction (zero vector)":
    check not rayPointsTowards(fpvec2(0, 0), fpvec2(0, 0), fpvec2(10, 0), 0.0.fp)

  test "Degenerate toTarget (origin == target)":
    check rayPointsTowards(fpvec2(5, 5), fpvec2(1, 0), fpvec2(5, 5), -1.0.fp)
    check rayPointsTowards(fpvec2(5, 5), fpvec2(1, 0), fpvec2(5, 5), 0.0.fp)
