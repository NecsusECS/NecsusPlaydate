import std/[unittest, options], necsus, necsuspd/[choices, util], vmath, graphics_stub

type Selection = string

template runTest(name: string, body: untyped) =
  runSystemOnce do(
    choices {.inject.}: Choices[Selection],
    create {.inject.}: FullSpawn[(Selection, Animation, ChosenAnim)],
    createBare {.inject.}: FullSpawn[(Selection,)],
    createOther {.inject.}: FullSpawn[(int, Animation, ChosenAnim)],
    getAnim {.inject.}: Lookup[(Animation,)]
  ) -> void:
    let animA {.inject.}: ChosenAnim = (newAnimationDef(1), newAnimationDef(2))
    let animB {.inject.}: ChosenAnim = (newAnimationDef(3), newAnimationDef(4))

    template createStdEntities() {.inject.} =
      let a {.inject.} =
        create.with("a", newAnimation("foo", 10, 10, animA.inactive), animA)
      let b {.inject.} =
        create.with("b", newAnimation("bar", 10, 10, animB.inactive), animB)

    test name:
      body

proc `==`(state: Option[(Animation,)], def: AnimationDef): bool =
  state.isSome and state.get()[0].def == def

proc `$`(state: Option[(Animation,)]): string =
  state.mapIt("some(" & $it[0].def & ")").get("none()")

runTest "Start with nothing selected":
  check choices.chosen == none(Selection)

runTest "Choose a new value":
  createStdEntities()
  check a.getAnim == animA.inactive
  check b.getAnim == animB.inactive

  choices.choose(a)
  check choices.chosen == some("a")
  check a.getAnim == animA.active
  check b.getAnim == animB.inactive

  choices.choose(b)
  check choices.chosen == some("b")
  check a.getAnim == animA.inactive
  check b.getAnim == animB.active

  choices.choose(a)
  check choices.chosen == some("a")
  check a.getAnim == animA.active
  check b.getAnim == animB.inactive

runTest "Marking an unrelated class shouldn't affect the choice":
  createStdEntities()

  let anims: ChosenAnim = (newAnimationDef(5), newAnimationDef(6))

  let other = createOther.with(1, newAnimation("baz", 10, 10, anims.inactive), anims)

  choices.choose(a)
  choices.choose(other)

  check choices.chosen == some("a")

runTest "Choices without an animation should still work":
  let foo = createBare.with("foo")
  let bar = createBare.with("bar")
  choices.choose(foo)
  check choices.chosen == some("foo")
  choices.choose(bar)
  check choices.chosen == some("bar")
