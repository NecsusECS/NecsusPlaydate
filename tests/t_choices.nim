import std/[unittest, options], necsus, necsuspd/choices, vmath, graphics_stub

type Selection = string

template runTest(name: string, body: untyped) =
  runSystemOnce do(
    choices {.inject.}: Choices[Selection],
    create {.inject.}: FullSpawn[(Selection, Animation, ChosenAnim)]
  ) -> void:
    test name:
      body

runTest "Start with nothing selected":
  check choices.chosen == none(Selection)

runTest "Choose a new value":
  let a = create.with(
    "a", newAnimation("foo", 10, 10), (newAnimationDef(1), newAnimationDef(2))
  )

  let b = create.with(
    "b", newAnimation("bar", 10, 10), (newAnimationDef(3), newAnimationDef(4))
  )

  choices.choose(a)
  check choices.chosen == some("a")

  choices.choose(b)
  check choices.chosen == some("b")

  choices.choose(a)
  check choices.chosen == some("a")
