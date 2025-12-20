///|
test "variable duration timeline animation" {
  let entity = @entity.Entity::new()
  // Setup timeline:
  // Frame 0: 0.1s
  // Frame 1: 0.5s
  // Frame 2: 0.2s
  // Total: 0.8s
  let frames = [
    @sprite.AnimationFrame::{
      sprite_path: "f0",
      size: @math.Vec2D(10.0, 10.0),
      offset: @math.Vec2D(0.0, 0.0),
      duration: 0.1,
    },
    @sprite.AnimationFrame::{
      sprite_path: "f1",
      size: @math.Vec2D(10.0, 10.0),
      offset: @math.Vec2D(0.0, 0.0),
      duration: 0.5,
    },
    @sprite.AnimationFrame::{
      sprite_path: "f2",
      size: @math.Vec2D(10.0, 10.0),
      offset: @math.Vec2D(0.0, 0.0),
      duration: 0.2,
    },
  ]
  let animation = @sprite.Animation::new(frames, loop_=false)
  let sprite = @sprite.Sprite::from_animation(animation, 0)
  @sprite.sprites.set(entity, sprite)
  @position.positions.set(entity, @position.Position(@math.Vec2D(0, 0)))

  // 1. Initial State: Frame 0, Elapsed 0.0
  match @sprite.sprites.get(entity) {
    Some({ sprite_type: Animation(_, frame~, elapsed~), .. }) => {
      assert_eq(frame, 0)
      assert_eq(elapsed, 0.0)
    }
    _ => abort("Sprite missing")
  }

  // 2. Advance by 0.05s -> Total 0.05s (Inside Frame 0)
  @sprite.render_sprite_system(0.05)
  match @sprite.sprites.get(entity) {
    Some({ sprite_type: Animation(_, frame~, elapsed~), .. }) => {
      assert_eq(frame, 0)
      assert_true(elapsed > 0.04 && elapsed < 0.06) // Approx 0.05
    }
    _ => abort("Sprite missing")
  }

  // 3. Advance by 0.1s -> Total 0.15s (Should be Frame 1, Elapsed 0.05s inside Frame 1)
  // Explanation: 0.15s total - 0.1s (Frame 0) = 0.05s remainder into Frame 1
  @sprite.render_sprite_system(0.1)
  match @sprite.sprites.get(entity) {
    Some({ sprite_type: Animation(_, frame~, elapsed~), .. }) => {
      assert_eq(frame, 1) // Advanced to frame 1
      assert_true(elapsed > 0.04 && elapsed < 0.06) // 0.05s into frame 1
    }
    _ => abort("Sprite missing")
  }

  // 4. Advance by 0.4s -> Total 0.55s (elapsed 0.45s) -> Still Frame 1 (Duration 0.5s)
  @sprite.render_sprite_system(0.4)
  match @sprite.sprites.get(entity) {
    Some({ sprite_type: Animation(_, frame~, elapsed~), .. }) => {
      assert_eq(frame, 1)
      assert_true(elapsed > 0.44 && elapsed < 0.46) // 0.45s into frame 1
    }
    _ => abort("Sprite missing")
  }

  // 5. Advance by 0.1s -> Total 0.65s (elapsed 0.55s) -> Should be Frame 2
  // Explanation: 0.45 + 0.1 = 0.55. Frame 1 duration is 0.5. 
  // 0.55 - 0.5 = 0.05 remainder into Frame 2.
  @sprite.render_sprite_system(0.1)
  match @sprite.sprites.get(entity) {
    Some({ sprite_type: Animation(_, frame~, elapsed~), .. }) => {
      assert_eq(frame, 2)
      assert_true(elapsed > 0.04 && elapsed < 0.06)
    }
    _ => abort("Sprite missing")
  }

  // 6. Check finish status
  // We are at Frame 2 (last frame), elapsed 0.05. Duration is 0.2.
  // Should NOT be finished.
  assert_false(@sprite.is_animation_finished(entity))

  // 7. Advance by 0.2s -> End of animation
  @sprite.render_sprite_system(0.2)
  assert_true(@sprite.is_animation_finished(entity))
  entity.destroy()
}

///|
test "looping animation behavior" {
  let entity = @entity.Entity::new()
  let frames = [
    @sprite.AnimationFrame::{
      sprite_path: "0",
      size: @math.Vec2D(10.0, 10.0),
      offset: @math.Vec2D(0.0, 0.0),
      duration: 1.0,
    },
    @sprite.AnimationFrame::{
      sprite_path: "1",
      size: @math.Vec2D(10.0, 10.0),
      offset: @math.Vec2D(0.0, 0.0),
      duration: 1.0,
    },
  ]
  let animation = @sprite.Animation::new(frames, loop_=true)
  let sprite = @sprite.Sprite::from_animation(animation, 0)
  @sprite.sprites.set(entity, sprite)
  @position.positions.set(entity, @position.Position(@math.Vec2D(0, 0)))

  // 1. Initial State: Frame 0
  assert_false(@sprite.is_animation_finished(entity))

  // 2. Advance to Frame 1 (1.5s total time)
  @sprite.render_sprite_system(1.5)
  match @sprite.sprites.get(entity) {
    Some({ sprite_type: Animation(_, frame~, elapsed~), .. }) => {
      assert_eq(frame, 1)
      assert_true(elapsed > 0.49 && elapsed < 0.51) // Approx 0.5s into frame 1
    }
    _ => abort("Sprite missing")
  }
  assert_false(@sprite.is_animation_finished(entity))

  // 3. Advance to wrap around to Frame 0 (1.0s more -> 2.5s total)
  // Frame 1 duration is 1.0, we have 0.5 elapsed. Need 0.5 more to finish frame 1.
  // Advancing 1.0s means: 0.5s finish Frame 1 -> 0.5s into Frame 0 (next loop)
  @sprite.render_sprite_system(1.0)
  match @sprite.sprites.get(entity) {
    Some({ sprite_type: Animation(_, frame~, elapsed~), .. }) => {
      assert_eq(frame, 0)
      assert_true(elapsed > 0.49 && elapsed < 0.51) // Approx 0.5s into frame 0
    }
    _ => abort("Sprite missing")
  }

  // Looping animation should never finish based on logic
  assert_false(@sprite.is_animation_finished(entity))
  entity.destroy()
}
