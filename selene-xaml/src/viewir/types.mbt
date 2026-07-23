///|
pub(all) struct IRTypeRef {
  package_alias : String
  package_path : String
  type_name : String
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct ResourceDocument {
  source_uri : String
  source : String
} derive(Eq, Debug)

///|
pub(all) enum IRValue {
  Constant(IRConstant, @infoset.XamlSourceSpan)
  Binding(String, @infoset.XamlSourceSpan)
} derive(Eq, Debug)

///|
pub(all) enum IRConstant {
  StringValue(String)
  BoolValue(Bool)
  DoubleValue(Double)
  IntValue(Int)
  EnumValue(String)
  LayoutValue(IRLayoutValue)
  RectValue(Double, Double, Double, Double)
  ImageRegionValue(Double, Double, Double, Double)
  NoImageRegion
  GridTracks(Array[IRGridTrack])
} derive(Eq, Debug)

///|
pub(all) enum IRLayoutValue {
  Auto
  Px(Double)
  Percent(Double)
} derive(Eq, Debug)

///|
pub(all) enum IRGridTrackRepetition {
  Count(Int)
  AutoFill
  AutoFit
} derive(Eq, Debug)

///|
pub(all) enum IRGridTrack {
  Auto
  Px(Double)
  Percent(Double)
  Fr(Double)
  MinContent
  MaxContent
  FitContent(IRGridTrack)
  MinMax(IRGridTrack, IRGridTrack)
  Repeat(IRGridTrackRepetition, Array[IRGridTrack])
} derive(Eq, Debug)

///|
pub(all) struct IRProperty {
  name : String
  value : IRValue
} derive(Eq, Debug)

///|
pub(all) struct IRVisualStateSetter {
  target_node : String
  property : String
  value : IRValue
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct IRVisualState {
  name : String
  setters : Array[IRVisualStateSetter]
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct IRVisualTransition {
  from : String?
  to : String?
  duration : Double
  delay : Double
  easing : String
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct IRVisualStateGroup {
  owner_node : String
  name : String
  current : IRValue?
  states : Array[IRVisualState]
  transitions : Array[IRVisualTransition]
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) enum IRNode {
  Element(
    String,
    String,
    String?,
    Array[IRProperty],
    Array[IRNode],
    @infoset.XamlSourceSpan
  )
  Conditional(String, @infoset.XamlSourceSpan, Array[IRNode], Array[IRNode])
  KeyedItems(
    String,
    @infoset.XamlSourceSpan,
    String,
    @infoset.XamlSourceSpan,
    IRTypeRef?,
    Array[IRNode]
  )
} derive(Eq, Debug)

///|
pub(all) struct IRField {
  name : String
  field_type : String
} derive(Eq, Debug)

///|
pub(all) struct IRStruct {
  name : String
  fields : Array[IRField]
} derive(Eq, Debug)

///|
pub(all) struct IRVariant {
  name : String
  payload : String?
} derive(Eq, Debug)

///|
pub(all) struct IREnum {
  name : String
  variants : Array[IRVariant]
} derive(Eq, Debug)

///|
pub(all) struct IRFunction {
  name : String
  parameters : Array[String]
  return_type : String
} derive(Eq, Debug)

///|
pub(all) enum IRViewModelProjection {
  Identity
  Compute(String)
} derive(Eq, Debug)

///|
pub(all) enum IRPatchProjection {
  None
  GeneratedCollections
  Apply(String)
} derive(Eq, Debug)

///|
pub(all) struct IRCollection {
  field_name : String
  item_type : String
  key_field : String
  key_type : String
  patch_replace : String?
  patch_upsert : String?
  patch_remove : String?
  patch_move : String?
} derive(Eq, Debug)

///|
pub(all) struct IRViewIdentity {
  view_name : String
  source_uri : String
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) enum IRDataScopeKind {
  RootViewModel
  TemplateItem
  LocalState
} derive(Eq, Debug)

///|
pub(all) struct IRDataScope {
  id : String
  parent : String?
  value_type : IRTypeRef
  kind : IRDataScopeKind
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct IRBinding {
  id : String
  path : String
  scope_id : String
  steps : Array[IRBindingStep]
  result_type : String
  dependencies : Array[String]
  targets : Array[IRBindingTarget]
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct IRBindingStep {
  declaring_type : String
  step : String
  result_type : String
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct IRBindingTarget {
  node : String
  property : String
  target_type : String
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) struct IRActionRoute {
  id : String
  authored_name : String
  variant_name : String
  event_kind : String
  source_scope : String
  collection_path : String?
  node_template : String
  span : @infoset.XamlSourceSpan
} derive(Eq, Debug)

///|
pub(all) enum IRCapability {
  TreeMutation
  ConditionalTree
  KeyedCollection
  TypedPatch
  ActionRouting
  VisualState
} derive(Eq, Debug)

///|
pub(all) struct IRBusinessContract {
  package_path : String
  structs : Map[String, IRStruct]
  enums : Map[String, IREnum]
  aliases : Map[String, String]
  functions : Map[String, IRFunction]
  model_type : IRTypeRef
  view_model_type : IRTypeRef
  view_model_projection : IRViewModelProjection
  state : IRStruct
  patch : IREnum?
  patch_projection : IRPatchProjection
  action : IREnum
  collections : Map[String, IRCollection]
} derive(Eq, Debug)

///|
pub(all) struct ViewIR {
  identity : IRViewIdentity
  contract : IRBusinessContract
  root : IRNode
  data_scopes : Array[IRDataScope]
  bindings : Array[IRBinding]
  action_routes : Array[IRActionRoute]
  visual_state_groups : Array[IRVisualStateGroup]
  required_capabilities : Array[IRCapability]
} derive(Eq, Debug)

///|
priv struct ParsedContract {
  package_path : String
  structs : Map[String, IRStruct]
  enums : Map[String, IREnum]
  aliases : Map[String, String]
  functions : Map[String, IRFunction]
}

///|
priv struct SyntaxViewIR {
  identity : IRViewIdentity
  data_type : IRTypeRef
  root : SyntaxNode
  visual_state_groups : Array[SyntaxVisualStateGroup]
}

///|
priv enum SyntaxValue {
  Literal(String, @infoset.XamlSourceSpan)
  Binding(String, @infoset.XamlSourceSpan)
}

///|
priv struct SyntaxProperty {
  name : String
  value : SyntaxValue
}

///|
priv struct SyntaxVisualStateSetter {
  target_node : String
  property : String
  value : SyntaxValue
  span : @infoset.XamlSourceSpan
}

///|
priv struct SyntaxVisualState {
  name : String
  setters : Array[SyntaxVisualStateSetter]
  span : @infoset.XamlSourceSpan
}

///|
priv struct SyntaxVisualTransition {
  from : String?
  to : String?
  duration : String
  delay : String
  easing : String
  span : @infoset.XamlSourceSpan
}

///|
priv struct SyntaxVisualStateGroup {
  owner_node : String
  name : String
  current : SyntaxValue?
  states : Array[SyntaxVisualState]
  transitions : Array[SyntaxVisualTransition]
  span : @infoset.XamlSourceSpan
}

///|
priv enum SyntaxNode {
  Element(
    String,
    String,
    String?,
    Array[SyntaxProperty],
    Array[SyntaxNode],
    @infoset.XamlSourceSpan
  )
  Conditional(
    String,
    @infoset.XamlSourceSpan,
    Array[SyntaxNode],
    Array[SyntaxNode]
  )
  KeyedItems(
    String,
    @infoset.XamlSourceSpan,
    String,
    @infoset.XamlSourceSpan,
    IRTypeRef?,
    Array[SyntaxNode]
  )
}

///|
pub(all) suberror ViewIRError {
  Xaml(@infoset.XamlError)
  Unsupported(String, @infoset.XamlSourceSpan)
  InvalidContract(String)
} derive(Eq, Debug)

///|
pub impl Show for ViewIRError with fn output(self, logger) {
  match self {
    Xaml(error) => logger.write_string(error.to_string())
    Unsupported(message, span) =>
      logger.write_string(
        span.source_uri +
        ":" +
        span.start.line.to_string() +
        ":" +
        span.start.column.to_string() +
        " " +
        message,
      )
    InvalidContract(message) => logger.write_string(message)
  }
}

///|
pub fn IRStruct::field(self : IRStruct, name : String) -> IRField? {
  for field in self.fields {
    if field.name == name {
      return Some(field)
    }
  }
  None
}
