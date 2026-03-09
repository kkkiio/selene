///|
test "sprite alpha multiplies picture and animation draw commands" {
  @render2d.begin_frame2d_system(0.0)

  let picture_entity = @entity.Entity::new()
  defer picture_entity.destroy()
  let picture = @sprite.Picture::new(
    @math.Vec2D(16.0, 16.0),
    "picture-alpha",
    color={ r: 255U, g: 255U, b: 255U, a: 0.5 },
  )
  @sprite.sprites.set(
    picture_entity,
    @sprite.Sprite::from_picture(picture, 0, alpha=0.5),
  )
  @position.positions.set(
    picture_entity,
    @position.Position(@math.Vec2D(0.0, 0.0)),
  )
  @sprite.render_sprite_system(0.0)
  match @render2d.get_frame2d().world_commands[0] {
    Image(command) => assert_eq(command.color.a, 0.25)
    _ => fail("Expected image draw command")
  }

  picture_entity.destroy()
  @render2d.begin_frame2d_system(0.0)

  let animation_entity = @entity.Entity::new()
  defer animation_entity.destroy()
  let animation = @sprite.Animation::new([
    {
      image: @asset.load_image("animation-alpha"),
      size: @math.Vec2D(8.0, 8.0),
      offset: @math.Vec2D(0.0, 0.0),
      duration: 1.0,
      pivot: @math.Vec2D(0.0, 0.0),
    },
  ])
  @sprite.sprites.set(
    animation_entity,
    @sprite.Sprite::from_animation(animation, 0, alpha=0.4),
  )
  @position.positions.set(
    animation_entity,
    @position.Position(@math.Vec2D(0.0, 0.0)),
  )
  @sprite.render_sprite_system(0.0)
  match @render2d.get_frame2d().world_commands[0] {
    Image(command) => assert_eq(command.color.a, 0.4)
    _ => fail("Expected image draw command")
  }
}

///|
test "sprite alpha multiplies text and shape colors" {
  @render2d.begin_frame2d_system(0.0)

  let text_entity = @entity.Entity::new()
  defer text_entity.destroy()
  @sprite.sprites.set(
    text_entity,
    @sprite.Sprite::from_text(
      @sprite.Text::new("alpha", color="rgba(255, 255, 255, 0.8)"),
      0,
      alpha=0.5,
    ),
  )
  @position.positions.set(text_entity, @position.Position(@math.Vec2D(0.0, 0.0)))
  @sprite.render_sprite_system(0.0)
  match @render2d.get_frame2d().world_commands[0] {
    Text(command) => assert_eq(command.style.color.a, 0.4)
    _ => fail("Expected text draw command")
  }

  text_entity.destroy()
  @render2d.begin_frame2d_system(0.0)

  let rect_entity = @entity.Entity::new()
  defer rect_entity.destroy()
  @sprite.sprites.set(
    rect_entity,
    @sprite.Sprite::from_color_rect(
      @sprite.ColorRect::new(
        @math.Vec2D(12.0, 12.0),
        "rgba(255, 0, 0, 0.8)",
        stroke_color="rgba(0, 0, 0, 0.6)",
      ),
      0,
      alpha=0.5,
    ),
  )
  @position.positions.set(rect_entity, @position.Position(@math.Vec2D(0.0, 0.0)))
  @sprite.render_sprite_system(0.0)
  match @render2d.get_frame2d().world_commands[0] {
    Rect(command) => {
      assert_eq(command.fill_color.a, 0.4)
      match command.stroke_color {
        Some(stroke_color) => assert_eq(stroke_color.a, 0.3)
        None => fail("Expected rect stroke color")
      }
    }
    _ => fail("Expected rect draw command")
  }

  rect_entity.destroy()
  @render2d.begin_frame2d_system(0.0)

  let circle_entity = @entity.Entity::new()
  defer circle_entity.destroy()
  @sprite.sprites.set(
    circle_entity,
    @sprite.Sprite::from_color_circle(
      @sprite.ColorCircle::new(
        6.0,
        "rgba(0, 255, 0, 0.7)",
        stroke_color="rgba(255, 255, 255, 0.5)",
      ),
      0,
      alpha=0.5,
    ),
  )
  @position.positions.set(circle_entity, @position.Position(@math.Vec2D(0.0, 0.0)))
  @sprite.render_sprite_system(0.0)
  match @render2d.get_frame2d().world_commands[0] {
    Circle(command) => {
      assert_eq(command.fill_color.a, 0.35)
      match command.stroke_color {
        Some(stroke_color) => assert_eq(stroke_color.a, 0.25)
        None => fail("Expected circle stroke color")
      }
    }
    _ => fail("Expected circle draw command")
  }
}
