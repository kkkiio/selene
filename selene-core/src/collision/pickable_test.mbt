///|
fn reset_pickable_test_state() -> Unit {
  pickables().clear()
  shapes().clear()
  pointer_event_bus.clear()
  @position.positions().clear()
  @inputs.mouse.pos = @math.Vec2D(0.0, 0.0)
  @inputs.mouse.left_button = false
  @inputs.mouse.right_button = false
  @inputs.mouse.middle_button = false
  @inputs.advanced_mouse_system(0.0)
  @camera.set_limits()
}

///|
fn create_pickable_rect_entity(
  position : @math.Vec2D,
  size : @math.Vec2D,
  is_ui? : Bool = false,
) -> @entity.Entity {
  let entity = @entity.Entity::new()
  ignore(is_ui)
  pickables().set(entity, Pickable::new())
  @position.positions().set(entity, @position.Position(position))
  shapes().set(entity, Rect(size~, offset=@math.Vec2D::zero()))
  entity
}

///|
fn click_left_on_pos(pos : @math.Vec2D, interval : Double) -> Unit {
  @inputs.mouse.pos = pos
  @inputs.mouse.left_button = true
  @inputs.advanced_mouse_system(0.0)
  pickable_click_system(interval)
  @inputs.mouse.left_button = false
  @inputs.advanced_mouse_system(0.0)
  pickable_click_system(0.0)
}

///|
test "is_hover returns true for world entity hit by mouse" {
  reset_pickable_test_state()
  defer pickable_click_system(1.0)
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  @inputs.mouse.pos = @math.Vec2D(15.0, 15.0)
  @inputs.advanced_mouse_system(0.0)
  pickable_click_system(0.0)
  assert_true(is_hover(entity))
}

///|
test "is_hover returns false for world entity missed by mouse" {
  reset_pickable_test_state()
  defer pickable_click_system(1.0)
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  @inputs.mouse.pos = @math.Vec2D(100.0, 100.0)
  @inputs.advanced_mouse_system(0.0)
  pickable_click_system(0.0)
  assert_false(is_hover(entity))
}

///|
test "is_hover resets to false after mouse leaves entity" {
  reset_pickable_test_state()
  defer pickable_click_system(1.0)
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  @inputs.mouse.pos = @math.Vec2D(15.0, 15.0)
  @inputs.advanced_mouse_system(0.0)
  pickable_click_system(0.0)
  assert_true(is_hover(entity))

  @inputs.mouse.pos = @math.Vec2D(100.0, 100.0)
  @inputs.advanced_mouse_system(0.0)
  pickable_click_system(0.0)
  assert_false(is_hover(entity))
}

///|
test "double click emits DoubleClicked within time window" {
  reset_pickable_test_state()
  defer pickable_click_system(1.0)
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  let reader : @event.EventReader[PointerEvent] = @event.EventReader::new()

  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.01)
  ignore(@event.read(reader, pointer_event_bus))

  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.1)
  let events = @event.read(reader, pointer_event_bus)
  let has_double = events.any(fn(event) {
    event.entity == entity &&
    event.button == @inputs.MouseButton::Left &&
    event.phase == DoubleClicked
  })
  assert_true(has_double)
}

///|
test "double click does not emit when interval is too long" {
  reset_pickable_test_state()
  defer pickable_click_system(1.0)
  create_pickable_rect_entity(@math.Vec2D(10.0, 10.0), @math.Vec2D(20.0, 20.0))
  |> ignore
  let reader : @event.EventReader[PointerEvent] = @event.EventReader::new()

  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.01)
  ignore(@event.read(reader, pointer_event_bus))

  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.3)
  let events = @event.read(reader, pointer_event_bus)
  let has_double = events.any(fn(event) { event.phase == DoubleClicked })
  assert_false(has_double)
}

///|
test "pointer_event_bus entity observers receive targeted events" {
  reset_pickable_test_state()
  defer pickable_click_system(1.0)
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  let received : Array[PointerPhase] = []
  let handle = @event.observe_entity(pointer_event_bus, entity, fn(trigger) {
    received.push(trigger.event.phase)
  })
  defer @event.unobserve(pointer_event_bus, handle)

  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.01)
  @event.event_observer_dispatch_system(0.0)
  assert_true(received.contains(JustPressed))
  assert_true(received.contains(JustReleased))
}
