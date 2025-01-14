import unittest, necsuspd/circle

proc draw[N: static int](points: array[N, array[N, int]]): string =
    for y in 0..<N:
        for x in 0..<N:
            if points[y][x] == 0:
                result &= " "
            else:
                result &= "X"
        result &= "\n"

suite "Drawing a circle":

    test "Draw a thicker circle":

        var canvas: array[40, array[40, int]]

        for point in circlePixels(20, 20, 10, 16):
            canvas[point.y][point.x] = 1

        check(canvas.draw ==
            "                                        \n" &
            "                                        \n" &
            "                                        \n" &
            "                                        \n" &
            "                 XXXXXXX                \n" &
            "              XXXXXXXXXXXXX             \n" &
            "            XXXXXXXXXXXXXXXXX           \n" &
            "           XXXXXXXXXXXXXXXXXXX          \n" &
            "          XXXXXXXXXXXXXXXXXXXXX         \n" &
            "         XXXXXXXXXXXXXXXXXXXXXXX        \n" &
            "        XXXXXXXXXXXXXXXXXXXXXXXXX       \n" &
            "       XXXXXXXXXX       XXXXXXXXXX      \n" &
            "      XXXXXXXXX           XXXXXXXXX     \n" &
            "      XXXXXXXX             XXXXXXXX     \n" &
            "     XXXXXXXX               XXXXXXXX    \n" &
            "     XXXXXXX                 XXXXXXX    \n" &
            "     XXXXXXX                 XXXXXXX    \n" &
            "    XXXXXXX                   XXXXXXX   \n" &
            "    XXXXXXX                   XXXXXXX   \n" &
            "    XXXXXXX                   XXXXXXX   \n" &
            "    XXXXXXX                   XXXXXXX   \n" &
            "    XXXXXXX                   XXXXXXX   \n" &
            "    XXXXXXX                   XXXXXXX   \n" &
            "    XXXXXXX                   XXXXXXX   \n" &
            "     XXXXXXX                 XXXXXXX    \n" &
            "     XXXXXXX                 XXXXXXX    \n" &
            "     XXXXXXXX               XXXXXXXX    \n" &
            "      XXXXXXXX             XXXXXXXX     \n" &
            "      XXXXXXXXX           XXXXXXXXX     \n" &
            "       XXXXXXXXXX       XXXXXXXXXX      \n" &
            "        XXXXXXXXXXXXXXXXXXXXXXXXX       \n" &
            "         XXXXXXXXXXXXXXXXXXXXXXX        \n" &
            "          XXXXXXXXXXXXXXXXXXXXX         \n" &
            "           XXXXXXXXXXXXXXXXXXX          \n" &
            "            XXXXXXXXXXXXXXXXX           \n" &
            "              XXXXXXXXXXXXX             \n" &
            "                 XXXXXXX                \n" &
            "                                        \n" &
            "                                        \n" &
            "                                        \n")


    test "Draw a thin circle":

        var canvas: array[20, array[20, int]]

        for point in circlePixels(10, 10, 8, 8):
            canvas[point.y][point.x] = 1

        check(canvas.draw ==
            "                    \n" &
            "                    \n" &
            "        XXXXX       \n" &
            "      XX     XX     \n" &
            "     X         X    \n" &
            "    X           X   \n" &
            "   X             X  \n" &
            "   X             X  \n" &
            "  X               X \n" &
            "  X               X \n" &
            "  X               X \n" &
            "  X               X \n" &
            "  X               X \n" &
            "   X             X  \n" &
            "   X             X  \n" &
            "    X           X   \n" &
            "     X         X    \n" &
            "      XX     XX     \n" &
            "        XXXXX       \n" &
            "                    \n")

    test "Circle with a canvas":

        var canvas: array[20, array[20, int]]

        for point in circlePixels(10, 10, 4, 8, (5'i32, 4'i32, 8'i32, 7'i32)):
            canvas[point.y][point.x] = 1

        check(canvas.draw ==
            "                    \n" &
            "                    \n" &
            "                    \n" &
            "                    \n" &
            "     XXXXXXXX       \n" &
            "     XXXXXXXX       \n" &
            "     XXXXXXXX       \n" &
            "     XXXX   X       \n" &
            "     XXX            \n" &
            "     XX             \n" &
            "     XX             \n" &
            "                    \n" &
            "                    \n" &
            "                    \n" &
            "                    \n" &
            "                    \n" &
            "                    \n" &
            "                    \n" &
            "                    \n" &
            "                    \n")
