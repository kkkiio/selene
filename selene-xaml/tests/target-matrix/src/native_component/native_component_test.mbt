///|
test "COMPONENT-NATIVE-01 native loader projects component state into public Selene stores" {
  let previous_world = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  defer @ecs.set_current_world(previous_world)
  let parent = @entity.Entity()
  @ui.nodes()[parent] = @ui.Node(
    width=@ui.Val::Px(960.0),
    height=@ui.Val::Px(540.0),
  )
  let state : Json = {
    "score": 18420,
    "remaining_seconds": 73,
    "wave": 6,
    "level": 12,
    "experience": 78,
    "experience_goal": 100,
    "level_up_visible": true,
    "game_over_visible": false,
    "victory": false,
    "selections": [
      {
        "key": "attack",
        "label": "Attack +20%",
        "icon": "",
        "background": "#9c3d54",
      },
      {
        "key": "range",
        "label": "Range +25%",
        "icon": "",
        "background": "#356d8d",
      },
      {
        "key": "speed",
        "label": "Speed +15%",
        "icon": "",
        "background": "#497a4a",
      },
    ],
  }
  let component = @component_loader.NativeUiComponent::load(
    Survivors,
    "../../examples/wasm-component/component/dist/survivors-ui.component.wasm",
  )
  component.mount(parent, state)
  let view_host = @component_host.SeleneHost::new()
  let range = view_host.entity(parent, "selection:range").unwrap()
  component.replace(parent, state)
  component.apply(parent, [
    {
      "SelectionUpsert": {
        "key": "range",
        "label": "Range +30%",
        "icon": "",
        "background": "#315f82",
      },
    },
  ])
  let action = component.handle_event(parent, { "Click": "selection:range" })
  debug_inspect(
    (
      @ui.texts()[view_host.entity(parent, "score").unwrap()].content,
      @ui.texts()[view_host.entity(parent, "selection:range:label").unwrap()].content,
      view_host.entity(parent, "selection:range").unwrap() == range,
      action,
    ),
    content=(
      #|("Score: 18420", "Range +30%", true, "{\"SelectPowerup\":\"range\"}")
    ),
  )
  parent.destroy()
  component.update()
  component.unload()
}
