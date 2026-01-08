import std/[unittest, options], necsus, necsuspd/[choices, util, sprite], vmath, necsuspd/stubs/graphics, helpers

type Selection = string

template runTest(name: string, body: untyped) =
  runSystemOnce do(
    choices {.inject.}: Choices[Selection],
    create {.inject.}: FullSpawn[(Selection, Animation, ChosenAnim)],
    createBare {.inject.}: FullSpawn[(Selection,)],
    createOther {.inject.}: FullSpawn[(int, Animation, ChosenAnim)],
    getAnim {.inject.}: Lookup[(Animation,)],
    events {.inject.}: Inbox[ChoseEvent[Selection]]
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
  check events.len == 0

runTest "Choose a new value":
  createStdEntities()
  check a.getAnim == animA.inactive
  check b.getAnim == animB.inactive
  check events.len == 0

  choices.choose(a)
  check choices.chosen == some("a")
  check a.getAnim == animA.active
  check b.getAnim == animB.inactive
  check events.len == 1

  choices.choose(b)
  check choices.chosen == some("b")
  check a.getAnim == animA.inactive
  check b.getAnim == animB.active
  check events.len == 2

  choices.choose(a)
  check choices.chosen == some("a")
  check a.getAnim == animA.active
  check b.getAnim == animB.inactive
  check events.len == 3

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

runTest "Choosing the same value should not change the choice":
  createStdEntities()
  check a.getAnim == animA.inactive
  check b.getAnim == animB.inactive
  check events.len == 0

  for _ in 0 .. 4:
    choices.choose(a)
    check choices.chosen == some("a")
    check a.getAnim == animA.active
    check b.getAnim == animB.inactive
    check events.len == 1
