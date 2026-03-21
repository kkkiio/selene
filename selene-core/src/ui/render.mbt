///|
let extracted_ui_entities : Array[@entity.Entity] = []

///|
fn push_ui_rect_fill(rect : @math.Rect, color : @render.Color) -> Unit {
  if rect.size[X] <= 0.0 || rect.size[Y] <= 0.0 || color.a <= 0.0 {
    return
  }
  @render2d.push_ui_rect({ rect, fill_color: color, stroke_color: None })
}

///|
fn push_ui_circle_fill(
  center : @math.Vec2D,
  radius : Double,
  color : @render.Color,
) -> Unit {
  if radius <= 0.0 || color.a <= 0.0 {
    return
  }
  @render2d.push_ui_circle({
    center,
    radius,
    fill_color: color,
    stroke_color: None,
  })
}

///|
fn scale_alpha(color : @render.Color, factor : Double) -> @render.Color {
  let alpha = if factor <= 0.0 {
    0.0
  } else if factor >= 1.0 {
    color.a
  } else {
    color.a * factor
  }
  @render.Color::{ ..color, a: alpha }
}

///|
priv struct ResolvedBorderRadius {
  top_left : Double
  top_right : Double
  bottom_right : Double
  bottom_left : Double
}

///|
fn has_rounded_corners(radius : ResolvedBorderRadius) -> Bool {
  radius.top_left > 0.0 ||
  radius.top_right > 0.0 ||
  radius.bottom_right > 0.0 ||
  radius.bottom_left > 0.0
}

///|
fn resolve_corner_radius(value : Val, size : @math.Vec2D) -> Double {
  let basis = @cmp.maximum(0.0, @cmp.minimum(size[X], size[Y]))
  resolve_val(value, basis)
}

///|
fn resolved_border_radius(
  radius : BorderRadius,
  size : @math.Vec2D,
) -> ResolvedBorderRadius {
  let limit = @cmp.maximum(0.0, @cmp.minimum(size[X], size[Y]) / 2.0)
  {
    top_left: @cmp.minimum(
      limit,
      @cmp.maximum(0.0, resolve_corner_radius(radius.top_left, size)),
    ),
    top_right: @cmp.minimum(
      limit,
      @cmp.maximum(0.0, resolve_corner_radius(radius.top_right, size)),
    ),
    bottom_right: @cmp.minimum(
      limit,
      @cmp.maximum(0.0, resolve_corner_radius(radius.bottom_right, size)),
    ),
    bottom_left: @cmp.minimum(
      limit,
      @cmp.maximum(0.0, resolve_corner_radius(radius.bottom_left, size)),
    ),
  }
}

///|
fn inset_rect(rect : @math.Rect, inset : UiInsets) -> @math.Rect {
  {
    position: @math.Vec2D(
      rect.position[X] + inset.left,
      rect.position[Y] + inset.top,
    ),
    size: @math.Vec2D(
      @cmp.maximum(0.0, rect.size[X] - inset.left - inset.right),
      @cmp.maximum(0.0, rect.size[Y] - inset.top - inset.bottom),
    ),
  }
}

///|
fn inset_border_radius(
  radius : ResolvedBorderRadius,
  inset : UiInsets,
) -> ResolvedBorderRadius {
  {
    top_left: @cmp.maximum(
      0.0,
      radius.top_left - @cmp.maximum(inset.top, inset.left),
    ),
    top_right: @cmp.maximum(
      0.0,
      radius.top_right - @cmp.maximum(inset.top, inset.right),
    ),
    bottom_right: @cmp.maximum(
      0.0,
      radius.bottom_right - @cmp.maximum(inset.bottom, inset.right),
    ),
    bottom_left: @cmp.maximum(
      0.0,
      radius.bottom_left - @cmp.maximum(inset.bottom, inset.left),
    ),
  }
}

///|
fn inflate_rect(rect : @math.Rect, amount : Double) -> @math.Rect {
  {
    position: @math.Vec2D(rect.position[X] - amount, rect.position[Y] - amount),
    size: @math.Vec2D(
      @cmp.maximum(0.0, rect.size[X] + amount * 2.0),
      @cmp.maximum(0.0, rect.size[Y] + amount * 2.0),
    ),
  }
}

///|
fn offset_rect(rect : @math.Rect, offset : @math.Vec2D) -> @math.Rect {
  { position: rect.position + offset, size: rect.size }
}

///|
fn inflate_border_radius(
  radius : ResolvedBorderRadius,
  amount : Double,
) -> ResolvedBorderRadius {
  {
    top_left: @cmp.maximum(0.0, radius.top_left + amount),
    top_right: @cmp.maximum(0.0, radius.top_right + amount),
    bottom_right: @cmp.maximum(0.0, radius.bottom_right + amount),
    bottom_left: @cmp.maximum(0.0, radius.bottom_left + amount),
  }
}

///|
fn push_quarter_circle(
  clip_rect : @math.Rect,
  center : @math.Vec2D,
  radius : Double,
  color : @render.Color,
) -> Unit {
  if clip_rect.size[X] <= 0.0 || clip_rect.size[Y] <= 0.0 || radius <= 0.0 {
    return
  }
  @render2d.push_ui_clip(clip_rect)
  push_ui_circle_fill(center, radius, color)
  @render2d.pop_ui_clip()
}

///|
fn push_rounded_rect(
  rect : @math.Rect,
  radius : ResolvedBorderRadius,
  color : @render.Color,
) -> Unit {
  if rect.size[X] <= 0.0 || rect.size[Y] <= 0.0 || color.a <= 0.0 {
    return
  }
  if !has_rounded_corners(radius) {
    push_ui_rect_fill(rect, color)
    return
  }

  let tl = radius.top_left
  let tr = radius.top_right
  let br = radius.bottom_right
  let bl = radius.bottom_left
  let x = rect.position[X]
  let y = rect.position[Y]
  let w = rect.size[X]
  let h = rect.size[Y]
  let left_band = @cmp.maximum(tl, bl)
  let right_band = @cmp.maximum(tr, br)
  let top_band = @cmp.maximum(tl, tr)
  let bottom_band = @cmp.maximum(bl, br)

  push_ui_rect_fill(
    {
      position: @math.Vec2D(x + left_band, y + top_band),
      size: @math.Vec2D(
        @cmp.maximum(0.0, w - left_band - right_band),
        @cmp.maximum(0.0, h - top_band - bottom_band),
      ),
    },
    color,
  )
  push_ui_rect_fill(
    {
      position: @math.Vec2D(x + tl, y),
      size: @math.Vec2D(@cmp.maximum(0.0, w - tl - tr), top_band),
    },
    color,
  )
  push_ui_rect_fill(
    {
      position: @math.Vec2D(x + bl, y + h - bottom_band),
      size: @math.Vec2D(@cmp.maximum(0.0, w - bl - br), bottom_band),
    },
    color,
  )
  push_ui_rect_fill(
    {
      position: @math.Vec2D(x, y + tl),
      size: @math.Vec2D(left_band, @cmp.maximum(0.0, h - tl - bl)),
    },
    color,
  )
  push_ui_rect_fill(
    {
      position: @math.Vec2D(x + w - right_band, y + tr),
      size: @math.Vec2D(right_band, @cmp.maximum(0.0, h - tr - br)),
    },
    color,
  )
  push_quarter_circle(
    { position: @math.Vec2D(x, y), size: @math.Vec2D(tl, tl) },
    @math.Vec2D(x + tl, y + tl),
    tl,
    color,
  )
  push_quarter_circle(
    { position: @math.Vec2D(x + w - tr, y), size: @math.Vec2D(tr, tr) },
    @math.Vec2D(x + w - tr, y + tr),
    tr,
    color,
  )
  push_quarter_circle(
    { position: @math.Vec2D(x + w - br, y + h - br), size: @math.Vec2D(br, br) },
    @math.Vec2D(x + w - br, y + h - br),
    br,
    color,
  )
  push_quarter_circle(
    { position: @math.Vec2D(x, y + h - bl), size: @math.Vec2D(bl, bl) },
    @math.Vec2D(x + bl, y + h - bl),
    bl,
    color,
  )
}

///|
fn shadow_samples(blur : Double) -> Int {
  if blur <= 0.0 {
    1
  } else {
    let steps = (blur / 8.0).ceil().to_int() + 1
    @cmp.minimum(6, @cmp.maximum(2, steps))
  }
}

///|
fn push_box_shadow(entity : @entity.Entity) -> Unit {
  guard box_shadows().get(entity) is Some(shadow) else { return }
  guard global_ui_nodes().get(entity) is Some(global) else { return }
  let base_radius = resolved_border_radius(
    border_radii().get(entity).unwrap_or(BorderRadius::all(Val::px(0.0))),
    global.screen_rect.size,
  )
  let spread_basis = @cmp.minimum(
    global.screen_rect.size[X],
    global.screen_rect.size[Y],
  )
  for layer in shadow.layers {
    let offset = @math.Vec2D(
      resolve_val(layer.x_offset, global.screen_rect.size[X]),
      resolve_val(layer.y_offset, global.screen_rect.size[Y]),
    )
    let spread = resolve_val(layer.spread_radius, spread_basis)
    let blur = resolve_val(layer.blur_radius, spread_basis)
    let samples = shadow_samples(blur)
    let mut index = samples - 1
    while index >= 0 {
      let t = if samples <= 1 {
        0.0
      } else {
        index.to_double() / (samples - 1).to_double()
      }
      let blur_amount = blur * t
      let alpha_scale = if samples <= 1 {
        1.0
      } else {
        (1.0 - t * 0.85) / samples.to_double()
      }
      push_rounded_rect(
        offset_rect(
          inflate_rect(global.screen_rect, spread + blur_amount),
          offset,
        ),
        inflate_border_radius(base_radius, spread + blur_amount),
        scale_alpha(layer.color, alpha_scale),
      )
      index -= 1
    }
  }
}

///|
fn should_render_ui(entity : @entity.Entity) -> Bool {
  entity.is_alive() &&
  @visibility.is_visible(entity) &&
  global_ui_nodes().contains(entity) &&
  nodes()
  .get(entity)
  .map(fn(node) { node.active && node.display != None })
  .unwrap_or(false)
}

///|
fn scaled_text_font(font : TextFont) -> TextFont {
  match get_ui_scale_mode() {
    Screen => font
    Viewport => { ..font, size: @system.scale_value(font.size) }
  }
}

///|
fn ui_material_context_for(entity : @entity.Entity) -> UiMaterialContext? {
  global_ui_nodes()
  .get(entity)
  .map(fn(transform) {
    UiMaterialContext::new(
      entity,
      transform.screen_rect,
      content_rect=transform.screen_content_rect,
      border_radius=border_radii()
        .get(entity)
        .unwrap_or(BorderRadius::all(Val::px(0.0))),
    )
  })
}

///|
pub fn draw_ui_material_solid(
  context : UiMaterialContext,
  color : @render.Color,
) -> Unit {
  push_rounded_rect(
    context.rect,
    resolved_border_radius(context.border_radius, context.rect.size),
    color,
  )
}

///|
pub fn draw_ui_material_gradient(
  context : UiMaterialContext,
  gradient : UiGradient,
) -> Unit {
  @render2d.push_ui_gradient_rect({
    rect: context.rect,
    color_start: gradient.color_start,
    color_end: gradient.color_end,
  })
}

///|
pub fn draw_ui_material_image(
  context : UiMaterialContext,
  image : UiImage,
) -> Unit {
  let source = ui_image_regions()
  .get(context.entity)
  .map(fn(it) { it.region })
  @render2d.push_ui_image({
    image: image.image,
    destination: fitted_image_rect(context.rect, image),
    source,
    transform: @math.Transform::new(),
    repeat: NoRepeat,
    color: image.tint,
  })
}

///|
fn push_background(entity : @entity.Entity) -> Unit {
  guard !material_nodes().contains(entity) else { return }
  guard background_colors().get(entity) is Some(background) else { return }
  guard ui_material_context_for(entity) is Some(context) else { return }
  draw_ui_material_solid(context, background.color)
}

///|
fn push_material_node(entity : @entity.Entity) -> Bool {
  guard material_nodes().get(entity) is Some(material_node) else {
    return false
  }
  guard ui_material_asset(material_node.material) is Some(material) else {
    return false
  }
  guard ui_material_context_for(entity) is Some(context) else { return false }
  (material.draw)(context)
  true
}

///|
fn push_border(entity : @entity.Entity) -> Unit {
  guard border_colors().get(entity) is Some(border_color) else { return }
  guard global_ui_nodes().get(entity) is Some(global) else { return }
  guard computed_ui_nodes().get(entity) is Some(computed) else { return }
  let rect = global.screen_rect
  let border = computed.border
  let radius = resolved_border_radius(
    border_radii().get(entity).unwrap_or(BorderRadius::all(Val::px(0.0))),
    rect.size,
  )
  if has_rounded_corners(radius) {
    match background_colors().get(entity) {
      Some(background) => {
        push_rounded_rect(rect, radius, border_color.color)
        push_rounded_rect(
          inset_rect(rect, border),
          inset_border_radius(radius, border),
          background.color,
        )
        return
      }
      None =>
        @platform_render.capability_warning(
          "ui_rounded_border_without_fill", "rounded UI borders without a background color still fall back to square edge segments",
        )
    }
  }
  if border.top > 0.0 {
    push_ui_rect_fill(
      { position: rect.position, size: @math.Vec2D(rect.size[X], border.top) },
      border_color.color,
    )
  }
  if border.bottom > 0.0 {
    push_ui_rect_fill(
      {
        position: @math.Vec2D(
          rect.position[X],
          rect.position[Y] + rect.size[Y] - border.bottom,
        ),
        size: @math.Vec2D(rect.size[X], border.bottom),
      },
      border_color.color,
    )
  }
  if border.left > 0.0 {
    push_ui_rect_fill(
      {
        position: @math.Vec2D(rect.position[X], rect.position[Y] + border.top),
        size: @math.Vec2D(
          border.left,
          @cmp.maximum(0.0, rect.size[Y] - border.top - border.bottom),
        ),
      },
      border_color.color,
    )
  }
  if border.right > 0.0 {
    push_ui_rect_fill(
      {
        position: @math.Vec2D(
          rect.position[X] + rect.size[X] - border.right,
          rect.position[Y] + border.top,
        ),
        size: @math.Vec2D(
          border.right,
          @cmp.maximum(0.0, rect.size[Y] - border.top - border.bottom),
        ),
      },
      border_color.color,
    )
  }
}

///|
fn push_outline(entity : @entity.Entity) -> Unit {
  guard outlines().get(entity) is Some(outline) else { return }
  guard global_ui_nodes().get(entity) is Some(transform) else { return }
  let width = resolve_val(outline.width, transform.screen_rect.size[X])
  let offset = resolve_val(outline.offset, transform.screen_rect.size[X])
  if width <= 0.0 || outline.color.a <= 0.0 {
    return
  }
  let inner = inflate_rect(transform.screen_rect, offset)
  let outer = inflate_rect(transform.screen_rect, offset + width)
  let radius = resolved_border_radius(
    border_radii().get(entity).unwrap_or(BorderRadius::all(Val::px(0.0))),
    transform.screen_rect.size,
  )
  if has_rounded_corners(radius) {
    @platform_render.capability_warning(
      "ui_rounded_outline", "rounded UI outlines still render as square outline bands in the current 2D path",
    )
  }
  push_ui_rect_fill(
    {
      position: outer.position,
      size: @math.Vec2D(
        outer.size[X],
        @cmp.maximum(0.0, inner.position[Y] - outer.position[Y]),
      ),
    },
    outline.color,
  )
  push_ui_rect_fill(
    {
      position: @math.Vec2D(
        outer.position[X],
        inner.position[Y] + inner.size[Y],
      ),
      size: @math.Vec2D(
        outer.size[X],
        @cmp.maximum(
          0.0,
          outer.position[Y] + outer.size[Y] - inner.position[Y] - inner.size[Y],
        ),
      ),
    },
    outline.color,
  )
  push_ui_rect_fill(
    {
      position: @math.Vec2D(outer.position[X], inner.position[Y]),
      size: @math.Vec2D(
        @cmp.maximum(0.0, inner.position[X] - outer.position[X]),
        inner.size[Y],
      ),
    },
    outline.color,
  )
  push_ui_rect_fill(
    {
      position: @math.Vec2D(
        inner.position[X] + inner.size[X],
        inner.position[Y],
      ),
      size: @math.Vec2D(
        @cmp.maximum(
          0.0,
          outer.position[X] + outer.size[X] - inner.position[X] - inner.size[X],
        ),
        inner.size[Y],
      ),
    },
    outline.color,
  )
}

///|
fn fitted_image_rect(container : @math.Rect, image : UiImage) -> @math.Rect {
  match image.fit {
    Stretch => container
    None => { position: container.position, size: image.size }
    Contain => {
      let scale = @cmp.minimum(
        if image.size[X] <= 0.0 {
          1.0
        } else {
          container.size[X] / image.size[X]
        },
        if image.size[Y] <= 0.0 {
          1.0
        } else {
          container.size[Y] / image.size[Y]
        },
      )
      let size = @math.Vec2D(image.size[X] * scale, image.size[Y] * scale)
      {
        position: @math.Vec2D(
          container.position[X] + (container.size[X] - size[X]) / 2.0,
          container.position[Y] + (container.size[Y] - size[Y]) / 2.0,
        ),
        size,
      }
    }
    Cover => {
      let scale = @cmp.maximum(
        if image.size[X] <= 0.0 {
          1.0
        } else {
          container.size[X] / image.size[X]
        },
        if image.size[Y] <= 0.0 {
          1.0
        } else {
          container.size[Y] / image.size[Y]
        },
      )
      let size = @math.Vec2D(image.size[X] * scale, image.size[Y] * scale)
      {
        position: @math.Vec2D(
          container.position[X] + (container.size[X] - size[X]) / 2.0,
          container.position[Y] + (container.size[Y] - size[Y]) / 2.0,
        ),
        size,
      }
    }
  }
}

///|
fn push_image(entity : @entity.Entity) -> Unit {
  guard !material_nodes().contains(entity) else { return }
  guard ui_images().get(entity) is Some(image) else { return }
  guard global_ui_nodes().get(entity) is Some(transform) else { return }
  let source = ui_image_regions().get(entity).map(fn(it) { it.region })
  @render2d.push_ui_image({
    image: image.image,
    destination: fitted_image_rect(transform.screen_content_rect, image),
    source,
    transform: @math.Transform::new(),
    repeat: NoRepeat,
    color: image.tint,
  })
}

///|
fn measure_text_fragment(
  font : TextFont,
  color : TextColor,
  text : String,
) -> @math.Vec2D {
  @platform_render.measure_text(
    {
      font: font.font_handle,
      family: font.family,
      size: font.size,
      bold: font.bold,
      color: color.color,
      align: Left,
      baseline: Top,
    },
    text,
  )
}

///|
fn truncate_word(token : ParagraphToken, max_width : Double) -> ParagraphToken {
  if max_width <= 0.0 {
    return { ..token, text: "", width: 0.0 }
  }
  if token.width <= max_width {
    return token
  }
  let ellipsis = "..."
  let mut current = token.text
  let mut width = token.width
  while current.length() > 0 {
    width = measure_text_fragment(token.font, token.color, current + ellipsis)[X]
    if width > max_width {
      current = current.unsafe_substring(start=0, end=current.length() - 1)
    } else {
      break
    }
  }
  { ..token, text: current + ellipsis, width }
}

///|
/// collect all text spans from entity and its children
fn collect_paragraph_spans(entity : @entity.Entity) -> Array[ParagraphSpan] {
  guard texts().get(entity) is Some(text) else { return [] }
  let root_font = text_font(entity) |> scaled_text_font
  let root_color = text_color(entity)
  let root_underline = text_underline(entity, false)
  let root_underline_color = text_underline_color(entity, None)
  let spans = Array::new(capacity=1 + entity.get_children().length())
  spans.push(
    ParagraphSpan::new(
      text.content,
      font=root_font,
      color=root_color,
      underline=root_underline,
      underline_color=root_underline_color,
    ),
  )
  for child in entity.get_children() {
    guard child.is_alive() else { continue }
    guard text_spans().get(child) is Some(span) else { continue }
    spans.push(
      ParagraphSpan::new(
        span.content,
        font=text_fonts().get(child).map_or(root_font, scaled_text_font),
        color=text_colors().get(child).unwrap_or(root_color),
        underline=text_underline(child, root_underline),
        underline_color=text_underline_color(child, root_underline_color),
      ),
    )
  }
  spans
}

///|
fn layout_paragraph(
  spans : Array[ParagraphSpan],
  layout : TextLayout,
  max_width? : Double = 0.0,
) -> ParagraphLayout {
  let tokens = paragraph_tokens(spans)
  let lines : Array[ParagraphLine] = []
  let mut fragments : Array[ParagraphFragment] = []
  let mut cursor_x = 0.0
  let mut truncated = false
  fn new_line() {
    lines.push(make_line(fragments))
    fragments = []
    cursor_x = 0.0
    truncated = false
  }
  fn push_token(token : ParagraphToken) {
    if token.text.is_empty() {
      return
    }
    fragments.push({
      text: token.text,
      font: token.font,
      color: token.color,
      underline: token.underline,
      underline_color: token.underline_color,
      x: cursor_x,
      width: token.width,
      height: token.height,
    })
    cursor_x += token.width
  }
  let max_width = @cmp.maximum(0.0, max_width)
  for token in tokens {
    match token {
      { kind: ParagraphTokenKind::ForcedBreak, .. } => new_line()
      // do we need to trim leading whitespace? 
      // if fragments.is_empty() {
      //   continue
      // }
      { kind: ParagraphTokenKind::Whitespace, .. } as token => {
        let overflow = max_width > 0.0 && cursor_x + token.width > max_width
        if layout.wrap is WordWrap && overflow {
          new_line()
        } else {
          push_token(token)
        }
      }
      { kind: ParagraphTokenKind::Word, .. } as token => {
        let overflow = max_width > 0.0 && cursor_x + token.width > max_width
        if overflow {
          match layout {
            { wrap: NoWrap, overflow: Clip, .. } => push_token(token)
            { wrap: NoWrap, overflow: Ellipsis, .. } =>
              if not(truncated) {
                truncated = true
                push_token(truncate_word(token, max_width - cursor_x))
              }
            { wrap: WordWrap, .. } => {
              if not(fragments.is_empty()) {
                new_line()
              }
              push_token(token)
            }
          }
        } else {
          push_token(token)
        }
      }
    }
  }
  if !fragments.is_empty() || lines.is_empty() {
    ignore(new_line())
  }
  let scaled_lines = lines.map(fn(line) {
    let raw_height = if line.height <= 0.0 { 1.0 } else { line.height }
    { ..line, height: raw_height * @cmp.maximum(1.0, layout.line_height) }
  })
  let width = scaled_lines.fold(init=0.0, fn(acc, line) {
    @cmp.maximum(acc, line.width)
  })
  let height = scaled_lines.fold(init=0.0, fn(acc, line) { acc + line.height })
  { lines: scaled_lines, size: @math.Vec2D(width, height) }
}

///|
fn prepare_paragraph_layout(
  entity : @entity.Entity,
  content_rect : @math.Rect,
) -> ParagraphLayout {
  let spans = collect_paragraph_spans(entity)
  let layout = text_layout(entity)
  layout_paragraph(spans, layout, max_width=content_rect.size[X])
}

///|
fn push_fragment_underline(
  fragment : ParagraphFragment,
  x : Double,
  y : Double,
  line_height : Double,
) -> Unit {
  guard fragment.underline && fragment.width > 0.0 else { return }
  let thickness = @cmp.maximum(1.0, fragment.font.size * 0.08)
  let underline_y = y +
    @cmp.maximum(line_height - thickness, fragment.height * 0.85)
  push_ui_rect_fill(
    {
      position: @math.Vec2D(x, underline_y),
      size: @math.Vec2D(fragment.width, thickness),
    },
    fragment.underline_color.unwrap_or(fragment.color.color),
  )
}

///|
fn push_text(entity : @entity.Entity) -> Unit {
  guard texts().get(entity) is Some(_) else { return }
  guard global_ui_nodes().get(entity) is Some(transform) else { return }
  let layout = text_layout(entity)
  let paragraph = prepare_paragraph_layout(
    entity,
    transform.screen_content_rect,
  )
  if paragraph.lines.is_empty() {
    return
  }
  let block_height = paragraph.size[Y]
  let start_y = match layout.baseline {
    Top => transform.screen_content_rect.position[Y]
    Center =>
      transform.screen_content_rect.position[Y] +
      (transform.screen_content_rect.size[Y] - block_height) / 2.0
    Bottom =>
      transform.screen_content_rect.position[Y] +
      transform.screen_content_rect.size[Y] -
      block_height
  }
  let mut line_y = start_y
  for line in paragraph.lines {
    let line_x = match layout.align {
      Left => transform.screen_content_rect.position[X]
      Center =>
        transform.screen_content_rect.position[X] +
        (transform.screen_content_rect.size[X] - line.width) / 2.0
      Right =>
        transform.screen_content_rect.position[X] +
        transform.screen_content_rect.size[X] -
        line.width
    }
    for fragment in line.fragments {
      // `x`/`y` are already fully resolved in UI layout space.
      // Force renderer-local alignment to top-left to avoid applying alignment twice.
      let style_for_draw : @render2d_types.TextStyle2D = {
        font: fragment.font.font_handle,
        family: fragment.font.family,
        size: fragment.font.size,
        bold: fragment.font.bold,
        color: fragment.color.color,
        align: @math.Left,
        baseline: @math.Top,
      }
      let fragment_x = line_x + fragment.x
      @render2d.push_ui_text({
        text: fragment.text,
        position: @math.Vec2D(fragment_x, line_y),
        style: style_for_draw,
      })
      push_fragment_underline(fragment, fragment_x, line_y, line.height)
    }
    line_y += line.height
  }
}

///|
fn inherited_clip_for_entity(entity : @entity.Entity) -> @math.Rect? {
  if override_clips().contains(entity) {
    return None
  }
  let mut current = entity.get_parent()
  let mut clip : @math.Rect? = None
  while current is Some(ancestor) {
    if calculated_clips().get(ancestor) is Some(calculated) {
      clip = match clip {
        Some(existing) => rect_intersection(existing, calculated.clip)
        None => Some(calculated.clip)
      }
    }
    if override_clips().contains(ancestor) {
      break
    }
    current = ancestor.get_parent()
  }
  clip
}

///|
fn render_entity(entity : @entity.Entity) -> Unit {
  guard should_render_ui(entity) else { return }
  guard nodes().get(entity) is Some(node) else { return }
  let effective_inherited_clip = inherited_clip_for_entity(entity)

  let mut pushed_inherited_clip = false
  match effective_inherited_clip {
    Some(clip_rect) => {
      @render2d.push_ui_clip(clip_rect)
      pushed_inherited_clip = true
    }
    None => ()
  }

  push_box_shadow(entity)
  ignore(push_material_node(entity))
  push_background(entity)
  push_border(entity)
  push_outline(entity)

  if pushed_inherited_clip {
    @render2d.pop_ui_clip()
  }

  let needs_clip = node.overflow_x != Visible || node.overflow_y != Visible
  let content_clip = if needs_clip {
    calculated_clips().get(entity).map(fn(value) { value.clip })
  } else {
    effective_inherited_clip
  }
  let mut content_visible = true
  if needs_clip && content_clip is None {
    content_visible = false
  }

  if content_visible {
    let mut pushed_content_clip = false
    match content_clip {
      Some(clip_rect) => {
        @render2d.push_ui_clip(clip_rect)
        pushed_content_clip = true
      }
      None => ()
    }
    push_image(entity)
    push_text(entity)
    if pushed_content_clip {
      @render2d.pop_ui_clip()
    }
  }
}

///|
pub fn ui_extract_system(_delta : Double) -> Unit {
  extracted_ui_entities.clear()
  for entity, _ in nodes() {
    if should_render_ui(entity) {
      extracted_ui_entities.push(entity)
    }
  }
  extracted_ui_entities.sort_by(compare_ui_stacking)
}

///|
pub fn ui_prepare_system(_delta : Double) -> Unit {
  for entity in extracted_ui_entities {
    render_entity(entity)
  }
}
