///|
fn reset_pickable_test_state() -> Unit {
  pickables.clear()
  shapes.clear()
  @position.positions.clear()
  @ui.uis.clear()
  @inputs.mouse.pos = @math.Vec2D(0.0, 0.0)
  @inputs.mouse.left_button = false
  @inputs.mouse.right_button = false
  @inputs.mouse.middle_button = false
  @inputs.advanced_mouse_system(0.0)
  quadtree_clear_system(0.0)
}

///|
fn create_pickable_rect_entity(
  position : @math.Vec2D,
  size : @math.Vec2D,
  is_ui? : Bool = false,
) -> @entity.Entity {
  let entity = @entity.Entity::new()
  pickables.set(entity, Pickable::new())
  @position.positions.set(entity, @position.Position(position))
  shapes.set(
    entity,
    Rect(size=size, offset=@math.Vec2D::zero()),
  )
  if is_ui {
    @ui.uis.set(entity, @ui.Ui::new())
  }
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
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  @inputs.mouse.pos = @math.Vec2D(15.0, 15.0)
  quadtree_clear_system(0.0)
  pickable_click_system(0.0)
  assert_true(is_hover(entity))
}

///|
test "is_hover returns false for world entity missed by mouse" {
  reset_pickable_test_state()
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  @inputs.mouse.pos = @math.Vec2D(100.0, 100.0)
  quadtree_clear_system(0.0)
  pickable_click_system(0.0)
  assert_false(is_hover(entity))
}

///|
test "is_hover returns true for ui entity hit by mouse" {
  reset_pickable_test_state()
  let entity = create_pickable_rect_entity(
    @math.Vec2D(20.0, 20.0),
    @math.Vec2D(30.0, 30.0),
    is_ui=true,
  )
  @inputs.mouse.pos = @math.Vec2D(25.0, 25.0)
  quadtree_clear_system(0.0)
  pickable_click_system(0.0)
  assert_true(is_hover(entity))
}

///|
test "is_hover resets to false after mouse leaves entity" {
  reset_pickable_test_state()
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  quadtree_clear_system(0.0)
  @inputs.mouse.pos = @math.Vec2D(15.0, 15.0)
  pickable_click_system(0.0)
  assert_true(is_hover(entity))

  @inputs.mouse.pos = @math.Vec2D(100.0, 100.0)
  pickable_click_system(0.0)
  assert_false(is_hover(entity))
}

///|
test "is_hover returns false when entity has no pickable or no shape" {
  reset_pickable_test_state()
  let no_pickable = @entity.Entity::new()
  @position.positions.set(no_pickable, @position.Position(@math.Vec2D(0.0, 0.0)))

  let no_shape = @entity.Entity::new()
  pickables.set(no_shape, Pickable::new())
  @position.positions.set(no_shape, @position.Position(@math.Vec2D(0.0, 0.0)))

  @inputs.mouse.pos = @math.Vec2D(1.0, 1.0)
  quadtree_clear_system(0.0)
  pickable_click_system(0.0)

  assert_false(is_hover(no_pickable))
  assert_false(is_hover(no_shape))
}

///|
test "double click triggers callback within time window" {
  reset_pickable_test_state()
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  quadtree_clear_system(0.0)
  let count = Ref::new(0)
  guard pickables.get(entity) is Some(pickable) else {
    fail("pickable not found")
  }
  pickable.on_double_click(fn(button) {
    if button == @inputs.MouseButton::Left {
      count.val += 1
    }
  })

  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.01)
  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.1)
  assert_eq(count.val, 1)
}

///|
test "double click does not trigger when interval is too long" {
  reset_pickable_test_state()
  let entity = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  quadtree_clear_system(0.0)
  let count = Ref::new(0)
  guard pickables.get(entity) is Some(pickable) else {
    fail("pickable not found")
  }
  pickable.on_double_click(fn(_button) { count.val += 1 })

  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.01)
  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.3)
  assert_eq(count.val, 0)
}

///|
test "double click requires same entity and same button" {
  reset_pickable_test_state()
  let _entity_a = create_pickable_rect_entity(
    @math.Vec2D(10.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  let entity_b = create_pickable_rect_entity(
    @math.Vec2D(100.0, 10.0),
    @math.Vec2D(20.0, 20.0),
  )
  quadtree_clear_system(0.0)
  let count_b = Ref::new(0)
  guard pickables.get(entity_b) is Some(pickable_b) else {
    fail("pickable not found")
  }
  pickable_b.on_double_click(fn(_button) { count_b.val += 1 })

  click_left_on_pos(@math.Vec2D(11.0, 11.0), 0.01)
  click_left_on_pos(@math.Vec2D(101.0, 11.0), 0.1)
  assert_eq(count_b.val, 0)

  @inputs.mouse.pos = @math.Vec2D(101.0, 11.0)
  @inputs.mouse.right_button = true
  @inputs.advanced_mouse_system(0.0)
  pickable_click_system(0.1)
  @inputs.mouse.right_button = false
  @inputs.advanced_mouse_system(0.0)
  pickable_click_system(0.0)
  assert_eq(count_b.val, 0)
}
