import std/[unittest, options], necsuspd/[intersects, fpvec], fixedpoint

suite "intersects(point, circle)":
  test "point exactly on the circle's edge":
    check(
      intersection(fpvec2(2, 0).point, circle(fpvec2(1, 0), fp(1))) == some(
        fpvec2(2, 0)
      )
    )

  test "point inside the circle":
    check(
      intersection(fpvec2(1.5, 0).point, circle(fpvec2(1, 0), fp(1))) == none(FPVec2)
    )

  test "point outside the circle":
    check(intersection(fpvec2(3, 0).point, circle(fpvec2(1, 0), fp(1))) == none(FPVec2))

  test "point at the center of the circle":
    check(intersection(fpvec2(1, 0).point, circle(fpvec2(1, 0), fp(1))) == none(FPVec2))

  test "point on the edge with negative coordinates":
    check(
      intersection(fpvec2(0, 0).point, circle(fpvec2(1, 0), fp(1))) == some(
        fpvec2(0, 0)
      )
    )

suite "intersects(segment, circle)":
  test "no intersection: segment outside circle":
    check(
      intersection(segment(fpvec2(0, 0), fpvec2(1, 0)), circle(fpvec2(5, 0), fp(1))) ==
        none(FPVec2)
    )

  test "tangent: segment just touches circle":
    check(
      intersection(segment(fpvec2(0, 1), fpvec2(2, 1)), circle(fpvec2(1, 0), fp(1))) ==
        some(fpvec2(1, 1))
    )

  test "segment passes through circle":
    check(
      intersection(segment(fpvec2(0, 0), fpvec2(2, 0)), circle(fpvec2(1, 0), fp(1))) ==
        some(fpvec2(0, 0))
    ) # First intersection at x=0

  test "segment starts inside circle and exits":
    check(
      intersection(segment(fpvec2(1, 0), fpvec2(3, 0)), circle(fpvec2(1, 0), fp(1))) ==
        some(fpvec2(2, 0))
    ) # Exits at x=2

  test "segment ends inside circle and enters":
    check(
      intersection(segment(fpvec2(3, 0), fpvec2(1, 0)), circle(fpvec2(1, 0), fp(1))) ==
        some(fpvec2(2, 0))
    ) # Enters at x=2

  test "segment entirely inside circle":
    check(
      intersection(
        segment(fpvec2(0.5, 0.0), fpvec2(0.8, 0.0)), circle(fpvec2(1, 0), fp(1))
      ) == none(FPVec2)
    ) # No intersection with boundary

  test "segment is a point on the circle's edge":
    check(
      intersection(segment(fpvec2(2, 0), fpvec2(2, 0)), circle(fpvec2(1, 0), fp(1))) ==
        some(fpvec2(2, 0))
    )
