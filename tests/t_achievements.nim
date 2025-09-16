import necsuspd/achievements, std/[unittest, options, json], stubs/playdate_api

const sample_data =
  """
{
  "specVersion": "1.0.0",
  "gameID": "dolor.fugiat.dolor.ad",
  "name": "quis cupidatat fugiat ut",
  "author": "laboris deserunt pariatur enim cillum",
  "description": "proident sed officia",
  "version": "1.2.3",
  "achievements": [
    {
      "name": "laboris quis do sed cillum",
      "description": "consectetur pariatur adipisicing irure qui",
      "descriptionLocked": "eu",
      "id": "A",
      "grantedAt": 70219406,
      "icon": "anim culpa veniam",
      "iconLocked": "Lorem tempor",
      "isSecret": true,
      "progressMax": 41101684,
      "progress": 4194246,
      "progressIsPercentage": false,
      "scoreValue": 23706442
    },
    {
      "name": "enim magna aute non",
      "description": "veniam anim ut id elit",
      "id": "B",
      "scoreValue": 20161435
    },
    {
      "name": "laborum aute nulla",
      "description": "sint",
      "descriptionLocked": "et quis",
      "id": "C",
      "iconLocked": "officia esse adipisicing",
      "isSecret": false,
      "progress": 14779483,
      "progressIsPercentage": true
    }
  ]
}
"""

type ExampleAchievements = enum
  A
  B
  C
  D

const app: AppAchievementDef[ExampleAchievements] = defineAchievements[
  ExampleAchievements
](
  gameID = "dolor.fugiat.dolor.ad",
  name = "quis cupidatat fugiat ut",
  author = "laboris deserunt pariatur enim cillum",
  description = "proident sed officia",
  version = "1.2.3",
  achievements = [
    achievement(
      id = A,
      name = "laboris quis do sed cillum",
      description = "consectetur pariatur adipisicing irure qui",
      descriptionLocked = some("eu"),
      icon = some("anim culpa veniam"),
      iconLocked = some("Lorem tempor"),
      isSecret = true,
      progressMax = some(41101684),
      scoreValue = some(23706442),
    ),
    achievement(
      id = B,
      name = "enim magna aute non",
      description = "veniam anim ut id elit",
      scoreValue = some(20161435),
    ),
    achievement(
      id = C,
      name = "laborum aute nulla",
      description = "sint",
      descriptionLocked = some("et quis"),
      iconLocked = some("officia esse adipisicing"),
      progressIsPercentage = true,
    ),
    achievement(
      id = D,
      name = "amet Excepteur laboris ullamco dolor",
      description = "nisi",
      descriptionLocked = some("cupidatat do magna officia"),
      iconLocked = some("dolore ex incididunt dolore ad"),
      progressMax = some(38236980),
      progressIsPercentage = true,
      scoreValue = some(50332214),
    ),
  ],
)

const sample_path = "/Shared/Achievements/dolor.fugiat.dolor.ad/Achievements.json"

suite "Achievements":
  test "No change to achievements":
    withMockFiles({sample_path: sample_data}):
      let state = app.load()
      app.save(newSeq[(ExampleAchievements, AchievementState)]())
      check(state == app.load())

  test "Reading achievements":
    withMockFiles({sample_path: sample_data}):
      let state = app.load()
      check(state[A] == AchievementGranted.init(70219406).AchievementState)
      check(state[B] == AchievementLocked.init().AchievementState)
      check(state[C] == AchievementInProgress.init(14779483).AchievementState)
      check(state[D] == AchievementLocked.init().AchievementState)

  test "Writing achievements":
    withMockFiles({sample_path: sample_data}):
      app.save(B, AchievementInProgress.init(12345))
      app.save(D, AchievementGranted.init(123456))

      let state = app.load()
      check(state[A] == AchievementGranted.init(70219406).AchievementState)
      check(state[B] == AchievementInProgress.init(12345).AchievementState)
      check(state[C] == AchievementInProgress.init(14779483).AchievementState)
      check(state[D] == AchievementGranted.init(123456).AchievementState)

  test "Don't overwrite with lesser achievements":
    withMockFiles({sample_path: sample_data}):
      app.save(A, AchievementGranted.init(80000000))
      app.save(C, AchievementInProgress.init(10000))

      let state = app.load()
      check(state[A] == AchievementGranted.init(70219406).AchievementState)
      check(state[B] == AchievementLocked.init().AchievementState)
      check(state[C] == AchievementInProgress.init(14779483).AchievementState)
      check(state[D] == AchievementLocked.init().AchievementState)

  test "Check if an achievement is granted":
    withMockFiles({sample_path: sample_data}):
      check(app.isGranted(A))
      check(not app.isGranted(B))
      check(not app.isGranted(C))
      check(not app.isGranted(D))

  test "Achievements to string":
    withMockFiles({sample_path: sample_data}):
      let state = app.load()
      check($state == "{A: AchievementGranted(70219406), B: AchievementLocked(), C: AchievementInProgress(14779483), D: AchievementLocked(), }")
