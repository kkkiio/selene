///|
test "virtual button binding drives action edges" {
  clear_all_action_bindings()
  @inputs.clear_virtual_controls()
  let action = InputAction("jump")
  let button = @inputs.VirtualButton("jump-button")
  bind_action(action, VirtualButton(button))
  input_action_system(0.0)
  inspect(action_pressed(action), content="false")
  @inputs.set_virtual_button_pressed(button, true)
  input_action_system(0.0)
  inspect(action_pressed(action), content="true")
  inspect(action_just_pressed(action), content="true")
  @inputs.set_virtual_button_pressed(button, false)
  input_action_system(0.0)
  inspect(action_pressed(action), content="false")
  inspect(action_just_released(action), content="true")
  clear_all_action_bindings()
  @inputs.clear_virtual_controls()
}

///|
test "virtual axis binding applies dead zone and direction" {
  clear_all_action_bindings()
  @inputs.clear_virtual_controls()
  let positive_action = InputAction("move-right")
  let negative_action = InputAction("move-left")
  let axis = @inputs.VirtualAxis("move-x")
  bind_action(positive_action, VirtualAxis(axis, dead_zone=0.2, positive=true))
  bind_action(negative_action, VirtualAxis(axis, dead_zone=0.2, positive=false))
  @inputs.set_virtual_axis_value(axis, 0.1)
  input_action_system(0.0)
  inspect(action_value(positive_action), content="0")
  @inputs.set_virtual_axis_value(axis, 0.75)
  input_action_system(0.0)
  inspect(action_value(positive_action), content="0.75")
  inspect(action_value(negative_action), content="0")
  @inputs.set_virtual_axis_value(axis, -0.5)
  input_action_system(0.0)
  inspect(action_value(positive_action), content="0")
  inspect(action_value(negative_action), content="0.5")
  clear_all_action_bindings()
  @inputs.clear_virtual_controls()
}

///|
test "pointer primary binding follows primary pointer state" {
  clear_all_action_bindings()
  @inputs.apply_input_snapshot(@inputs.empty_input_snapshot())
  let action = InputAction("primary")
  bind_action(action, PointerPrimary)
  @inputs.mouse.left_button = true
  input_action_system(0.0)
  inspect(action_pressed(action), content="true")
  clear_all_action_bindings()
  @inputs.apply_input_snapshot(@inputs.empty_input_snapshot())
}

///|
test "any gamepad button binding includes nonzero device indexes" {
  clear_all_action_bindings()
  @inputs.apply_input_snapshot(@inputs.empty_input_snapshot())
  let action = InputAction("jump")
  let gamepad = @inputs.Gamepad(1)
  let pressed = @inputs.empty_input_snapshot()
  pressed.connected_gamepads.add(gamepad)
  pressed.pressed_gamepad_buttons.add(
    @inputs.GamepadButtonInput(gamepad, South),
  )
  bind_action(action, AnyGamepadButton(South))

  @inputs.apply_input_snapshot(pressed)
  input_action_system(0.0)
  inspect(action_pressed(action), content="true")
  inspect(action_just_pressed(action), content="true")

  @inputs.apply_input_snapshot(@inputs.empty_input_snapshot())
  input_action_system(0.0)
  inspect(action_pressed(action), content="false")
  inspect(action_just_released(action), content="true")
  clear_all_action_bindings()
}

///|
test "any gamepad axis binding applies direction and dead zone" {
  clear_all_action_bindings()
  @inputs.apply_input_snapshot(@inputs.empty_input_snapshot())
  let right = InputAction("move-right")
  let left = InputAction("move-left")
  let gamepad = @inputs.Gamepad(1)
  let snapshot = @inputs.empty_input_snapshot()
  snapshot.connected_gamepads.add(gamepad)
  let axis = @inputs.GamepadAxisInput(gamepad, LeftStickX)
  bind_action(right, AnyGamepadAxis(LeftStickX, dead_zone=0.2, positive=true))
  bind_action(left, AnyGamepadAxis(LeftStickX, dead_zone=0.2, positive=false))

  snapshot.gamepad_axis_values.set(axis, 0.1)
  @inputs.apply_input_snapshot(snapshot)
  input_action_system(0.0)
  inspect(action_value(right), content="0")
  inspect(action_value(left), content="0")

  snapshot.gamepad_axis_values.set(axis, -0.75)
  @inputs.apply_input_snapshot(snapshot)
  input_action_system(0.0)
  inspect(action_value(right), content="0")
  inspect(action_value(left), content="0.75")
  clear_all_action_bindings()
  @inputs.apply_input_snapshot(@inputs.empty_input_snapshot())
}
