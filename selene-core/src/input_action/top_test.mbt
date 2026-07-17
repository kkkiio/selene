///|
test "action bindings and edge state are isolated by world" {
  let previous_world = @ecs.current_world()
  let first_world = @ecs.World()
  let second_world = @ecs.World()
  defer (match previous_world {
    Some(previous) => @ecs.set_current_world(previous)
    None => @ecs.clear_current_world()
  })
  defer @inputs.clear_virtual_controls()
  let action = @input_action.InputAction("world-isolated-action")
  let button = @inputs.VirtualButton("world-isolated-button")

  @ecs.set_current_world(first_world)
  @input_action.clear_all_action_bindings()
  @input_action.bind_action(action, @input_action.VirtualButton(button))
  @inputs.set_virtual_button_pressed(button, true)
  @input_action.input_action_system(0.0)
  inspect(@input_action.action_pressed(action), content="true")
  inspect(@input_action.action_just_pressed(action), content="true")

  @ecs.set_current_world(second_world)
  inspect(@input_action.action_pressed(action), content="false")
  @input_action.bind_action(action, @input_action.VirtualButton(button))
  @input_action.input_action_system(0.0)
  inspect(@input_action.action_pressed(action), content="true")
  inspect(@input_action.action_just_pressed(action), content="true")
  @input_action.clear_all_action_bindings()
  inspect(@input_action.action_pressed(action), content="false")

  @ecs.set_current_world(first_world)
  inspect(@input_action.action_pressed(action), content="true")
  @input_action.input_action_system(0.0)
  inspect(@input_action.action_just_pressed(action), content="false")
  @inputs.set_virtual_button_pressed(button, false)
  @input_action.input_action_system(0.0)
  inspect(@input_action.action_just_released(action), content="true")

  @ecs.set_current_world(second_world)
  inspect(@input_action.action_just_released(action), content="false")
}
