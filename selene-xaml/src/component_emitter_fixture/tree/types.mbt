///|
pub(all) enum NodeKind {
  VIEW
  FLEX
  TEXT
  IMAGE
  BUTTON
  SCROLL_VIEW
} derive(Eq, Debug)

///|
pub(all) enum TextAlign {
  LEFT
  CENTER
  RIGHT
} derive(Eq, Debug)

///|
pub(all) enum ImageFit {
  FILL
  CONTAIN
  COVER
} derive(Eq, Debug)

///|
pub(all) enum FlexDirection {
  ROW
  ROW_REVERSE
  COLUMN
  COLUMN_REVERSE
} derive(Eq, Debug)

///|
pub(all) enum LayoutValue {
  Auto
  Px(Float)
  Percent(Float)
} derive(Eq, Debug)

///|
pub(all) struct NodeStyle {
  absolute : Bool
  left : Float
  top : Float
  width : LayoutValue
  height : LayoutValue
  margin_left : Float
  margin_top : Float
  margin_right : Float
  margin_bottom : Float
  padding_left : Float
  padding_top : Float
  padding_right : Float
  padding_bottom : Float
  background : String
  border_color : String
  border : Float
  radius : Float
  color : String
  font_family : String
  font_size : Float
  bold : Bool
  align : TextAlign
  wrap : Bool
  z_index : Int
  fit : ImageFit
  direction : FlexDirection
  flex_basis : LayoutValue
  flex_grow : Float
  flex_shrink : Float
  row_gap : Float
  column_gap : Float
  horizontal_scroll : Bool
  vertical_scroll : Bool
  scrollbar_width : Float
} derive(Eq, Debug)

///|
pub(all) struct NodeSpec {
  key : String
  parent : String?
  kind : NodeKind
  text : String
  source : String
  active : Bool
  enabled : Bool
  focusable : Bool
  style : NodeStyle
} derive(Eq, Debug)

///|
pub(all) struct TextMutation {
  key : String
  value : String
} derive(Eq, Debug)

///|
pub(all) struct BoolMutation {
  key : String
  value : Bool
} derive(Eq, Debug)

///|
pub(all) struct F32Mutation {
  key : String
  value : Float
} derive(Eq, Debug)

///|
pub(all) struct MoveMutation {
  key : String
  parent : String
  index : UInt
} derive(Eq, Debug)

///|
pub(all) enum TreeMutation {
  Mount(NodeSpec)
  Update(NodeSpec)
  SetText(TextMutation)
  SetSource(TextMutation)
  SetBackground(TextMutation)
  SetActive(BoolMutation)
  SetEnabled(BoolMutation)
  SetTop(F32Mutation)
  Move(MoveMutation)
  Remove(String)
} derive(Eq, Debug)

///|
pub(all) struct HostError {
  code : String
  message : String
} derive(Eq, Debug)

///|
pub fn apply(
  _entity : UInt,
  _mutations : Array[TreeMutation],
) -> Result[Unit, HostError] {
  Ok(())
}
