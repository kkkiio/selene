///|
pub(all) struct ParagraphSpan {
  text : String
  font : TextFont
  color : TextColor
  underline : Bool
  underline_color : @render.Color?

  fn new(
    text : String,
    font? : TextFont,
    color? : TextColor,
    underline? : Bool,
    underline_color? : @render.Color?,
  ) -> ParagraphSpan
}

///|
pub fn ParagraphSpan::new(
  text : String,
  font? : TextFont = TextFont::new(),
  color? : TextColor = TextColor::from_css("white"),
  underline? : Bool = false,
  underline_color? : @render.Color? = None,
) -> ParagraphSpan {
  { text, font, color, underline, underline_color }
}

///|
pub(all) struct ParagraphFragment {
  text : String
  font : TextFont
  color : TextColor
  underline : Bool
  underline_color : @render.Color?
  x : Double
  width : Double
  height : Double
}

///|
pub(all) struct ParagraphLine {
  fragments : Array[ParagraphFragment]
  width : Double
  height : Double
}

///|
pub(all) struct ParagraphLayout {
  lines : Array[ParagraphLine]
  size : @math.Vec2D
}

///|
priv enum ParagraphTokenKind {
  Word
  Whitespace
  ForcedBreak
} derive(Eq)

///|
priv struct ParagraphToken {
  text : String
  font : TextFont
  color : TextColor
  underline : Bool
  underline_color : @render.Color?
  width : Double
  height : Double
  kind : ParagraphTokenKind
}

///|
fn make_token(
  text : String,
  font : TextFont,
  color : TextColor,
  underline : Bool,
  underline_color : @render.Color?,
  kind : ParagraphTokenKind,
) -> ParagraphToken {
  let measured = measure_text_fragment(font, color, text)
  {
    text,
    font,
    color,
    underline,
    underline_color,
    width: measured[X],
    height: measured[Y],
    kind,
  }
}

///|
fn tokenize_paragraph_span(span : ParagraphSpan) -> Iter[ParagraphToken] {
  let text = span.text
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let builder = StringBuilder::new()
  let mut current_kind = ParagraphTokenKind::Word
  fn flush() -> ParagraphToken? {
    if builder.is_empty() {
      return None
    }
    let current = builder.to_string()
    builder.reset()
    Some(
      make_token(
        current,
        span.font,
        span.color,
        span.underline,
        span.underline_color,
        current_kind,
      ),
    )
  }
  Iter::concat(
    text
    .iter()
    .flat_map(fn(ch) {
      if ch == '\n' {
        return flush()
          .iter()
          .concat(
            Iter::singleton(
              make_token(
                "\n",
                span.font,
                span.color,
                span.underline,
                span.underline_color,
                ForcedBreak,
              ),
            ),
          )
      }
      let next_kind = if ch == ' ' || ch == '\t' {
        ParagraphTokenKind::Whitespace
      } else {
        ParagraphTokenKind::Word
      }
      let iter = if not(builder.is_empty()) && next_kind != current_kind {
        flush()
      } else {
        None
      }
      current_kind = next_kind
      builder.write_char(ch)
      iter.iter()
    }),
    Iter::new(flush),
  )
}

///|
fn paragraph_tokens(spans : Array[ParagraphSpan]) -> Iter[ParagraphToken] {
  spans.iter().flat_map(span => tokenize_paragraph_span(span))
}

///|
fn make_line(fragments : Array[ParagraphFragment]) -> ParagraphLine {
  let width = fragments.fold(init=0.0, fn(acc, fragment) {
    @cmp.maximum(acc, fragment.x + fragment.width)
  })
  let height = fragments.fold(init=0.0, fn(acc, fragment) {
    @cmp.maximum(acc, fragment.height)
  })
  { fragments, width, height }
}

///|
fn text_underline(entity : @entity.Entity, inherited : Bool) -> Bool {
  underlines().get(entity).map(fn(value) { value.enabled }).unwrap_or(inherited)
}

///|
fn text_underline_color(
  entity : @entity.Entity,
  inherited : @render.Color?,
) -> @render.Color? {
  match underline_colors().get(entity) {
    Some(value) => Some(value.color)
    None => inherited
  }
}
