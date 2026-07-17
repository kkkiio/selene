///|
test "any gamepad button queries include nonzero device indexes" {
  let previous = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  let gamepad = Gamepad(1)
  let input = GamepadButtonInput(gamepad, South)
  let pressed = empty_input_snapshot()
  pressed.connected_gamepads.add(gamepad)
  pressed.pressed_gamepad_buttons.add(input)

  apply_input_snapshot(pressed)
  advanced_gamepad_system(0.0)
  inspect(is_any_gamepad_button_pressed(South), content="true")
  inspect(is_any_gamepad_button_just_pressed(South), content="true")
  inspect(is_any_gamepad_button_just_released(South), content="false")

  advanced_gamepad_system(0.0)
  inspect(is_any_gamepad_button_just_pressed(South), content="false")

  let released = empty_input_snapshot()
  released.connected_gamepads.add(gamepad)
  apply_input_snapshot(released)
  advanced_gamepad_system(0.0)
  inspect(is_any_gamepad_button_pressed(South), content="false")
  inspect(is_any_gamepad_button_just_released(South), content="true")
  apply_input_snapshot(empty_input_snapshot())
  advanced_gamepad_system(0.0)

  let disconnected = empty_input_snapshot()
  disconnected.pressed_gamepad_buttons.add(input)
  apply_input_snapshot(disconnected)
  advanced_gamepad_system(0.0)
  inspect(is_any_gamepad_button_pressed(South), content="false")
  inspect(is_any_gamepad_button_just_pressed(South), content="false")

  apply_input_snapshot(empty_input_snapshot())
  advanced_gamepad_system(0.0)
  @ecs.set_current_world(previous)
}
