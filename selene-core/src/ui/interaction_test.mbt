///|
test "focus scopes constrain and restore device-independent navigation" {
  let previous = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  let spawn = fn(x : Double, y : Double) {
    let entity = @entity.Entity()
    let rect : @math.Rect = {
      position: @math.Vec2(x, y),
      size: @math.Vec2(40.0, 40.0),
    }
    @ui.nodes()[entity] = @ui.Node()
    @ui.global_ui_nodes()[entity] = {
      logical_rect: rect,
      screen_rect: rect,
      logical_content_rect: rect,
      screen_content_rect: rect,
      target_camera: None,
      target_viewport: {
        position: @math.Vec2(0.0, 0.0),
        size: @math.Vec2(400.0, 400.0),
      },
    }
    @ui.buttons()[entity] = @ui.Button()
    @ui.focusables()[entity] = @ui.Focusable()
    entity
  }
  let external = spawn(300.0, 20.0)
  let root = @entity.Entity()
  @ui.nodes()[root] = @ui.Node()
  let first = spawn(20.0, 20.0)
  let second = spawn(80.0, 20.0)
  let below = spawn(80.0, 80.0)
  first.set_parent(root)
  second.set_parent(root)
  below.set_parent(root)
  @ui.tab_indexes()[first] = @ui.TabIndex(0)
  @ui.tab_indexes()[second] = @ui.TabIndex(1)
  @ui.tab_indexes()[below] = @ui.TabIndex(2)
  @ui.focus(external)
  @ui.focus_scopes().push(@ui.FocusScope(root, initial_focus=Some(second)))
  assert_eq(@ui.focused_entity(), Some(second))
  @ui.focus(external)
  assert_eq(@ui.focused_entity(), Some(second))
  assert_eq(@ui.navigate(Previous), true)
  assert_eq(@ui.focused_entity(), Some(first))
  assert_eq(@ui.navigate(Move(Right)), true)
  assert_eq(@ui.focused_entity(), Some(second))
  @ui.navigation_handlers()[second] = fn(action) {
    action == @ui.UiNavigationAction::Move(Right)
  }
  assert_eq(@ui.navigate(Move(Right)), true)
  assert_eq(@ui.focused_entity(), Some(second))
  @ui.navigation_handlers().remove(second)
  @ui.navigation_handlers()[root] = fn(action) {
    action == @ui.UiNavigationAction::Cancel
  }
  assert_eq(@ui.navigate(Cancel), true)
  assert_eq(@ui.focused_entity(), Some(second))
  @ui.navigation_handlers().remove(root)
  assert_eq(@ui.navigate(Move(Down)), true)
  assert_eq(@ui.focused_entity(), Some(below))
  @ui.tab_indexes()[below] = @ui.TabIndex(-1)
  @ui.focus(below)
  assert_eq(@ui.navigate(Next), true)
  assert_eq(@ui.focused_entity(), Some(first))
  @ui.focus(below)

  let nested_root = @entity.Entity()
  @ui.nodes()[nested_root] = @ui.Node()
  let nested_action = spawn(160.0, 160.0)
  nested_action.set_parent(nested_root)
  @ui.focus_scopes().push(
    @ui.FocusScope(nested_root, initial_focus=Some(nested_action)),
  )
  assert_eq(@ui.focused_entity(), Some(nested_action))
  ignore(@ui.focus_scopes().pop())
  assert_eq(@ui.focused_entity(), Some(below))
  ignore(@ui.focus_scopes().pop())
  assert_eq(@ui.focused_entity(), Some(external))

  for
    entity in [external, first, second, below, nested_action, root, nested_root] {
    @ui.nodes().remove(entity)
    @ui.global_ui_nodes().remove(entity)
    @ui.buttons().remove(entity)
    @ui.focusables().remove(entity)
    @ui.focuseds().remove(entity)
    @ui.tab_indexes().remove(entity)
    if entity.is_alive() {
      entity.destroy()
    }
  }
  @ecs.set_current_world(previous)
}
