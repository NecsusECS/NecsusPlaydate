import
  necsus,
  positioned,
  vmath,
  easing,
  inputs,
  findDir,
  util,
  time,
  vec_tools,
  playdate/api,
  options

type
  CarouselData[T] = ref object
    target: IVec2
    selected: EntityId
    easing: EasingCalc[Vec2]
    duration: float32
    case animating: bool
    of true:
      startTime: float32
      start: Vec2
    of false:
      discard

  CarouselChanged*[T] = object ## Event sent when a carousel gets a new value

  Carousel*[T] = object
    elements: FullQuery[(T, ptr Positioned)]
    findElem: Lookup[(T, ptr Positioned)]
    onPress: Outbox[T]
    buttons: Inbox[ButtonPushed]
    data: Shared[CarouselData[T]]
    time: GameTime
    changed: Outbox[CarouselChanged[T]]

proc firstElement[T](bundle: Bundle[Carousel[T]]): auto =
  ## Return the first element in the carousel
  for eid, (_, positioned) in bundle.elements:
    return some((eid, positioned))
  return none((EntityId, ptr Positioned))

proc moveAllBy[T](bundle: Bundle[Carousel[T]], delta: IVec2) =
  for (_, pos) in bundle.elements:
    pos.pos = pos.toIVec2 + delta

proc reset*[T](
    bundle: Bundle[Carousel[T]],
    target: IVec2,
    easing: EasingCalc[Vec2],
    duration: float32,
) =
  ## Resets the carousel to it's starting state
  for (eid, startPos) in bundle.firstElement:
    bundle.moveAllBy(target - startPos.toIVec2)
    bundle.data :=
      CarouselData[T](
        animating: false,
        target: target,
        selected: eid,
        easing: easing,
        duration: duration,
      )

iterator eligibleCards[T](bundle: Bundle[Carousel[T]]): (Positioned, EntityId) =
  ## An iterator that returns the cards available when choosing a new carousel value
  for eid, (_, pos) in bundle.elements:
    if bundle.data.get.selected != eid:
      yield (pos[], eid)

proc determineSelection[T](bundle: Bundle[Carousel[T]]): Option[EntityId] =
  ## Determine which element is selected
  for data in bundle.data:
    return some(data.selected)
  for (eid, _) in bundle.firstElement:
    return some(eid)
  return none(EntityId)

proc checkNewSelection[T](bundle: Bundle[Carousel[T]]) =
  ## Checks for button presses to determine a new button press
  for data in bundle.data:
    for selected in bundle.determineSelection():
      let origin =
        bundle.findElem(selected).mapIt(it[1][]).orElse(positioned(data.target))

      for button in bundle.buttons:
        for (newPosition, newSelection) in findDir[EntityId](
          eligibleCards(bundle), button, origin
        ):
          bundle.data :=
            CarouselData[T](
              animating: true,
              target: data.target,
              selected: newSelection,
              easing: data.easing,
              duration: data.duration,
              startTime: bundle.time.get(),
              start: newPosition.toVec2,
            )
          bundle.changed(CarouselChanged[T]())

proc runAnimation[T](bundle: Bundle[Carousel[T]]) =
  ## Executes any animations that need to be run
  for data in bundle.data:
    if data.animating:
      let t = (bundle.time.get() - data.startTime) / data.duration
      for (_, selectedPos) in bundle.findElem(data.selected):
        if t <= 1.0:
          let expectPos = data.easing(data.start, data.target.toVec2, t).toIVec2
          bundle.moveAllBy(expectPos - selectedPos.toIVec2)
        else:
          bundle.moveAllBy(data.target - selectedPos.toIVec2)
          bundle.data :=
            CarouselData[T](
              animating: false,
              target: data.target,
              selected: data.selected,
              easing: data.easing,
              duration: data.duration,
            )

proc update*[T](bundle: Bundle[Carousel[T]]) =
  ## Updates the internal state of the carousel
  checkNewSelection(bundle)
  runAnimation(bundle)

  for button in bundle.buttons:
    if button in {kButtonA, kButtonB}:
      for (selected, _) in bundle.determineSelection().flatMapIt(bundle.findElem(it)):
        bundle.onPress(selected)
