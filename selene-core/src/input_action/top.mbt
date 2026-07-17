///|
pub(all) struct InputAction {
  name : String
} derive(Eq, Debug, Hash)

///|
pub(all) enum InputBinding {
  Key(@inputs.Code)
  Mouse(@inputs.MouseButton)
  PointerPrimary
  VirtualButton(@inputs.VirtualButton)
  VirtualAxis(
    @inputs.VirtualAxis,
    mut dead_zone~ : Double,
    mut positive~ : Bool
  )
  GamepadButton(@inputs.Gamepad, @inputs.GamepadButton)
  GamepadAxis(
    @inputs.Gamepad,
    @inputs.GamepadAxis,
    mut dead_zone~ : Double,
    mut positive~ : Bool
  )
  AnyGamepadButton(@inputs.GamepadButton)
  AnyGamepadAxis(
    @inputs.GamepadAxis,
    mut dead_zone~ : Double,
    mut positive~ : Bool
  )
}

///|
pub(all) struct ActionState {
  mut pressed : Bool
  mut just_pressed : Bool
  mut just_released : Bool
  mut value : Double
} derive(Eq, Debug)

///|
pub(all) enum ActionEventKind {
  Pressed
  Released
  ValueChanged
} derive(Eq, Debug)

///|
pub(all) struct ActionEvent {
  action : InputAction
  kind : ActionEventKind
  value : Double
} derive(Eq, Debug)

///|
priv struct InputActionWorldStore {
  input_bindings : Map[InputAction, Array[InputBinding]]
  action_states : Map[InputAction, ActionState]
}

///|
let input_action_world_stores : Map[UInt, InputActionWorldStore] = Map([])

///|
fn input_action_world_store() -> InputActionWorldStore {
  let world_id = @ecs.require_current_world().id()
  input_action_world_stores.get_or_init(world_id, () => {
    input_bindings: Map([]),
    action_states: Map([]),
  })
}

///|
pub let input_action_event_bus : @event.Events[ActionEvent] = Events()

///|
pub fn InputAction::InputAction(name : String) -> InputAction {
  { name, }
}

///|
pub fn bind_action(action : InputAction, binding : InputBinding) -> Unit {
  let store = input_action_world_store()
  let bindings = store.input_bindings.get(action).unwrap_or([])
  bindings.push(binding)
  store.input_bindings.set(action, bindings)
  if !store.action_states.contains(action) {
    store.action_states.set(action, {
      pressed: false,
      just_pressed: false,
      just_released: false,
      value: 0.0,
    })
  }
}

///|
pub fn clear_action_bindings(action : InputAction) -> Unit {
  let store = input_action_world_store()
  store.input_bindings.remove(action)
  store.action_states.remove(action)
}

///|
pub fn clear_all_action_bindings() -> Unit {
  let store = input_action_world_store()
  store.input_bindings.clear()
  store.action_states.clear()
}

///|
pub fn action_pressed(action : InputAction) -> Bool {
  input_action_world_store().action_states
  .get(action)
  .map(fn(state) { state.pressed })
  .unwrap_or(false)
}

///|
pub fn action_just_pressed(action : InputAction) -> Bool {
  input_action_world_store().action_states
  .get(action)
  .map(fn(state) { state.just_pressed })
  .unwrap_or(false)
}

///|
pub fn action_just_released(action : InputAction) -> Bool {
  input_action_world_store().action_states
  .get(action)
  .map(fn(state) { state.just_released })
  .unwrap_or(false)
}

///|
pub fn action_value(action : InputAction) -> Double {
  input_action_world_store().action_states
  .get(action)
  .map(fn(state) { state.value })
  .unwrap_or(0.0)
}

///|
fn binding_value(binding : InputBinding) -> Double {
  match binding {
    Key(code) => if @inputs.is_pressed(code) { 1.0 } else { 0.0 }
    Mouse(button) => if @inputs.is_mouse_pressed(button) { 1.0 } else { 0.0 }
    PointerPrimary => if @inputs.primary_pointer_down() { 1.0 } else { 0.0 }
    VirtualButton(button) =>
      if @inputs.is_virtual_button_pressed(button) {
        1.0
      } else {
        0.0
      }
    VirtualAxis(axis, dead_zone~, positive~) =>
      axis_value_with_dead_zone(
        @inputs.virtual_axis_value(axis),
        dead_zone,
        positive,
      )
    GamepadButton(gamepad, button) =>
      if @inputs.is_gamepad_button_pressed(gamepad, button) {
        1.0
      } else {
        0.0
      }
    GamepadAxis(gamepad, axis, dead_zone~, positive~) =>
      axis_value_with_dead_zone(
        @inputs.gamepad_axis_value(gamepad, axis),
        dead_zone,
        positive,
      )
    AnyGamepadButton(button) =>
      if @inputs.is_any_gamepad_button_pressed(button) {
        1.0
      } else {
        0.0
      }
    AnyGamepadAxis(axis, dead_zone~, positive~) => {
      let mut value = 0.0
      for gamepad in @inputs.connected_gamepads() {
        value = @cmp.maximum(
          value,
          axis_value_with_dead_zone(
            @inputs.gamepad_axis_value(gamepad, axis),
            dead_zone,
            positive,
          ),
        )
      }
      value
    }
  }
}

///|
fn axis_value_with_dead_zone(
  axis_value : Double,
  dead_zone : Double,
  positive : Bool,
) -> Double {
  let dead_zone = @cmp.minimum(1.0, @cmp.maximum(0.0, dead_zone))
  let absolute = if axis_value < 0.0 { -axis_value } else { axis_value }
  let filtered = if absolute <= dead_zone { 0.0 } else { axis_value }
  if positive {
    @cmp.maximum(0.0, filtered)
  } else {
    @cmp.maximum(0.0, -filtered)
  }
}

///|
pub fn input_action_system(_delta : Double) -> Unit {
  let store = input_action_world_store()
  for action, bindings in store.input_bindings {
    let previous = store.action_states
      .get(action)
      .unwrap_or({
        pressed: false,
        just_pressed: false,
        just_released: false,
        value: 0.0,
      })
    let mut value = 0.0
    for binding in bindings {
      value = @cmp.maximum(value, binding_value(binding))
    }
    let pressed = value > 0.0
    let just_pressed = pressed && !previous.pressed
    let just_released = !pressed && previous.pressed
    let next_state : ActionState = {
      pressed,
      just_pressed,
      just_released,
      value,
    }
    store.action_states.set(action, next_state)
    if just_pressed {
      input_action_event_bus.send({ action, kind: Pressed, value })
    }
    if just_released {
      input_action_event_bus.send({ action, kind: Released, value })
    }
    let delta = value - previous.value
    let absolute_delta = if delta < 0.0 { -delta } else { delta }
    if absolute_delta > 0.000001 {
      input_action_event_bus.send({ action, kind: ValueChanged, value })
    }
  }
}
