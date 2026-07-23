///|
test "SURVIVORS-01 generated view preserves local identity and routes typed actions" {
  let previous_world = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  defer @ecs.set_current_world(previous_world)
  let parent = @entity.Entity()
  @ui.nodes()[parent] = @ui.Node(
    width=@ui.Val::Px(480.0),
    height=@ui.Val::Px(320.0),
  )
  let initial : @view.SurvivorsUiState = {
    score: 10,
    remaining_seconds: 90,
    wave: 2,
    level: 3,
    experience: 4,
    experience_goal: 8,
    level_up_visible: true,
    game_over_visible: false,
    victory: false,
    selections: [
      { key: "attack", label: "Attack", icon: "attack.png", background: "red" },
      { key: "speed", label: "Speed", icon: "speed.png", background: "blue" },
    ],
  }
  let host = @ui_view.ViewHost::new()
  @view.SurvivorsView::mount(parent, initial)
  let speed = host
    .entity(parent, "selection-list/selections:speed/selection-button")
    .unwrap()
  let speed_label = host
    .entity(parent, "selection-list/selections:speed/label")
    .unwrap()
  debug_inspect(
    (
      @ui.texts()[host.entity(parent, "level").unwrap()].content,
      @ui.texts()[speed_label].content,
    ),
    content=(
      #|("Level: 3", "Speed")
    ),
  )
  @view.SurvivorsView::replace(parent, {
    ..initial,
    selections: [initial.selections[1], initial.selections[0]],
  })
  inspect(
    host
    .entity(parent, "selection-list/selections:speed/selection-button")
    .unwrap() ==
    speed,
    content="true",
  )
  @view.SurvivorsView::apply(parent, [
    @view.SurvivorsUiPatch::SelectionUpsert({
      key: "speed",
      label: "Speed +15%",
      icon: "speed.png",
      background: "green",
    }),
    @view.SurvivorsUiPatch::SelectionMove(("speed", 1U)),
  ])
  inspect(@ui.texts()[speed_label].content, content="Speed +15%")
  @view.SurvivorsView::replace(parent, {
    ..initial,
    score: 25,
    level_up_visible: false,
    game_over_visible: true,
    victory: true,
  })
  debug_inspect(
    (
      host.entity(parent, "level-up-panel") is None,
      host.entity(parent, "game-over-panel") is Some(_),
      @ui.texts()[host.entity(parent, "final-score").unwrap()].content,
    ),
    content=(
      #|(true, true, "Final Score: 25")
    ),
  )
  host.unmount(parent)
  parent.destroy()
}
