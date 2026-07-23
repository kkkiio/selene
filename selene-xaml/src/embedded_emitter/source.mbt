///|
priv struct EmbeddedSourceMapping {
  original_offset : Int
  generated_offset : Int
  length : Int
}

///|
priv struct EmittedView {
  source : String
  mappings : Array[EmbeddedSourceMapping]
}

///|
priv enum EmbeddedValue {
  Literal(@viewir.IRConstant, @infoset.XamlSourceSpan)
  Binding(String, @infoset.XamlSourceSpan)
}

///|
priv struct EmbeddedProperty {
  name : String
  value : EmbeddedValue
}

///|
priv enum EmbeddedNode {
  Element(
    String,
    String,
    String?,
    Array[EmbeddedProperty],
    Array[EmbeddedNode],
    @infoset.XamlSourceSpan
  )
  Conditional(
    String,
    @infoset.XamlSourceSpan,
    Array[EmbeddedNode],
    Array[EmbeddedNode]
  )
  KeyedItems(
    String,
    @infoset.XamlSourceSpan,
    String,
    @infoset.XamlSourceSpan,
    @viewir.IRTypeRef?,
    Array[EmbeddedNode]
  )
}

///|
priv struct EmbeddedProjection {
  model_type : @viewir.IRTypeRef
  view_model_type : @viewir.IRTypeRef
  view_model_projection : @viewir.IRViewModelProjection
  state : @viewir.IRStruct
  patch : @viewir.IREnum?
  patch_projection : @viewir.IRPatchProjection
  collections : Map[String, @viewir.IRCollection]
  bindings : Map[String, @viewir.IRBinding]
  visual_state_groups : Array[@viewir.IRVisualStateGroup]
}

///|
priv struct EmbeddedValueEmission {
  mappings : Array[EmbeddedSourceMapping]
  schema : EmbeddedProjection
  scope_type : String
  receiver : String
}

///|
fn project_embedded_ir(
  ir : @viewir.ViewIR,
) -> (EmbeddedNode, EmbeddedProjection) {
  let bindings : Map[String, @viewir.IRBinding] = Map([])
  for binding in ir.bindings {
    bindings[binding.id] = binding
  }
  let pending : Array[(@viewir.IRNode, String)] = [(ir.root, "root")]
  let projected : Map[String, EmbeddedNode] = Map([])
  let child_links : Map[String, Array[String]] = Map([])
  while pending.length() > 0 {
    let (node, path) = pending.pop().unwrap()
    match node {
      @viewir.IRNode::Element(kind, key, name, properties, children, span) => {
        let values : Array[EmbeddedProperty] = []
        for property in properties {
          let value = match property.value {
            @viewir.IRValue::Binding(id, value_span) =>
              EmbeddedValue::Binding(id, value_span)
            @viewir.IRValue::Constant(constant, value_span) =>
              EmbeddedValue::Literal(constant, value_span)
          }
          values.push({ name: property.name, value })
        }
        let links : Array[String] = []
        for index, child in children {
          let child_path = path + "/" + index.to_string()
          links.push(child_path)
          pending.push((child, child_path))
        }
        projected[path] = EmbeddedNode::Element(
          kind,
          key,
          name,
          values,
          [],
          span,
        )
        child_links[path] = links
      }
      @viewir.IRNode::Conditional(binding, span, then_nodes, else_nodes) => {
        let then_links : Array[String] = []
        let else_links : Array[String] = []
        for index, child in then_nodes {
          let child_path = path + "/then/" + index.to_string()
          then_links.push(child_path)
          pending.push((child, child_path))
        }
        for index, child in else_nodes {
          let child_path = path + "/else/" + index.to_string()
          else_links.push(child_path)
          pending.push((child, child_path))
        }
        projected[path] = EmbeddedNode::Conditional(binding, span, [], [])
        child_links[path + ":then"] = then_links
        child_links[path + ":else"] = else_links
      }
      @viewir.IRNode::KeyedItems(
        binding,
        source_span,
        key_path,
        key_span,
        item_type,
        children
      ) => {
        let links : Array[String] = []
        for index, child in children {
          let child_path = path + "/item/" + index.to_string()
          links.push(child_path)
          pending.push((child, child_path))
        }
        projected[path] = EmbeddedNode::KeyedItems(
          bindings[binding].path,
          source_span,
          key_path,
          key_span,
          item_type,
          [],
        )
        child_links[path] = links
      }
    }
  }
  let paths = projected.keys().collect()
  paths.sort()
  for path in paths.rev() {
    match projected[path] {
      EmbeddedNode::Element(kind, key, name, values, _, span) =>
        projected[path] = EmbeddedNode::Element(
          kind,
          key,
          name,
          values,
          child_links.get(path).unwrap_or([]).map(child => projected[child]),
          span,
        )
      EmbeddedNode::Conditional(binding, span, _, _) =>
        projected[path] = EmbeddedNode::Conditional(
          binding,
          span,
          child_links
          .get(path + ":then")
          .unwrap_or([])
          .map(child => projected[child]),
          child_links
          .get(path + ":else")
          .unwrap_or([])
          .map(child => projected[child]),
        )
      EmbeddedNode::KeyedItems(
        binding,
        source_span,
        key_path,
        key_span,
        item_type,
        _
      ) =>
        projected[path] = EmbeddedNode::KeyedItems(
          binding,
          source_span,
          key_path,
          key_span,
          item_type,
          child_links.get(path).unwrap_or([]).map(child => projected[child]),
        )
    }
  }
  (
    projected["root"],
    {
      model_type: ir.contract.model_type,
      view_model_type: ir.contract.view_model_type,
      view_model_projection: ir.contract.view_model_projection,
      state: ir.contract.state,
      patch: ir.contract.patch,
      patch_projection: ir.contract.patch_projection,
      collections: ir.contract.collections,
      bindings,
      visual_state_groups: ir.visual_state_groups,
    },
  )
}

///|
fn emit_view_source(
  plan : @viewir.ViewIR,
  generated_header : String,
) -> EmittedView raise @viewir.ViewIRError {
  let (root, analysis) = project_embedded_ir(plan)
  let schema = analysis
  let output = StringBuilder::new()
  let mappings : Array[EmbeddedSourceMapping] = []
  let routes = plan.action_routes.copy()
  let action_shapes : Map[String, Bool] = Map([])
  for action in routes {
    action_shapes[action.variant_name] = action.collection_path is Some(_)
  }
  let action_names = action_shapes.keys().collect()
  action_names.sort()
  output <+ "\{generated_header}"
  if action_names.length() == 0 {
    output <+
      $|///|
      $|pub(all) enum \{plan.identity.view_name}Action {} derive(Eq, Debug)
      $|
      $|
  } else {
    output <+
      $|///|
      $|pub(all) enum \{plan.identity.view_name}Action {
      $|
    for name in action_names {
      output <+ "  \{name}"
      if action_shapes[name] {
        output <+ "(String)"
      }
      output <+ "\n"
    }
    output <+ "} derive(Eq, Debug)\n\n"
  }
  output <+
    $|///|
    $|pub(all) suberror \{plan.identity.view_name}Error {
    $|  AlreadyMounted
    $|  NotMounted
    $|  DeadEntity
    $|  DuplicateKey(String, String)
    $|  InvalidPatch(String)
    $|  Host(@ui_view.HostError)
    $|} derive(Eq, Debug)
    $|
    $|///|
    $|pub impl Show for \{plan.identity.view_name}Error with fn output(self, logger) {
    $|  match self {
    $|    AlreadyMounted =>
    $|      logger.write_string("view is already mounted on this entity")
    $|    NotMounted => logger.write_string("view is not mounted on this entity")
    $|    DeadEntity => logger.write_string("view entity is not alive")
    $|    DuplicateKey(path, key) =>
    $|      logger.write_string("duplicate or empty key in " + path + ": " + key)
    $|    InvalidPatch(message) => logger.write_string(message)
    $|    Host(error) => logger.write_string(error.to_string())
    $|  }
    $|}
    $|
    $|///|
    $|fn generated_compute_view_model(model : \{analysis.model_type.type_name}) -> \{analysis.view_model_type.type_name} {
    $|  
  match analysis.view_model_projection {
    @viewir.IRViewModelProjection::Identity => output <+ "model\n"
    @viewir.IRViewModelProjection::Compute(function) =>
      output <+ "@\{analysis.model_type.package_alias}.\{function}(model)\n"
  }
  output <+ "}\n\n"
  emit_view_runtime(output, plan, analysis)
  let specs_signature = "fn generated_specs(state : " +
    analysis.state.name +
    ") -> Array[@ui_view.NodeSpec] raise " +
    plan.identity.view_name +
    "Error {"
  if specs_signature.length() <= 81 {
    output <+ "///|\n\{specs_signature}\n"
  } else {
    output <+
      $|///|
      $|fn generated_specs(
      $|  state : \{analysis.state.name},
      $|) -> Array[@ui_view.NodeSpec] raise \{plan.identity.view_name}Error {
      $|
  }
  output <+ "  let nodes : Array[@ui_view.NodeSpec] = []\n"
  let serial = [0]
  emit_plan_specs(
    output,
    mappings,
    routes,
    root,
    schema,
    analysis,
    "state",
    analysis.state.name,
    None,
    None,
    None,
    1,
    serial,
  )
  output <+ "  nodes\n}\n\n"
  emit_view_methods(output, routes, plan, analysis)
  { source: output.to_string(), mappings }
}

///|
fn emit_view_runtime(
  output : StringBuilder,
  plan : @viewir.ViewIR,
  analysis : EmbeddedProjection,
) -> Unit {
  output <+
    $|///|
    $|#warnings("-unused_value")
    $|fn generated_rect_component(
    $|  value : String,
    $|  index : Int,
    $|  path : String,
    $|) -> Double raise \{plan.identity.view_name}Error {
    $|  let parts = value.split(" ").filter(part => part != "").collect()
    $|  let selected = match parts.length() {
    $|    1 => parts[0]
    $|    2 => if index == 0 || index == 2 { parts[1] } else { parts[0] }
    $|    4 =>
    $|      match index {
    $|        0 => parts[3]
    $|        1 => parts[0]
    $|        2 => parts[1]
    $|        _ => parts[2]
    $|      }
    $|    _ => raise InvalidPatch("invalid rect value for " + path + ": " + value)
    $|  }
    $|  @string.parse_double(selected) catch {
    $|    _ =>
    $|      raise InvalidPatch(
    $|        "invalid number for " + path + ": " + selected.to_owned(),
    $|      )
    $|  }
    $|}
    $|
    $|///|
    $|fn generated_contains(specs : Array[@ui_view.NodeSpec], key : String) -> Bool {
    $|  for spec in specs {
    $|    if spec.key == key {
    $|      return true
    $|    }
    $|  }
    $|  false
    $|}
    $|
    $|///|
    $|fn generated_parent_index(
    $|  specs : Array[@ui_view.NodeSpec],
    $|  parent : String?,
    $|  key : String,
    $|) -> Int {
    $|  let mut sibling_index = 0
    $|  for spec in specs {
    $|    if spec.parent == parent {
    $|      if spec.key == key {
    $|        return sibling_index
    $|      }
    $|      sibling_index += 1
    $|    }
    $|  }
    $|  -1
    $|}
    $|
    $|///|
    $|fn generated_diff(
    $|  previous : Array[@ui_view.NodeSpec],
    $|  desired : Array[@ui_view.NodeSpec],
    $|) -> Array[@ui_view.TreeMutation] {
    $|  if previous == desired {
    $|    return []
    $|  }
    $|  let previous_by_key : Map[String, @ui_view.NodeSpec] = Map([])
    $|  let desired_by_key : Map[String, @ui_view.NodeSpec] = Map([])
    $|  for spec in previous {
    $|    previous_by_key[spec.key] = spec
    $|  }
    $|  for spec in desired {
    $|    desired_by_key[spec.key] = spec
    $|  }
    $|  let mutations : Array[@ui_view.TreeMutation] = []
    $|  for spec in previous {
    $|    if !desired_by_key.contains(spec.key) {
    $|      let removed_root = match spec.parent {
    $|        Some(parent) => desired_by_key.contains(parent)
    $|        None => true
    $|      }
    $|      if removed_root {
    $|        mutations.push(@ui_view.TreeMutation::Remove(spec.key))
    $|      }
    $|    }
    $|  }
    $|  for spec in desired {
    $|    match previous_by_key.get(spec.key) {
    $|      None => {
    $|        mutations.push(@ui_view.TreeMutation::Mount(spec))
    $|        match spec.parent {
    $|          Some(parent) =>
    $|            mutations.push(
    $|              @ui_view.TreeMutation::Move(
    $|                spec.key,
    $|                parent,
    $|                generated_parent_index(desired, spec.parent, spec.key),
    $|              ),
    $|            )
    $|          None => ()
    $|        }
    $|      }
    $|      Some(old) => {
    $|        let moved = old.parent != spec.parent ||
    $|          generated_parent_index(previous, old.parent, old.key) !=
    $|          generated_parent_index(desired, spec.parent, spec.key)
    $|        match spec.parent {
    $|          Some(parent) if moved =>
    $|            mutations.push(
    $|              @ui_view.TreeMutation::Move(
    $|                spec.key,
    $|                parent,
    $|                generated_parent_index(desired, spec.parent, spec.key),
    $|              ),
    $|            )
    $|          _ => ()
    $|        }
    $|        let precise_old = {
    $|          ..old,
    $|          parent: spec.parent,
    $|          text: spec.text,
    $|          source: spec.source,
    $|          active: spec.active,
    $|          enabled: spec.enabled,
    $|          style: {
    $|            ..old.style,
    $|            background: spec.style.background,
    $|            top: spec.style.top,
    $|          },
    $|        }
    $|        if precise_old != spec {
    $|          mutations.push(@ui_view.TreeMutation::Update(spec))
    $|        } else {
    $|          if old.text != spec.text {
    $|            mutations.push(@ui_view.TreeMutation::SetText(spec.key, spec.text))
    $|          }
    $|          if old.source != spec.source {
    $|            mutations.push(@ui_view.TreeMutation::SetSource(spec.key, spec.source))
    $|          }
    $|          if old.style.background != spec.style.background {
    $|            mutations.push(@ui_view.TreeMutation::SetBackground(spec.key, spec.style.background))
    $|          }
    $|          if old.active != spec.active {
    $|            mutations.push(@ui_view.TreeMutation::SetActive(spec.key, spec.active))
    $|          }
    $|          if old.enabled != spec.enabled {
    $|            mutations.push(@ui_view.TreeMutation::SetEnabled(spec.key, spec.enabled))
    $|          }
    $|          if old.style.top != spec.style.top {
    $|            mutations.push(@ui_view.TreeMutation::SetTop(spec.key, spec.style.top))
    $|          }
    $|        }
    $|      }
    $|    }
    $|  }
    $|  mutations
    $|}
    $|
    $|///|
    $|#warnings("-struct_never_constructed")
    $|pub struct \{plan.identity.view_name} {}
    $|
    $|///|
    $|priv struct GeneratedViewRecord {
    $|  mut model : \{analysis.model_type.type_name}
    $|  mut view_model : \{analysis.view_model_type.type_name}
    $|  mut specs : Array[@ui_view.NodeSpec]
    $|}
    $|
    $|///|
    $|let generated_view_records : Map[@entity.Entity, GeneratedViewRecord] = Map([])
    $|
    $|///|
    $|pub(all) struct \{plan.identity.view_name}ActionEvent {
    $|  entity : @entity.Entity
    $|  action : \{plan.identity.view_name}Action
    $|}
    $|
    $|///|
    $|pub let action_event_bus : @event.Events[\{plan.identity.view_name}ActionEvent] = @event.Events()
    $|
    $|///|
    $|let generated_event_reader : @event.EventReader[
    $|  @ui_view.UiViewEvent,
    $|] = @event.EventReader()
    $|
    $|
}

///|
fn emit_plan_specs(
  output : StringBuilder,
  mappings : Array[EmbeddedSourceMapping],
  routes : Array[@viewir.IRActionRoute],
  node : EmbeddedNode,
  schema : EmbeddedProjection,
  analysis : EmbeddedProjection,
  receiver : String,
  scope_type : String,
  parent_template : String?,
  item_prefix_template : String?,
  collection_path : String?,
  indent : Int,
  serial : Array[Int],
) -> Unit raise @viewir.ViewIRError {
  let padding = "  ".repeat(indent)
  let emission : EmbeddedValueEmission = {
    mappings,
    schema,
    scope_type,
    receiver,
  }
  match node {
    Element(kind, key, _, properties, children, _) => {
      let property_map : Map[String, EmbeddedValue] = Map([])
      for property in properties {
        if ![
            "Text", "Source", "Active", "Enabled", "Focusable", "FocusScope", "AutoFocus",
            "TabIndex", "Navigation.Up", "Navigation.Down", "Navigation.Left", "Navigation.Right",
            "Position", "Left", "Top", "Width", "Height", "Margin", "Padding", "Background",
            "BorderColor", "Border", "Radius", "Color", "FontFamily", "FontSize",
            "Bold", "Align", "Wrap", "ZIndex", "Fit", "Direction", "Grow", "Shrink",
            "Basis", "RowGap", "Gap", "ColumnGap", "HorizontalScroll", "VerticalScroll",
            "ScrollbarWidth", "OutlineColor", "OutlineWidth", "OutlineOffset", "OnClick",
            "OnFocus", "Rows", "Columns", "AutoFlow", "Grid.Row", "Grid.Column",
            "Grid.RowSpan", "Grid.ColumnSpan",
          ].contains(property.name) {
          let span = match property.value {
            Literal(_, span) | Binding(_, span) => span
          }
          raise @viewir.ViewIRError::Unsupported(
            "unsupported generated property: " + property.name,
            span,
          )
        }
        property_map[property.name] = property.value
      }
      let node_template = match item_prefix_template {
        Some(prefix) => prefix + "/" + key
        None => key
      }
      let node_expression = if node_template.contains("__SELENE_KEY__") {
        "\"" +
        node_template.replace_all(
          old="__SELENE_KEY__",
          new="\\{generated_item_key_" + serial[0].to_string() + "}",
        ) +
        "\""
      } else {
        node_template.escape()
      }
      output <+ "\{padding}nodes.push({\n"
      output <+ "\{padding}  key: \{node_expression},\n"
      match parent_template {
        Some(parent) => {
          let parent_expression = if parent.contains("__SELENE_KEY__") {
            "\"" +
            parent.replace_all(
              old="__SELENE_KEY__",
              new="\\{generated_item_key_" + serial[0].to_string() + "}",
            ) +
            "\""
          } else {
            parent.escape()
          }
          let parent_line = padding +
            "  parent: Some(" +
            parent_expression +
            "),"
          if parent_line.length() <= 81 {
            output <+ "\{parent_line}\n"
          } else {
            output <+
              $|\{padding}  parent: Some(
              $|\{padding}    \{parent_expression},
              $|\{padding}  ),
              $|
          }
        }
        None => output <+ "\{padding}  parent: None,\n"
      }
      output <+ "\{padding}  kind: @ui_view.NodeKind::\{kind},\n"
      let focusable_fallback = if kind == "Button" { "true" } else { "false" }
      output <+
        $|\{padding}  text: \{fragment => emit_typed_value(fragment, emission, property_map.get("Text"), "string", "\"\"")},
        $|\{padding}  source: \{fragment => emit_typed_value(fragment, emission, property_map.get("Source"), "string", "\"\"")},
        $|\{padding}  active: \{fragment => emit_typed_value(fragment, emission, property_map.get("Active"), "bool", "true")},
        $|\{padding}  enabled: \{fragment => emit_typed_value(fragment, emission, property_map.get("Enabled"), "bool", "true")},
        $|\{padding}  focusable: \{fragment => emit_typed_value(fragment, emission, property_map.get("Focusable"), "bool", focusable_fallback)},
        $|\{padding}  tab_index: \{fragment => emit_typed_value(fragment, emission, property_map.get("TabIndex"), "int", "0")},
        $|\{padding}  focus_scope: \{fragment => emit_typed_value(fragment, emission, property_map.get("FocusScope"), "bool", "false")},
        $|\{padding}  auto_focus: \{fragment => emit_typed_value(fragment, emission, property_map.get("AutoFocus"), "bool", "false")},
        $|\{padding}  navigation_up: \{fragment => emit_typed_value(fragment, emission, property_map.get("Navigation.Up"), "string", "\"\"")},
        $|\{padding}  navigation_down: \{fragment => emit_typed_value(fragment, emission, property_map.get("Navigation.Down"), "string", "\"\"")},
        $|\{padding}  navigation_left: \{fragment => emit_typed_value(fragment, emission, property_map.get("Navigation.Left"), "string", "\"\"")},
        $|\{padding}  navigation_right: \{fragment => emit_typed_value(fragment, emission, property_map.get("Navigation.Right"), "string", "\"\"")},
        $|\{padding}  style: {
        $|
      let absolute = match property_map.get("Position") {
        None | Some(Literal(@viewir.IRConstant::EnumValue("Relative"), _)) =>
          false
        Some(Literal(@viewir.IRConstant::EnumValue("Absolute"), _)) => true
        Some(Literal(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "Position requires an enum constant", span,
          )
        Some(Binding(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "generated property does not support Binding: Position", span,
          )
      }
      output <+ "\{padding}    absolute: \{absolute},\n"
      for entry in [("Left", "left"), ("Top", "top")] {
        let (property, field) = entry
        output <+
          "\{padding}    \{field}: \{fragment => emit_typed_value(fragment, emission, property_map.get(property), "number", "0.0")},\n"
      }
      for entry in [("Width", "width"), ("Height", "height")] {
        let (property, field) = entry
        output <+
          "\{padding}    \{field}: \{fragment => emit_layout_value(fragment, emission, property_map.get(property))},\n"
      }
      for
        entry in [
          ("Margin", "margin_left", 0),
          ("Margin", "margin_top", 1),
          ("Margin", "margin_right", 2),
          ("Margin", "margin_bottom", 3),
          ("Padding", "padding_left", 0),
          ("Padding", "padding_top", 1),
          ("Padding", "padding_right", 2),
          ("Padding", "padding_bottom", 3),
        ] {
        let (property, field, component) = entry
        output <+
          "\{padding}    \{field}: \{fragment => emit_rect_value(fragment, emission, property_map.get(property), component)},\n"
      }
      for
        entry in [("Background", "background"), ("BorderColor", "border_color")] {
        let (property, field) = entry
        output <+
          "\{padding}    \{field}: \{fragment => emit_typed_value(fragment, emission, property_map.get(property), "string", "\"\"")},\n"
      }
      output <+
        $|\{padding}    border: \{fragment => emit_typed_value(fragment, emission, property_map.get("Border"), "number", "0.0")},
        $|\{padding}    radius: \{fragment => emit_typed_value(fragment, emission, property_map.get("Radius"), "number", "0.0")},
        $|\{padding}    outline_color: \{fragment => emit_typed_value(fragment, emission, property_map.get("OutlineColor"), "string", "\"\"")},
        $|\{padding}    outline_width: \{fragment => emit_typed_value(fragment, emission, property_map.get("OutlineWidth"), "number", "0.0")},
        $|\{padding}    outline_offset: \{fragment => emit_typed_value(fragment, emission, property_map.get("OutlineOffset"), "number", "0.0")},
        $|
      for entry in [("Color", "color"), ("FontFamily", "font_family")] {
        let (property, field) = entry
        output <+
          "\{padding}    \{field}: \{fragment => emit_typed_value(fragment, emission, property_map.get(property), "string", "\"\"")},\n"
      }
      output <+
        $|\{padding}    font_size: \{fragment => emit_typed_value(fragment, emission, property_map.get("FontSize"), "number", "0.0")},
        $|\{padding}    bold: \{fragment => emit_typed_value(fragment, emission, property_map.get("Bold"), "bool", "false")}
      let align = match property_map.get("Align") {
        None | Some(Literal(@viewir.IRConstant::EnumValue("Left"), _)) => "Left"
        Some(Literal(@viewir.IRConstant::EnumValue("Center"), _)) => "Center"
        Some(Literal(@viewir.IRConstant::EnumValue("Right"), _)) => "Right"
        Some(Literal(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "Align requires an enum constant", span,
          )
        Some(Binding(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "generated property does not support Binding: Align", span,
          )
      }
      output <+ ",\n\{padding}    align: @ui_view.TextAlign::\{align},\n"
      let wrap = match property_map.get("Wrap") {
        None => false
        Some(Literal(@viewir.IRConstant::EnumValue("NoWrap"), _)) => false
        Some(Literal(@viewir.IRConstant::EnumValue("WordWrap"), _)) => true
        Some(Literal(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "Wrap requires an enum constant", span,
          )
        Some(Binding(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "generated property does not support Binding: Wrap", span,
          )
      }
      output <+ "\{padding}    wrap: \{wrap.to_string()},\n"
      output <+
        "\{padding}    z_index: \{fragment => emit_typed_value(fragment, emission, property_map.get("ZIndex"), "int", "0")}"
      let fit = match property_map.get("Fit") {
        None | Some(Literal(@viewir.IRConstant::EnumValue("Fill"), _)) => "Fill"
        Some(Literal(@viewir.IRConstant::EnumValue("Contain"), _)) => "Contain"
        Some(Literal(@viewir.IRConstant::EnumValue("Cover"), _)) => "Cover"
        Some(Literal(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "Fit requires an enum constant", span,
          )
        Some(Binding(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "generated property does not support Binding: Fit", span,
          )
      }
      output <+ ",\n\{padding}    fit: @ui_view.ImageFit::\{fit},\n"
      let direction = match property_map.get("Direction") {
        None | Some(Literal(@viewir.IRConstant::EnumValue("Column"), _)) =>
          "Column"
        Some(Literal(@viewir.IRConstant::EnumValue("Row"), _)) => "Row"
        Some(Literal(@viewir.IRConstant::EnumValue("RowReverse"), _)) =>
          "RowReverse"
        Some(Literal(@viewir.IRConstant::EnumValue("ColumnReverse"), _)) =>
          "ColumnReverse"
        Some(Literal(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "Direction requires an enum constant", span,
          )
        Some(Binding(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "generated property does not support Binding: Direction", span,
          )
      }
      output <+
        "\{padding}    direction: @ui_view.FlexDirection::\{direction},\n"
      output <+
        $|\{padding}    flex_basis: \{fragment => emit_layout_value(fragment, emission, property_map.get("Basis"))},
        $|\{padding}    flex_grow: \{fragment => emit_typed_value(fragment, emission, property_map.get("Grow"), "number", "0.0")},
        $|\{padding}    flex_shrink: \{fragment => emit_typed_value(fragment, emission, property_map.get("Shrink"), "number", "1.0")},
        $|
      let row_gap = match property_map.get("RowGap") {
        Some(value) => Some(value)
        None => property_map.get("Gap")
      }
      let column_gap = match property_map.get("ColumnGap") {
        Some(value) => Some(value)
        None => property_map.get("Gap")
      }
      output <+
        $|\{padding}    row_gap: \{fragment => emit_typed_value(fragment, emission, row_gap, "number", "0.0")},
        $|\{padding}    column_gap: \{fragment => emit_typed_value(fragment, emission, column_gap, "number", "0.0")},
        $|\{padding}    grid_rows: \{fragment => emit_grid_tracks(fragment, property_map.get("Rows"))},
        $|\{padding}    grid_columns: \{fragment => emit_grid_tracks(fragment, property_map.get("Columns"))}
      let auto_flow = match property_map.get("AutoFlow") {
        None | Some(Literal(@viewir.IRConstant::EnumValue("Row"), _)) => "Row"
        Some(Literal(@viewir.IRConstant::EnumValue("Column"), _)) => "Column"
        Some(Literal(@viewir.IRConstant::EnumValue("RowDense"), _)) =>
          "RowDense"
        Some(Literal(@viewir.IRConstant::EnumValue("ColumnDense"), _)) =>
          "ColumnDense"
        Some(Literal(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "AutoFlow requires an enum constant", span,
          )
        Some(Binding(_, span)) =>
          raise @viewir.ViewIRError::Unsupported(
            "generated property does not support Binding: AutoFlow", span,
          )
      }
      output <+
        ",\n\{padding}    grid_auto_flow: @ui_view.GridAutoFlow::\{auto_flow},\n"
      for entry in [("Grid.Row", "grid_row"), ("Grid.Column", "grid_column")] {
        let (property, field) = entry
        output <+ "\{padding}    \{field}: "
        match property_map.get(property) {
          None => output <+ "None"
          Some(Literal(@viewir.IRConstant::IntValue(value), _)) =>
            output <+ "Some(\{value})"
          Some(Literal(_, span)) =>
            raise @viewir.ViewIRError::Unsupported(
              property + " requires an integer constant",
              span,
            )
          Some(Binding(_, span)) =>
            raise @viewir.ViewIRError::Unsupported(
              "generated property does not support Binding: " + property,
              span,
            )
        }
        output <+ ",\n"
      }
      for
        entry in [
          ("Grid.RowSpan", "grid_row_span"),
          ("Grid.ColumnSpan", "grid_column_span"),
        ] {
        let (property, field) = entry
        output <+
          "\{padding}    \{field}: \{fragment => emit_typed_value(fragment, emission, property_map.get(property), "int", "1")},\n"
      }
      output <+
        $|\{padding}    horizontal_scroll: \{fragment => emit_typed_value(fragment, emission, property_map.get("HorizontalScroll"), "bool", "false")},
        $|\{padding}    vertical_scroll: \{fragment => emit_typed_value(fragment, emission, property_map.get("VerticalScroll"), "bool", "false")},
        $|\{padding}    scrollbar_width: \{fragment => emit_typed_value(fragment, emission, property_map.get("ScrollbarWidth"), "number", "0.0")},
        $|\{padding}  },
        $|
      emit_embedded_visual_state_groups(
        output,
        mappings,
        analysis,
        node_template,
        receiver,
        scope_type,
        serial[0],
        indent + 1,
      )
      output <+ "\{padding}})\n"
      for child in children {
        emit_plan_specs(
          output,
          mappings,
          routes,
          child,
          schema,
          analysis,
          receiver,
          scope_type,
          Some(node_template),
          item_prefix_template,
          collection_path,
          indent,
          serial,
        )
      }
    }
    Conditional(path, span, then_nodes, else_nodes) => {
      output <+
        "\{padding}if \{fragment => emit_mapped_binding(fragment, emission, path, span, "bool")} {\n"
      for child in then_nodes {
        emit_plan_specs(
          output,
          mappings,
          routes,
          child,
          schema,
          analysis,
          receiver,
          scope_type,
          parent_template,
          item_prefix_template,
          collection_path,
          indent + 1,
          serial,
        )
      }
      if else_nodes.length() > 0 {
        output <+ "\{padding}} else {\n"
        for child in else_nodes {
          emit_plan_specs(
            output,
            mappings,
            routes,
            child,
            schema,
            analysis,
            receiver,
            scope_type,
            parent_template,
            item_prefix_template,
            collection_path,
            indent + 1,
            serial,
          )
        }
      }
      output <+ "\{padding}}\n"
    }
    KeyedItems(path, items_span, _, key_span, _, children) => {
      let collection = analysis.collections[path]
      if collection_path is Some(_) {
        raise @viewir.ViewIRError::Unsupported(
          "nested ItemsControl is not supported by generated views", key_span,
        )
      }
      serial[0] += 1
      let suffix = serial[0].to_string()
      let item = "generated_item_" + suffix
      let item_key = "generated_item_key_" + suffix
      let seen = "generated_seen_" + suffix
      output.write_string(
        padding + "let " + seen + " : Map[String, Bool] = Map([])\n",
      )
      output <+ "\{padding}for \{item} in "
      emit_mapped_raw(
        output,
        mappings,
        receiver + "." + collection.field_name,
        items_span,
      )
      output <+ " {\n"
      output <+ "\{padding}  let \{item_key} = "
      let key_expression = item +
        "." +
        collection.key_field +
        (if collection.key_type == "String" { "" } else { ".to_string()" })
      emit_mapped_raw(output, mappings, key_expression, key_span)
      let duplicate_condition = padding +
        "  if " +
        item_key +
        " == \"\" || " +
        seen +
        ".contains(" +
        item_key +
        ") {"
      if duplicate_condition.length() <= 81 {
        output <+ "\n\{duplicate_condition}\n"
      } else {
        output.write_string(
          "\n" +
          padding +
          "  if " +
          item_key +
          " == \"\" ||\n" +
          padding +
          "    " +
          seen +
          ".contains(" +
          item_key +
          ") {\n",
        )
      }
      output.write_string(
        padding +
        "    raise DuplicateKey(" +
        path.escape() +
        ", " +
        item_key +
        ")\n",
      )
      output.write_string(
        padding +
        "  }\n" +
        padding +
        "  " +
        seen +
        "[" +
        item_key +
        "] = true\n",
      )
      let base = parent_template.unwrap_or("") +
        "/" +
        kebab_case(path) +
        ":__SELENE_KEY__"
      for child in children {
        emit_plan_specs(
          output,
          mappings,
          routes,
          child,
          schema,
          analysis,
          item,
          collection.item_type,
          parent_template,
          Some(base),
          Some(path),
          indent + 1,
          serial,
        )
      }
      output <+ "\{padding}}\n"
    }
  }
}

///|
fn emit_embedded_visual_state_groups(
  output : StringBuilder,
  mappings : Array[EmbeddedSourceMapping],
  analysis : EmbeddedProjection,
  owner_node : String,
  receiver : String,
  scope_type : String,
  item_serial : Int,
  indent : Int,
) -> Unit raise @viewir.ViewIRError {
  let padding = "  ".repeat(indent)
  let emission : EmbeddedValueEmission = {
    mappings,
    schema: analysis,
    scope_type,
    receiver,
  }
  output <+ "\{padding}visual_state_groups: [\n"
  for order, group in analysis.visual_state_groups {
    if group.owner_node != owner_node {
      continue
    }
    output <+
      $|\{padding}  {
      $|\{padding}    order: \{order},
      $|\{padding}    name: \{group.name.escape()},
      $|\{padding}    current: 
    match group.current {
      None => output <+ "\"\""
      Some(@viewir.IRValue::Constant(@viewir.IRConstant::StringValue(value), _)) =>
        output <+ "\{value.escape()}"
      Some(@viewir.IRValue::Binding(id, span)) =>
        if analysis.bindings[id].result_type == "Bool" {
          output <+
            "if \{fragment => emit_mapped_binding(fragment, emission, id, span, "bool")} { \"Selected\" } else { \"Normal\" }"
        } else {
          emit_mapped_binding(output, emission, id, span, "string")
        }
      Some(@viewir.IRValue::Constant(_, span)) =>
        raise @viewir.ViewIRError::Unsupported(
          "VisualStateGroup.Current requires String or Bool", span,
        )
    }
    output <+
      $|,
      $|\{padding}    interaction: \{(group.current is None).to_string()},
      $|\{padding}    states: [
      $|
    for state in group.states {
      output <+
        $|\{padding}      {
        $|\{padding}        name: \{state.name.escape()},
        $|\{padding}        setters: [
        $|
      for setter in state.setters {
        let target = if setter.target_node.contains("__SELENE_KEY__") {
          "\"" +
          setter.target_node.replace_all(
            old="__SELENE_KEY__",
            new="\\{generated_item_key_" + item_serial.to_string() + "}",
          ) +
          "\""
        } else {
          setter.target_node.escape()
        }
        output <+
          "\{padding}          { target: \{target}, property: \{setter.property.escape()}, value: "
        match setter.value {
          @viewir.IRValue::Binding(id, span) => {
            let mut target_type = "String"
            for binding_target in analysis.bindings[id].targets {
              if binding_target.node == setter.target_node &&
                binding_target.property == setter.property {
                target_type = binding_target.target_type
                break
              }
            }
            match target_type {
              "String" =>
                output <+
                  "@ui_view.VisualStateValue::StringValue(\{fragment => emit_mapped_binding(fragment, emission, id, span, "string")})"
              "Bool" =>
                output <+
                  "@ui_view.VisualStateValue::BoolValue(\{fragment => emit_mapped_binding(fragment, emission, id, span, "bool")})"
              "LayoutValue" =>
                output <+
                  "@ui_view.VisualStateValue::LayoutValueValue(@ui_view.LayoutValue::Px(\{fragment => emit_mapped_binding(fragment, emission, id, span, "number")}))"
              "Int" =>
                output <+
                  "@ui_view.VisualStateValue::IntValue(\{fragment => emit_mapped_binding(fragment, emission, id, span, "int")})"
              _ =>
                output <+
                  "@ui_view.VisualStateValue::DoubleValue(\{fragment => emit_mapped_binding(fragment, emission, id, span, "number")})"
            }
          }
          @viewir.IRValue::Constant(constant, _) =>
            match constant {
              @viewir.IRConstant::StringValue(value) =>
                output <+
                  "@ui_view.VisualStateValue::StringValue(\{value.escape()})"
              @viewir.IRConstant::BoolValue(value) =>
                output <+ "@ui_view.VisualStateValue::BoolValue(\{value})"
              @viewir.IRConstant::DoubleValue(value) =>
                output <+ "@ui_view.VisualStateValue::DoubleValue(\{value})"
              @viewir.IRConstant::IntValue(value) =>
                output <+ "@ui_view.VisualStateValue::IntValue(\{value})"
              @viewir.IRConstant::LayoutValue(value) => {
                output <+ "@ui_view.VisualStateValue::LayoutValueValue("
                match value {
                  @viewir.IRLayoutValue::Auto =>
                    output <+ "@ui_view.LayoutValue::Auto"
                  @viewir.IRLayoutValue::Px(number) =>
                    output <+ "@ui_view.LayoutValue::Px(\{number})"
                  @viewir.IRLayoutValue::Percent(number) =>
                    output <+ "@ui_view.LayoutValue::Percent(\{number})"
                }
                output <+ ")"
              }
              @viewir.IRConstant::EnumValue(value) =>
                output <+
                  "@ui_view.VisualStateValue::StringValue(\{value.escape()})"
              @viewir.IRConstant::RectValue(_, _, _, _) =>
                raise @viewir.ViewIRError::Unsupported(
                  "VisualState does not support Rect setter values",
                  setter.span,
                )
              @viewir.IRConstant::GridTracks(_) =>
                raise @viewir.ViewIRError::Unsupported(
                  "VisualState does not support Grid track setter values",
                  setter.span,
                )
            }
        }
        output <+ " },\n"
      }
      output <+
        $|\{padding}        ],
        $|\{padding}      },
        $|
    }
    output <+
      $|\{padding}    ],
      $|\{padding}    transitions: [
      $|
    for transition in group.transitions {
      output <+
        $|\{padding}      {
        $|\{padding}        from: \{transition.from.map(value => "Some(" + value.escape() + ")").unwrap_or("None")},
        $|\{padding}        to: \{transition.to.map(value => "Some(" + value.escape() + ")").unwrap_or("None")},
        $|\{padding}        duration: \{transition.duration},
        $|\{padding}        delay: \{transition.delay},
        $|\{padding}        easing: \{transition.easing.escape()},
        $|\{padding}      },
        $|
    }
    output <+
      $|\{padding}    ],
      $|\{padding}  },
      $|
  }
  output <+ "\{padding}],\n"
}

///|
fn emit_layout_value(
  output : StringBuilder,
  emission : EmbeddedValueEmission,
  value : EmbeddedValue?,
) -> Unit raise @viewir.ViewIRError {
  match value {
    None => output <+ "@ui_view.LayoutValue::Auto"
    Some(Literal(@viewir.IRConstant::LayoutValue(layout), _)) =>
      match layout {
        @viewir.IRLayoutValue::Auto => output <+ "@ui_view.LayoutValue::Auto"
        @viewir.IRLayoutValue::Px(value) =>
          output <+ "@ui_view.LayoutValue::Px(\{value})"
        @viewir.IRLayoutValue::Percent(value) =>
          output <+ "@ui_view.LayoutValue::Percent(\{value})"
      }
    Some(Literal(_, span)) =>
      raise @viewir.ViewIRError::Unsupported(
        "layout property requires a typed layout constant", span,
      )
    Some(Binding(path, span)) =>
      output <+
        "@ui_view.LayoutValue::Px(\{fragment => emit_mapped_binding(fragment, emission, path, span, "number")})"
  }
}

///|
fn emit_grid_tracks(
  output : StringBuilder,
  value : EmbeddedValue?,
) -> Unit raise @viewir.ViewIRError {
  match value {
    None => output <+ "[]"
    Some(Literal(@viewir.IRConstant::GridTracks(tracks), _)) => {
      output <+ "["
      for index, track in tracks {
        if index > 0 {
          output <+ ", "
        }
        emit_grid_track(output, track)
      }
      output <+ "]"
    }
    Some(Literal(_, span)) =>
      raise @viewir.ViewIRError::Unsupported(
        "grid tracks require a typed track-list constant", span,
      )
    Some(Binding(_, span)) =>
      raise @viewir.ViewIRError::Unsupported(
        "generated Grid tracks do not support Binding", span,
      )
  }
}

///|
fn emit_grid_track(output : StringBuilder, track : @viewir.IRGridTrack) -> Unit {
  match track {
    Auto => output <+ "@ui_view.GridTrack::Auto"
    Px(value) => output <+ "@ui_view.GridTrack::Px(\{value})"
    Percent(value) => output <+ "@ui_view.GridTrack::Percent(\{value})"
    Fr(value) => output <+ "@ui_view.GridTrack::Fr(\{value})"
    MinContent => output <+ "@ui_view.GridTrack::MinContent"
    MaxContent => output <+ "@ui_view.GridTrack::MaxContent"
    FitContent(value) =>
      output <+
        "@ui_view.GridTrack::FitContent(\{fragment => emit_grid_track(fragment, value)})"
    MinMax(minimum, maximum) =>
      output <+
        "@ui_view.GridTrack::MinMax(\{fragment => emit_grid_track(fragment, minimum)}, \{fragment => emit_grid_track(fragment, maximum)})"
    Repeat(repetition, tracks) => {
      output <+ "@ui_view.GridTrack::Repeat("
      match repetition {
        Count(value) =>
          output <+ "@ui_view.GridTrackRepetition::Count(\{value})"
        AutoFill => output <+ "@ui_view.GridTrackRepetition::AutoFill"
        AutoFit => output <+ "@ui_view.GridTrackRepetition::AutoFit"
      }
      output <+ ", ["
      for index, repeated in tracks {
        if index > 0 {
          output <+ ", "
        }
        emit_grid_track(output, repeated)
      }
      output <+ "])"
    }
  }
}

///|
fn emit_typed_value(
  output : StringBuilder,
  emission : EmbeddedValueEmission,
  value : EmbeddedValue?,
  expected : String,
  fallback : String,
) -> Unit raise @viewir.ViewIRError {
  match value {
    None => output <+ "\{fallback}"
    Some(Literal(constant, span)) => {
      let expression = match expected {
        "string" if constant is @viewir.IRConstant::StringValue(text) =>
          text.escape()
        "bool" if constant is @viewir.IRConstant::BoolValue(value) =>
          value.to_string()
        "number" if constant is @viewir.IRConstant::DoubleValue(value) =>
          value.to_string()
        "int" if constant is @viewir.IRConstant::IntValue(value) =>
          value.to_string()
        _ =>
          raise @viewir.ViewIRError::Unsupported(
            "property requires a typed " + expected + " constant",
            span,
          )
      }
      output <+ "\{expression}"
    }
    Some(Binding(path, span)) =>
      emit_mapped_binding(output, emission, path, span, expected)
  }
}

///|
fn emit_mapped_binding(
  output : StringBuilder,
  emission : EmbeddedValueEmission,
  path : String,
  span : @infoset.XamlSourceSpan,
  expected : String,
) -> Unit {
  let (resolved, resolved_type) = resolved_expression(
    emission.schema,
    emission.scope_type,
    path,
    emission.receiver,
    span,
  )
  match (expected, resolved_type) {
    ("string", Some("String")) | ("string", None) | (_, None) =>
      emit_mapped_raw(output, emission.mappings, resolved, span)
    ("string", _) =>
      output <+
        "\{fragment => emit_mapped_raw(fragment, emission.mappings, resolved, span)}.to_string()"
    ("number", Some("Int")) | ("number", Some("UInt")) =>
      output <+
        "\{fragment => emit_mapped_raw(fragment, emission.mappings, resolved, span)}.to_double()"
    ("number", Some("String")) =>
      output <+
        "generated_rect_component(\{fragment => emit_mapped_raw(fragment, emission.mappings, resolved, span)}, 0, \{path.escape()})"
    _ => emit_mapped_raw(output, emission.mappings, resolved, span)
  }
}

///|
fn resolved_expression(
  projection : EmbeddedProjection,
  _scope_type : String,
  binding_id : String,
  receiver : String,
  _span : @infoset.XamlSourceSpan,
) -> (String, String?) {
  let binding = projection.bindings[binding_id]
  let expression = StringBuilder::new()
  expression <+ "\{receiver}"
  for step in binding.steps {
    expression <+ "."
    expression <+ "\{step.step}"
  }
  (expression.to_string(), Some(binding.result_type))
}

///|
fn kebab_case(value : String) -> String {
  let output = StringBuilder::new()
  for index, ch in value {
    if ch >= 'A' && ch <= 'Z' {
      if index > 0 {
        output.write_char('-')
      }
      output.write_char((ch.to_int() + 32).unsafe_to_char())
    } else if ch == '_' || ch == ' ' {
      output.write_char('-')
    } else {
      output.write_char(ch)
    }
  }
  output.to_string()
}

///|
fn emit_rect_value(
  output : StringBuilder,
  emission : EmbeddedValueEmission,
  value : EmbeddedValue?,
  component : Int,
) -> Unit raise @viewir.ViewIRError {
  match value {
    None => output <+ "0.0"
    Some(Literal(@viewir.IRConstant::RectValue(left, top, right, bottom), _)) =>
      output <+
        "\{match component { 0 => left; 1 => top; 2 => right; _ => bottom }}"
    Some(Literal(_, span)) =>
      raise @viewir.ViewIRError::Unsupported(
        "rect property requires a typed rect constant", span,
      )
    Some(Binding(path, span)) => {
      let (resolved, resolved_type) = resolved_expression(
        emission.schema,
        emission.scope_type,
        path,
        emission.receiver,
        span,
      )
      let value_expression = if resolved_type == Some("String") ||
        resolved_type is None {
        resolved
      } else {
        resolved + ".to_string()"
      }
      output <+
        "generated_rect_component(\{fragment => emit_mapped_raw(fragment, emission.mappings, value_expression, span)}, \{component}, \{path.escape()})"
    }
  }
}

///|
fn emit_mapped_raw(
  output : StringBuilder,
  mappings : Array[EmbeddedSourceMapping],
  expression : String,
  span : @infoset.XamlSourceSpan,
) -> Unit {
  let generated_offset = output.to_string().length()
  output <+ "\{expression}"
  mappings.push({
    original_offset: span.start.offset,
    generated_offset,
    length: expression.length(),
  })
}

///|
fn emit_view_methods(
  output : StringBuilder,
  routes : Array[@viewir.IRActionRoute],
  plan : @viewir.ViewIR,
  analysis : EmbeddedProjection,
) -> Unit {
  let mount_signature = "pub fn " +
    plan.identity.view_name +
    "::mount(entity : @entity.Entity, model : " +
    analysis.model_type.type_name +
    ") -> Unit raise " +
    plan.identity.view_name +
    "Error {"
  if mount_signature.length() <= 81 {
    output <+ "///|\n\{mount_signature}\n"
  } else {
    output <+
      $|///|
      $|pub fn \{plan.identity.view_name}::mount(
      $|  entity : @entity.Entity,
      $|  model : \{analysis.model_type.type_name},
      $|) -> Unit raise \{plan.identity.view_name}Error {
      $|
  }
  output <+
    #|  if !entity.is_alive() {
    #|    raise DeadEntity
    #|  }
    #|  if generated_view_records.contains(entity) {
    #|    raise AlreadyMounted
    #|  }
    #|  let view_model = generated_compute_view_model(model)
    #|  let desired = generated_specs(view_model)
    #|  let host = @ui_view.ViewHost::new()
    #|  host.mount(entity, desired) catch {
    #|    error => raise Host(error)
    #|  }
    #|  generated_view_records[entity] = { model, view_model, specs: desired }
    #|}
    #|
    #|
  let replace_signature = "pub fn " +
    plan.identity.view_name +
    "::replace(entity : @entity.Entity, model : " +
    analysis.model_type.type_name +
    ") -> Unit raise " +
    plan.identity.view_name +
    "Error {"
  if replace_signature.length() <= 81 {
    output <+ "///|\n\{replace_signature}\n"
  } else {
    output <+
      $|///|
      $|pub fn \{plan.identity.view_name}::replace(
      $|  entity : @entity.Entity,
      $|  model : \{analysis.model_type.type_name},
      $|) -> Unit raise \{plan.identity.view_name}Error {
      $|
  }
  output <+
    #|  let record = match generated_view_records.get(entity) {
    #|    Some(value) => value
    #|    None => raise NotMounted
    #|  }
    #|  if !entity.is_alive() {
    #|    generated_view_records.remove(entity)
    #|    raise DeadEntity
    #|  }
    #|  let view_model = generated_compute_view_model(model)
    #|  let desired = generated_specs(view_model)
    #|  let mutations = generated_diff(record.specs, desired)
    #|  if mutations.length() > 0 {
    #|    let host = @ui_view.ViewHost::new()
    #|    host.apply(entity, mutations) catch {
    #|      error => raise Host(error)
    #|    }
    #|  }
    #|  record.model = model
    #|  record.view_model = view_model
    #|  record.specs = desired
    #|}
    #|
    #|
  match analysis.patch {
    Some(patch) => emit_apply_method(output, plan, analysis, patch)
    None => ()
  }
  let event_signature = "fn generated_handle_event(record : GeneratedViewRecord, event : @ui_view.UiEvent) -> " +
    plan.identity.view_name +
    "Action? {"
  if event_signature.length() <= 81 {
    output <+ "///|\n\{event_signature}\n"
  } else {
    output <+
      $|///|
      $|fn generated_handle_event(
      $|  record : GeneratedViewRecord,
      $|  event : @ui_view.UiEvent,
      $|) -> \{plan.identity.view_name}Action? {
      $|
  }
  output <+
    #|  if !generated_contains(record.specs, event.key) {
    #|    return None
    #|  }
    #|
  for route in routes {
    output.write_string(
      "  if event.kind == @ui_view.UiEventKind::" + route.event_kind + " {\n",
    )
    match route.collection_path {
      Some(path) => {
        let collection = analysis.collections[path]
        output.write_string(
          "    for generated_action_item in record.view_model." +
          collection.field_name +
          " {\n",
        )
        output.write_string(
          "      let generated_action_key = generated_action_item." +
          collection.key_field,
        )
        if collection.key_type != "String" {
          output <+ ".to_string()"
        }
        let route_expression = if route.node_template.contains("__SELENE_KEY__") {
          "\"" +
          route.node_template.replace_all(
            old="__SELENE_KEY__",
            new="\\{generated_action_key}",
          ) +
          "\""
        } else {
          route.node_template.escape()
        }
        output <+ "\n      let generated_action_node_key = "
        output <+ "\{route_expression}"
        output.write_string(
          "\n      if event.key == generated_action_node_key {\n",
        )
        let action_line = "        return Some(" +
          plan.identity.view_name +
          "Action::" +
          route.variant_name +
          "(generated_action_key))"
        if action_line.length() <= 81 {
          output.write_string(
            "        return Some(" + plan.identity.view_name + "Action::",
          )
          output <+ "\{route.variant_name}"
          output <+ "(generated_action_key))\n"
        } else {
          output.write_string(
            "        return Some(\n          " +
            plan.identity.view_name +
            "Action::",
          )
          output <+ "\{route.variant_name}"
          output <+ "(generated_action_key),\n        )\n"
        }
        output <+ "      }\n"
        output <+ "    }\n"
      }
      None => {
        output <+ "    let generated_action_node_key = "
        output <+ "\{route.node_template.escape()}"
        output.write_string(
          "\n    if event.key == generated_action_node_key {\n",
        )
        let action_line = "      return Some(" +
          plan.identity.view_name +
          "Action::" +
          route.variant_name +
          ")"
        if action_line.length() <= 81 {
          output.write_string(
            "      return Some(" + plan.identity.view_name + "Action::",
          )
          output <+ "\{route.variant_name}"
          output <+ ")\n"
        } else {
          output.write_string(
            "      return Some(\n        " +
            plan.identity.view_name +
            "Action::",
          )
          output <+ "\{route.variant_name}"
          output <+ ",\n      )\n"
        }
        output <+ "    }\n"
      }
    }
    output <+ "  }\n"
  }
  output <+ "  None\n}\n\n"
  output <+
    $|///|
    $|fn generated_route_events(_world : @ecs.World) -> Unit {
    $|  let dead : Array[@entity.Entity] = []
    $|  for entity, _ in generated_view_records {
    $|    if !entity.is_alive() {
    $|      dead.push(entity)
    $|    }
    $|  }
    $|  for entity in dead {
    $|    generated_view_records.remove(entity)
    $|  }
    $|  for raw in generated_event_reader.read(@ui_view.view_event_bus) {
    $|    match generated_view_records.get(raw.entity) {
    $|      Some(record) =>
    $|        match generated_handle_event(record, raw.event) {
    $|          Some(action) => action_event_bus.send({ entity: raw.entity, action })
    $|          None => ()
    $|        }
    $|      None => ()
    $|    }
    $|  }
    $|}
    $|
    $|///|
    $|pub fn plugin(app : @app.App) -> @app.App {
    $|  app
    $|  .add_plugin(@ui_view.plugin)
    $|  .add_message(action_event_bus)
    $|  .add_system(
    $|    @system.PostUpdate,
    $|    generated_route_events,
    $|    system_name="selene_xaml_\{plan.identity.view_name}_events",
    $|  )
    $|}
    $|
}

///|
fn emit_apply_method(
  output : StringBuilder,
  plan : @viewir.ViewIR,
  analysis : EmbeddedProjection,
  patch : @viewir.IREnum,
) -> Unit {
  match analysis.patch_projection {
    @viewir.IRPatchProjection::Apply(function) => {
      output.write_string(
        "///|\npub fn " +
        plan.identity.view_name +
        "::apply(\n  entity : @entity.Entity,\n  patches : Array[" +
        patch.name +
        "],\n) -> Unit raise " +
        plan.identity.view_name +
        "Error {\n" +
        "  let record = match generated_view_records.get(entity) {\n" +
        "    Some(value) => value\n" +
        "    None => raise NotMounted\n" +
        "  }\n" +
        "  " +
        plan.identity.view_name +
        "::replace(entity, " +
        "@" +
        analysis.model_type.package_alias +
        "." +
        function +
        "(record.model, patches))\n" +
        "}\n\n",
      )
      return
    }
    @viewir.IRPatchProjection::GeneratedCollections => ()
    @viewir.IRPatchProjection::None => return
  }
  let patch_collections : Array[@viewir.IRCollection] = []
  for _, collection in analysis.collections {
    if collection.patch_replace is Some(_) {
      patch_collections.push(collection)
    }
  }
  if patch_collections.length() == 0 {
    return
  }
  patch_collections.sort_by(fn(left, right) {
    left.field_name.compare(right.field_name)
  })
  let apply_signature = "pub fn " +
    plan.identity.view_name +
    "::apply(entity : @entity.Entity, patches : Array[" +
    patch.name +
    "]) -> Unit raise " +
    plan.identity.view_name +
    "Error {"
  if apply_signature.length() <= 81 {
    output <+ "///|\n\{apply_signature}\n"
  } else {
    output.write_string(
      "///|\npub fn " +
      plan.identity.view_name +
      "::apply(\n" +
      "  entity : @entity.Entity,\n  patches : Array[" +
      patch.name +
      "],\n) -> Unit raise " +
      plan.identity.view_name +
      "Error {\n",
    )
  }
  output.write_string(
    "  let record = match generated_view_records.get(entity) {\n" +
    "    Some(value) => value\n" +
    "    None => raise NotMounted\n" +
    "  }\n",
  )
  for collection in patch_collections {
    output.write_string(
      "  let mut " +
      collection.field_name +
      " = record.model." +
      collection.field_name +
      ".copy()\n",
    )
  }
  output <+ "  for patch in patches {\n    match patch {\n"
  for collection in patch_collections {
    let field = collection.field_name
    let key = collection.key_field
    output.write_string(
      "      " +
      patch.name +
      "::" +
      collection.patch_replace.unwrap() +
      "(values) => " +
      field +
      " = values.copy()\n",
    )
    output.write_string(
      "      " +
      patch.name +
      "::" +
      collection.patch_upsert.unwrap() +
      "(value) => {\n",
    )
    output.write_string(
      "        let mut replaced = false\n        for index, current in " +
      field +
      " {\n",
    )
    output.write_string(
      "          if current." +
      key +
      " == value." +
      key +
      " {\n" +
      "            " +
      field +
      "[index] = value\n" +
      "            replaced = true\n" +
      "            break\n" +
      "          }\n",
    )
    output.write_string(
      "        }\n" +
      "        if !replaced {\n" +
      "          " +
      field +
      ".push(value)\n" +
      "        }\n" +
      "      }\n",
    )
    output.write_string(
      "      " +
      patch.name +
      "::" +
      collection.patch_remove.unwrap() +
      "(key) => {\n",
    )
    output.write_string(
      "        let mut removed = false\n" +
      "        for value in " +
      field +
      " {\n" +
      "          if value." +
      collection.key_field +
      " == key {\n" +
      "            removed = true\n" +
      "            break\n" +
      "          }\n" +
      "        }\n",
    )
    output.write_string(
      "        if !removed {\n" +
      "          raise InvalidPatch(\n" +
      "            \"patch remove key does not exist: \" + key.to_string(),\n" +
      "          )\n" +
      "        }\n" +
      "        " +
      field +
      " = " +
      field +
      ".filter(value => value." +
      collection.key_field +
      " != key)\n" +
      "      }\n",
    )
    output.write_string(
      "      " +
      patch.name +
      "::" +
      collection.patch_move.unwrap() +
      "((key, destination)) => {\n",
    )
    output.write_string(
      "        let retained : Array[" +
      collection.item_type +
      "] = []\n        let mut moved : " +
      collection.item_type +
      "? = None\n",
    )
    output.write_string(
      "        for value in " +
      field +
      " {\n" +
      "          if value." +
      collection.key_field +
      " == key {\n" +
      "            moved = Some(value)\n" +
      "          } else {\n" +
      "            retained.push(value)\n" +
      "          }\n" +
      "        }\n",
    )
    output.write_string(
      "        guard moved is Some(value) else {\n" +
      "          raise InvalidPatch(\n" +
      "            \"patch move key does not exist: \" + key.to_string(),\n" +
      "          )\n" +
      "        }\n",
    )
    output.write_string(
      "        let destination = destination.reinterpret_as_int()\n",
    )
    output.write_string(
      "        if destination < 0 || destination > retained.length() {\n" +
      "          raise InvalidPatch(\"patch move destination is out of range\")\n" +
      "        }\n",
    )
    output.write_string(
      "        retained.insert(destination, value)\n        " +
      field +
      " = retained\n      }\n",
    )
  }
  let recognized : Map[String, Bool] = Map([])
  for collection in patch_collections {
    recognized[collection.patch_replace.unwrap()] = true
    recognized[collection.patch_upsert.unwrap()] = true
    recognized[collection.patch_remove.unwrap()] = true
    recognized[collection.patch_move.unwrap()] = true
  }
  if patch.variants.any(variant => !recognized.contains(variant.name)) {
    output.write_string(
      "      _ => raise InvalidPatch(\"unsupported patch variant\")\n",
    )
  }
  output <+ "    }\n  }\n"
  output.write_string(
    "  " + plan.identity.view_name + "::replace(entity, { ..record.model",
  )
  for collection in patch_collections {
    output <+ ", \{collection.field_name}"
  }
  output <+ ", })\n}\n\n"
}
