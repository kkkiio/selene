///|
let live_survivors_entity : Ref[@entity.Entity?] = { val: None }

///|
let live_survivors_state : Ref[@model.SurvivorsUiState?] = { val: None }

///|
let survivors_event_reader : @event.EventReader[
  @survivors_view.SurvivorsViewActionEvent,
] = @event.EventReader()

///|
extern "js" fn mark_survivors_mounted() -> Unit =
  #| () => { globalThis.__seleneSurvivorsExample = { mounted: true }; }

///|
fn to_view_state(
  state : @model.SurvivorsUiState,
) -> @survivors_view.SurvivorsUiState {
  {
    score: state.score,
    remaining_seconds: state.remaining_seconds,
    wave: state.wave,
    level: state.level,
    experience: state.experience,
    experience_goal: state.experience_goal,
    level_up_visible: state.level_up_visible,
    game_over_visible: state.game_over_visible,
    victory: state.victory,
    selections: state.selections.map(selection => {
      let projected : @survivors_view.Selection = {
        key: selection.key,
        label: selection.label,
        icon: selection.icon,
        background: selection.background,
      }
      projected
    }),
  }
}

///|
fn showcase_state() -> @model.SurvivorsUiState {
  {
    score: 12800,
    remaining_seconds: 163,
    wave: 7,
    level: 12,
    experience: 64,
    experience_goal: 100,
    level_up_visible: true,
    game_over_visible: false,
    victory: false,
    selections: [
      {
        key: "attack",
        label: "Attack +20%",
        icon: "../assets/survivors/icon/powerup_attack.png",
        background: "#315a34",
      },
      {
        key: "speed",
        label: "Speed +15%",
        icon: "../assets/survivors/icon/powerup_speed.png",
        background: "#31506b",
      },
    ],
  }
}

///|
fn setup_survivors_view(_world : @ecs.World) -> Unit {
  try {
    let parent = @entity.Entity()
    @ui.nodes()[parent] = @ui.Node(
      width=@ui.Val::Px(480.0),
      height=@ui.Val::Px(320.0),
    )
    let state = showcase_state()
    @survivors_view.SurvivorsView::mount(parent, to_view_state(state))
    live_survivors_state.val = Some(state)
    live_survivors_entity.val = Some(parent)
    mark_survivors_mounted()
  } catch {
    error => abort(error.to_string())
  }
}

///|
fn dispatch_survivors_events(_world : @ecs.World) -> Unit {
  guard live_survivors_entity.val is Some(entity) &&
    live_survivors_state.val is Some(state) else {
    return
  }
  for envelope in survivors_event_reader.read(@survivors_view.action_event_bus) {
    if envelope.entity != entity {
      continue
    }
    try {
      match envelope.action {
        SelectPowerup(_) => {
          let next = { ..state, level_up_visible: false }
          @survivors_view.SurvivorsView::replace(entity, to_view_state(next))
          live_survivors_state.val = Some(next)
        }
        Restart => {
          let next = { ..showcase_state(), level_up_visible: false }
          @survivors_view.SurvivorsView::replace(entity, to_view_state(next))
          live_survivors_state.val = Some(next)
        }
      }
    } catch {
      error => abort(error.to_string())
    }
  }
}

///|
fn main {
  @selene_app.App()
  .with_viewport_width(480.0)
  .with_viewport_height(320.0)
  .with_zoom(2.0)
  .with_fps(60)
  .add_plugin(@plugins.default_plugin)
  .add_plugin(@survivors_view.plugin)
  .add_system(@system.Startup, setup_survivors_view)
  .add_system(
    @system.PostUpdate,
    dispatch_survivors_events,
    system_name="survivors_view_actions",
  )
  .run()
}
