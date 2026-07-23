///|
pub(all) enum NodeKind {
  View
  Flex
  Text
  Image
  Button
  ScrollView
} derive(Eq, Debug)

///|
pub(all) enum TextAlign {
  Left
  Center
  Right
} derive(Eq, Debug)

///|
pub(all) enum ImageFit {
  Fill
  Contain
  Cover
} derive(Eq, Debug)

///|
pub(all) enum FlexDirection {
  Row
  RowReverse
  Column
  ColumnReverse
} derive(Eq, Debug)

///|
pub(all) enum LayoutValue {
  Auto
  Px(Double)
  Percent(Double)
} derive(Eq, Debug)

///|
pub(all) enum UiEventKind {
  Click
  Focus
} derive(Eq, Debug)

///|
pub(all) enum VisualStateValue {
  StringValue(String)
  BoolValue(Bool)
  DoubleValue(Double)
  IntValue(Int)
  LayoutValueValue(LayoutValue)
} derive(Eq, Debug)

///|
pub(all) struct VisualStateSetter {
  target : String
  property : String
  value : VisualStateValue
} derive(Eq, Debug)

///|
pub(all) struct VisualStateDefinition {
  name : String
  setters : Array[VisualStateSetter]
} derive(Eq, Debug)

///|
pub(all) struct VisualTransition {
  from : String?
  to : String?
  duration : Double
  delay : Double
  easing : String
} derive(Eq, Debug)

///|
pub(all) struct VisualStateGroup {
  order : Int
  name : String
  current : String
  interaction : Bool
  states : Array[VisualStateDefinition]
  transitions : Array[VisualTransition]
} derive(Eq, Debug)

///|
pub(all) struct UiEvent {
  kind : UiEventKind
  key : String
} derive(Eq, Debug)

///|
pub(all) struct NodeStyle {
  absolute : Bool
  left : Double
  top : Double
  width : LayoutValue
  height : LayoutValue
  margin_left : Double
  margin_top : Double
  margin_right : Double
  margin_bottom : Double
  padding_left : Double
  padding_top : Double
  padding_right : Double
  padding_bottom : Double
  background : String
  border_color : String
  border : Double
  radius : Double
  outline_color : String
  outline_width : Double
  outline_offset : Double
  color : String
  font_family : String
  font_size : Double
  bold : Bool
  align : TextAlign
  wrap : Bool
  z_index : Int
  fit : ImageFit
  direction : FlexDirection
  flex_basis : LayoutValue
  flex_grow : Double
  flex_shrink : Double
  row_gap : Double
  column_gap : Double
  horizontal_scroll : Bool
  vertical_scroll : Bool
  scrollbar_width : Double
} derive(Eq, Debug)

///|
pub fn NodeStyle::default() -> NodeStyle {
  {
    absolute: false,
    left: 0.0,
    top: 0.0,
    width: Auto,
    height: Auto,
    margin_left: 0.0,
    margin_top: 0.0,
    margin_right: 0.0,
    margin_bottom: 0.0,
    padding_left: 0.0,
    padding_top: 0.0,
    padding_right: 0.0,
    padding_bottom: 0.0,
    background: "",
    border_color: "",
    border: 0.0,
    radius: 0.0,
    outline_color: "",
    outline_width: 0.0,
    outline_offset: 0.0,
    color: "",
    font_family: "",
    font_size: 0.0,
    bold: false,
    align: Left,
    wrap: false,
    z_index: 0,
    fit: Fill,
    direction: Column,
    flex_basis: Auto,
    flex_grow: 0.0,
    flex_shrink: 1.0,
    row_gap: 0.0,
    column_gap: 0.0,
    horizontal_scroll: false,
    vertical_scroll: false,
    scrollbar_width: 0.0,
  }
}

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
  visual_state_groups : Array[VisualStateGroup]
} derive(Eq, Debug)

///|
pub(all) enum TreeMutation {
  Mount(NodeSpec)
  Update(NodeSpec)
  SetText(String, String)
  SetSource(String, String)
  SetBackground(String, String)
  SetActive(String, Bool)
  SetEnabled(String, Bool)
  SetTop(String, Double)
  Move(String, String, Int)
  Remove(String)
} derive(Eq, Debug)

///|
pub(all) suberror HostError {
  InvalidMutation(String, String)
  Released
  WrongWorld(UInt, UInt)
} derive(Eq, Debug)

///|
pub impl Show for HostError with fn output(self, logger) {
  match self {
    InvalidMutation(code, message) => logger.write_string(code + ": " + message)
    Released => logger.write_string("view host is released")
    WrongWorld(expected, actual) =>
      logger.write_string(
        "view host belongs to world " +
        expected.to_string() +
        ", current world is " +
        actual.to_string(),
      )
  }
}
