///|
priv struct ComponentSourceMapping {
  original_offset : Int
  generated_offset : Int
  length : Int
}

///|
priv struct EmittedView {
  source : String
  mappings : Array[ComponentSourceMapping]
}

///|
priv enum ComponentValue {
  Literal(@viewir.IRConstant, @infoset.XamlSourceSpan)
  Binding(String, @infoset.XamlSourceSpan)
}

///|
priv struct ComponentProperty {
  name : String
  value : ComponentValue
}

///|
priv enum ComponentNode {
  Element(
    String,
    String,
    String?,
    Array[ComponentProperty],
    Array[ComponentNode],
    @infoset.XamlSourceSpan
  )
  Conditional(
    String,
    @infoset.XamlSourceSpan,
    Array[ComponentNode],
    Array[ComponentNode]
  )
  KeyedItems(
    String,
    @infoset.XamlSourceSpan,
    String,
    @infoset.XamlSourceSpan,
    @viewir.IRTypeRef?,
    Array[ComponentNode]
  )
}

///|
priv struct ComponentProjection {
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
fn project_component_ir(
  ir : @viewir.ViewIR,
) -> (ComponentNode, ComponentProjection) {
  let bindings : Map[String, @viewir.IRBinding] = Map([])
  for binding in ir.bindings {
    bindings[binding.id] = binding
  }
  let pending : Array[(@viewir.IRNode, String)] = [(ir.root, "root")]
  let projected : Map[String, ComponentNode] = Map([])
  let child_links : Map[String, Array[String]] = Map([])
  while pending.length() > 0 {
    let (node, path) = pending.pop().unwrap()
    match node {
      @viewir.IRNode::Element(kind, key, name, properties, children, span) => {
        let values : Array[ComponentProperty] = []
        for property in properties {
          let value = match property.value {
            @viewir.IRValue::Binding(id, value_span) =>
              ComponentValue::Binding(id, value_span)
            @viewir.IRValue::Constant(constant, value_span) =>
              ComponentValue::Literal(constant, value_span)
          }
          values.push({ name: property.name, value })
        }
        let links : Array[String] = []
        for index, child in children {
          let child_path = path + "/" + index.to_string()
          links.push(child_path)
          pending.push((child, child_path))
        }
        projected[path] = ComponentNode::Element(
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
        projected[path] = ComponentNode::Conditional(binding, span, [], [])
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
        projected[path] = ComponentNode::KeyedItems(
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
      ComponentNode::Element(kind, key, name, values, _, span) =>
        projected[path] = ComponentNode::Element(
          kind,
          key,
          name,
          values,
          child_links.get(path).unwrap_or([]).map(child => projected[child]),
          span,
        )
      ComponentNode::Conditional(binding, span, _, _) =>
        projected[path] = ComponentNode::Conditional(
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
      ComponentNode::KeyedItems(
        binding,
        source_span,
        key_path,
        key_span,
        item_type,
        _
      ) =>
        projected[path] = ComponentNode::KeyedItems(
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
fn emit_component_source(
  plan : @viewir.ViewIR,
  target : ComponentGuestTarget,
  generated_header : String,
) -> EmittedView raise @viewir.ViewIRError {
  let (root, analysis) = project_component_ir(plan)
  let schema = analysis
  let output = StringBuilder::new()
  let mappings : Array[ComponentSourceMapping] = []
  let routes = plan.action_routes.copy()
  output <+ "\{generated_header}"
  output <+
    $|///|
    $|pub(all) suberror \{plan.identity.view_name}Error {
    $|  DuplicateKey(String, String)
    $|  InvalidPatch(String)
    $|  Host(String)
    $|} derive(Eq, Debug)
    $|
    $|///|
    $|pub impl Show for \{plan.identity.view_name}Error with fn output(self, logger) {
    $|  match self {
    $|    DuplicateKey(path, key) =>
    $|      logger.write_string("duplicate or empty key in " + path + ": " + key)
    $|    InvalidPatch(message) => logger.write_string(message)
    $|    Host(message) => logger.write_string(message)
    $|  }
    $|}
    $|
    $|///|
    $|fn generated_compute_view_model(model : \{analysis.model_type.type_name}) -> \{analysis.view_model_type.type_name} {
    $|  
  match analysis.view_model_projection {
    @viewir.IRViewModelProjection::Identity => output <+ "model\n"
    @viewir.IRViewModelProjection::Compute(function) =>
      output <+ "\{function}(model)\n"
  }
  output <+ "}\n\n"
  emit_view_runtime(output, plan, target, analysis)
  let specs_signature = "fn generated_specs(state : " +
    analysis.state.name +
    ") -> Array[@tree.NodeSpec] raise " +
    plan.identity.view_name +
    "Error {"
  if specs_signature.length() <= 81 {
    output <+
      "///|\n#warnings(\"-unused_value-unused_error_type\")\n\{specs_signature}\n"
  } else {
    output <+
      $|///|
      $|#warnings("-unused_value-unused_error_type")
      $|fn generated_specs(
      $|  state : \{analysis.state.name},
      $|) -> Array[@tree.NodeSpec] raise \{plan.identity.view_name}Error {
      $|
  }
  output <+ "  let nodes : Array[@tree.NodeSpec] = []\n"
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
  emit_view_methods(output, routes, plan, target, analysis)
  { source: output.to_string(), mappings }
}

///|
fn emit_view_runtime(
  output : StringBuilder,
  plan : @viewir.ViewIR,
  target : ComponentGuestTarget,
  analysis : ComponentProjection,
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
    $|fn generated_contains(specs : Array[@tree.NodeSpec], key : String) -> Bool {
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
    $|  specs : Array[@tree.NodeSpec],
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
    $|  previous : Array[@tree.NodeSpec],
    $|  desired : Array[@tree.NodeSpec],
    $|) -> Array[@tree.TreeMutation] {
    $|  if previous == desired {
    $|    return []
    $|  }
    $|  let previous_by_key : Map[String, @tree.NodeSpec] = Map([])
    $|  let desired_by_key : Map[String, @tree.NodeSpec] = Map([])
    $|  for spec in previous {
    $|    previous_by_key[spec.key] = spec
    $|  }
    $|  for spec in desired {
    $|    desired_by_key[spec.key] = spec
    $|  }
    $|  let mutations : Array[@tree.TreeMutation] = []
    $|  for spec in previous {
    $|    if !desired_by_key.contains(spec.key) {
    $|      let removed_root = match spec.parent {
    $|        Some(parent) => desired_by_key.contains(parent)
    $|        None => true
    $|      }
    $|      if removed_root {
    $|        mutations.push(@tree.TreeMutation::Remove(spec.key))
    $|      }
    $|    }
    $|  }
    $|  for spec in desired {
    $|    match previous_by_key.get(spec.key) {
    $|      None => {
    $|        mutations.push(@tree.TreeMutation::Mount(spec))
    $|        match spec.parent {
    $|          Some(parent) =>
    $|            mutations.push(
    $|              @tree.TreeMutation::Move({
    $|                key: spec.key,
    $|                parent,
    $|                index: generated_parent_index(desired, spec.parent, spec.key).reinterpret_as_uint(),
    $|              }),
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
    $|              @tree.TreeMutation::Move({
    $|                key: spec.key,
    $|                parent,
    $|                index: generated_parent_index(desired, spec.parent, spec.key).reinterpret_as_uint(),
    $|              }),
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
    $|          mutations.push(@tree.TreeMutation::Update(spec))
    $|        } else {
    $|          if old.text != spec.text {
    $|            mutations.push(@tree.TreeMutation::SetText({ key: spec.key, value: spec.text }))
    $|          }
    $|          if old.source != spec.source {
    $|            mutations.push(@tree.TreeMutation::SetSource({ key: spec.key, value: spec.source }))
    $|          }
    $|          if old.style.background != spec.style.background {
    $|            mutations.push(@tree.TreeMutation::SetBackground({ key: spec.key, value: spec.style.background }))
    $|          }
    $|          if old.active != spec.active {
    $|            mutations.push(@tree.TreeMutation::SetActive({ key: spec.key, value: spec.active }))
    $|          }
    $|          if old.enabled != spec.enabled {
    $|            mutations.push(@tree.TreeMutation::SetEnabled({ key: spec.key, value: spec.enabled }))
    $|          }
    $|          if old.style.top != spec.style.top {
    $|            mutations.push(@tree.TreeMutation::SetTop({ key: spec.key, value: spec.style.top }))
    $|          }
    $|        }
    $|      }
    $|    }
    $|  }
    $|  mutations
    $|}
    $|
    $|///|
    $|#warnings("-unused_field")
    $|priv struct GeneratedGuestRecord {
    $|  model : \{analysis.model_type.type_name}
    $|  view_model : \{analysis.view_model_type.type_name}
    $|  specs : Array[@tree.NodeSpec]
    $|}
    $|
    $|///|
    $|let generated_guest_records : Map[UInt, GeneratedGuestRecord] = Map([])
    $|
    $|
  ignore(target)
}

///|
fn emit_plan_specs(
  output : StringBuilder,
  mappings : Array[ComponentSourceMapping],
  routes : Array[@viewir.IRActionRoute],
  node : ComponentNode,
  schema : ComponentProjection,
  analysis : ComponentProjection,
  receiver : String,
  scope_type : String,
  parent_template : String?,
  item_prefix_template : String?,
  collection_path : String?,
  indent : Int,
  serial : Array[Int],
) -> Unit raise @viewir.ViewIRError {
  let padding = "  ".repeat(indent)
  match node {
    Element(kind, key, _, properties, children, _) => {
      let property_map : Map[String, ComponentValue] = Map([])
      for property in properties {
        if ![
            "Text", "Source", "Active", "Enabled", "Focusable", "Position", "Left",
            "Top", "Width", "Height", "Margin", "Padding", "Background", "BorderColor",
            "Border", "Radius", "Color", "FontFamily", "FontSize", "Bold", "Align",
            "Wrap", "ZIndex", "Fit", "Direction", "Grow", "Shrink", "Basis", "RowGap",
            "Gap", "ColumnGap", "HorizontalScroll", "VerticalScroll", "ScrollbarWidth",
            "OutlineColor", "OutlineWidth", "OutlineOffset", "OnClick", "OnFocus",
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
      output <+ "\{padding}  kind: @tree.NodeKind::\{wit_variant(kind)},\n"
      output <+ "\{padding}  text: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Text"),
        "string",
        "\"\"",
      )
      output <+ ",\n\{padding}  source: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Source"),
        "string",
        "\"\"",
      )
      output <+ ",\n\{padding}  active: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Active"),
        "bool",
        "true",
      )
      output <+ ",\n\{padding}  enabled: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Enabled"),
        "bool",
        "true",
      )
      output <+ ",\n\{padding}  focusable: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Focusable"),
        "bool",
        if kind == "Button" {
          "true"
        } else {
          "false"
        },
      )
      output <+ ",\n\{padding}  style: {\n"
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
        output <+ "\{padding}    \{field}: "
        emit_typed_value(
          output,
          mappings,
          schema,
          scope_type,
          receiver,
          property_map.get(property),
          "number",
          "0.0",
        )
        output <+ ",\n"
      }
      for entry in [("Width", "width"), ("Height", "height")] {
        let (property, field) = entry
        output <+ "\{padding}    \{field}: "
        emit_layout_value(
          output,
          mappings,
          schema,
          scope_type,
          receiver,
          property_map.get(property),
        )
        output <+ ",\n"
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
        output <+ "\{padding}    \{field}: "
        emit_rect_value(
          output,
          mappings,
          schema,
          scope_type,
          receiver,
          property_map.get(property),
          component,
        )
        output <+ ",\n"
      }
      for
        entry in [("Background", "background"), ("BorderColor", "border_color")] {
        let (property, field) = entry
        output <+ "\{padding}    \{field}: "
        emit_typed_value(
          output,
          mappings,
          schema,
          scope_type,
          receiver,
          property_map.get(property),
          "string",
          "\"\"",
        )
        output <+ ",\n"
      }
      output <+ "\{padding}    border: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Border"),
        "number",
        "0.0",
      )
      output <+ ",\n\{padding}    radius: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Radius"),
        "number",
        "0.0",
      )
      output <+ ",\n"
      output <+ "\{padding}    outline_color: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("OutlineColor"),
        "string",
        "\"\"",
      )
      output <+ ",\n\{padding}    outline_width: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("OutlineWidth"),
        "number",
        "0.0",
      )
      output <+ ",\n\{padding}    outline_offset: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("OutlineOffset"),
        "number",
        "0.0",
      )
      output <+ ",\n"
      for entry in [("Color", "color"), ("FontFamily", "font_family")] {
        let (property, field) = entry
        output <+ "\{padding}    \{field}: "
        emit_typed_value(
          output,
          mappings,
          schema,
          scope_type,
          receiver,
          property_map.get(property),
          "string",
          "\"\"",
        )
        output <+ ",\n"
      }
      output <+ "\{padding}    font_size: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("FontSize"),
        "number",
        "0.0",
      )
      output <+ ",\n\{padding}    bold: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Bold"),
        "bool",
        "false",
      )
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
      output <+
        ",\n\{padding}    align: @tree.TextAlign::\{wit_variant(align)},\n"
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
      output <+ "\{padding}    z_index: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("ZIndex"),
        "int",
        "0",
      )
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
      output <+ ",\n\{padding}    fit: @tree.ImageFit::\{wit_variant(fit)},\n"
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
        "\{padding}    direction: @tree.FlexDirection::\{wit_variant(direction)},\n"
      output <+ "\{padding}    flex_basis: "
      emit_layout_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Basis"),
      )
      output <+ ",\n\{padding}    flex_grow: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Grow"),
        "number",
        "0.0",
      )
      output <+ ",\n\{padding}    flex_shrink: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("Shrink"),
        "number",
        "1.0",
      )
      output <+ ",\n"
      let row_gap = match property_map.get("RowGap") {
        Some(value) => Some(value)
        None => property_map.get("Gap")
      }
      output <+ "\{padding}    row_gap: "
      emit_typed_value(
        output, mappings, schema, scope_type, receiver, row_gap, "number", "0.0",
      )
      let column_gap = match property_map.get("ColumnGap") {
        Some(value) => Some(value)
        None => property_map.get("Gap")
      }
      output <+ ",\n\{padding}    column_gap: "
      emit_typed_value(
        output, mappings, schema, scope_type, receiver, column_gap, "number", "0.0",
      )
      output <+ ",\n\{padding}    horizontal_scroll: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("HorizontalScroll"),
        "bool",
        "false",
      )
      output <+ ",\n\{padding}    vertical_scroll: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("VerticalScroll"),
        "bool",
        "false",
      )
      output <+ ",\n\{padding}    scrollbar_width: "
      emit_typed_value(
        output,
        mappings,
        schema,
        scope_type,
        receiver,
        property_map.get("ScrollbarWidth"),
        "number",
        "0.0",
      )
      output <+ ",\n\{padding}  },\n"
      emit_component_visual_state_groups(
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
      output <+ "\{padding}if "
      emit_mapped_binding(
        output, mappings, schema, scope_type, receiver, path, span, "bool",
      )
      output <+ " {\n"
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
fn emit_component_visual_state_groups(
  output : StringBuilder,
  mappings : Array[ComponentSourceMapping],
  analysis : ComponentProjection,
  owner_node : String,
  receiver : String,
  scope_type : String,
  item_serial : Int,
  indent : Int,
) -> Unit raise @viewir.ViewIRError {
  let padding = "  ".repeat(indent)
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
          output <+ "if "
          emit_mapped_binding(
            output, mappings, analysis, scope_type, receiver, id, span, "bool",
          )
          output <+ " { \"Selected\" } else { \"Normal\" }"
        } else {
          emit_mapped_binding(
            output, mappings, analysis, scope_type, receiver, id, span, "string",
          )
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
              "String" => {
                output <+ "@tree.VisualStateValue::StringValue("
                emit_mapped_binding(
                  output, mappings, analysis, scope_type, receiver, id, span, "string",
                )
                output <+ ")"
              }
              "Bool" => {
                output <+ "@tree.VisualStateValue::BoolValue("
                emit_mapped_binding(
                  output, mappings, analysis, scope_type, receiver, id, span, "bool",
                )
                output <+ ")"
              }
              "LayoutValue" => {
                output <+
                  "@tree.VisualStateValue::LayoutValueValue(@tree.LayoutValue::Px("
                emit_mapped_binding(
                  output, mappings, analysis, scope_type, receiver, id, span, "number",
                )
                output <+ "))"
              }
              "Int" => {
                output <+ "@tree.VisualStateValue::IntValue("
                emit_mapped_binding(
                  output, mappings, analysis, scope_type, receiver, id, span, "int",
                )
                output <+ ")"
              }
              _ => {
                output <+ "@tree.VisualStateValue::DoubleValue("
                emit_mapped_binding(
                  output, mappings, analysis, scope_type, receiver, id, span, "number",
                )
                output <+ ")"
              }
            }
          }
          @viewir.IRValue::Constant(constant, _) =>
            match constant {
              @viewir.IRConstant::StringValue(value) =>
                output <+
                  "@tree.VisualStateValue::StringValue(\{value.escape()})"
              @viewir.IRConstant::BoolValue(value) =>
                output <+ "@tree.VisualStateValue::BoolValue(\{value})"
              @viewir.IRConstant::DoubleValue(value) =>
                output <+ "@tree.VisualStateValue::DoubleValue(\{value})"
              @viewir.IRConstant::IntValue(value) =>
                output <+ "@tree.VisualStateValue::IntValue(\{value})"
              @viewir.IRConstant::LayoutValue(value) => {
                output <+ "@tree.VisualStateValue::LayoutValueValue("
                match value {
                  @viewir.IRLayoutValue::Auto =>
                    output <+ "@tree.LayoutValue::Auto"
                  @viewir.IRLayoutValue::Px(number) =>
                    output <+ "@tree.LayoutValue::Px(\{number})"
                  @viewir.IRLayoutValue::Percent(number) =>
                    output <+ "@tree.LayoutValue::Percent(\{number})"
                }
                output <+ ")"
              }
              @viewir.IRConstant::EnumValue(value) =>
                output <+
                  "@tree.VisualStateValue::StringValue(\{value.escape()})"
              @viewir.IRConstant::RectValue(_, _, _, _) =>
                raise @viewir.ViewIRError::Unsupported(
                  "VisualState does not support Rect setter values",
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
  mappings : Array[ComponentSourceMapping],
  schema : ComponentProjection,
  scope_type : String,
  receiver : String,
  value : ComponentValue?,
) -> Unit raise @viewir.ViewIRError {
  match value {
    None => output <+ "@tree.LayoutValue::Auto"
    Some(Literal(@viewir.IRConstant::LayoutValue(layout), _)) =>
      match layout {
        @viewir.IRLayoutValue::Auto => output <+ "@tree.LayoutValue::Auto"
        @viewir.IRLayoutValue::Px(value) =>
          output <+ "@tree.LayoutValue::Px(\{value})"
        @viewir.IRLayoutValue::Percent(value) =>
          output <+ "@tree.LayoutValue::Percent(\{value})"
      }
    Some(Literal(_, span)) =>
      raise @viewir.ViewIRError::Unsupported(
        "layout property requires a typed layout constant", span,
      )
    Some(Binding(path, span)) => {
      output <+ "@tree.LayoutValue::Px("
      emit_mapped_binding(
        output, mappings, schema, scope_type, receiver, path, span, "number",
      )
      output <+ ")"
    }
  }
}

///|
fn emit_typed_value(
  output : StringBuilder,
  mappings : Array[ComponentSourceMapping],
  schema : ComponentProjection,
  scope_type : String,
  receiver : String,
  value : ComponentValue?,
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
      emit_mapped_binding(
        output, mappings, schema, scope_type, receiver, path, span, expected,
      )
  }
}

///|
fn emit_mapped_binding(
  output : StringBuilder,
  mappings : Array[ComponentSourceMapping],
  schema : ComponentProjection,
  scope_type : String,
  receiver : String,
  path : String,
  span : @infoset.XamlSourceSpan,
  expected : String,
) -> Unit {
  let (resolved, resolved_type) = resolved_expression(
    schema, scope_type, path, receiver, span,
  )
  match (expected, resolved_type) {
    ("string", Some("String")) | ("string", None) | (_, None) =>
      emit_mapped_raw(output, mappings, resolved, span)
    ("string", _) => {
      emit_mapped_raw(output, mappings, resolved, span)
      output <+ ".to_string()"
    }
    ("number", Some("Int")) | ("number", Some("UInt")) => {
      emit_mapped_raw(output, mappings, resolved, span)
      output <+ ".to_double()"
    }
    ("number", Some("String")) => {
      output <+ "generated_rect_component("
      emit_mapped_raw(output, mappings, resolved, span)
      output <+ ", 0, \{path.escape()})"
    }
    _ => emit_mapped_raw(output, mappings, resolved, span)
  }
}

///|
fn resolved_expression(
  projection : ComponentProjection,
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
fn wit_variant(value : String) -> String {
  let output = StringBuilder::new()
  for index, ch in value {
    if ch >= 'A' && ch <= 'Z' {
      if index > 0 {
        output.write_char('_')
      }
      output.write_char(ch)
    } else if ch == '-' || ch == ' ' {
      output.write_char('_')
    } else if ch >= 'a' && ch <= 'z' {
      output.write_char((ch.to_int() - 32).unsafe_to_char())
    } else {
      output.write_char(ch)
    }
  }
  output.to_string()
}

///|
fn emit_rect_value(
  output : StringBuilder,
  mappings : Array[ComponentSourceMapping],
  schema : ComponentProjection,
  scope_type : String,
  receiver : String,
  value : ComponentValue?,
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
        schema, scope_type, path, receiver, span,
      )
      let value_expression = if resolved_type == Some("String") ||
        resolved_type is None {
        resolved
      } else {
        resolved + ".to_string()"
      }
      output <+ "generated_rect_component("
      emit_mapped_raw(output, mappings, value_expression, span)
      output <+ ", \{component}, \{path.escape()})"
    }
  }
}

///|
fn emit_mapped_raw(
  output : StringBuilder,
  mappings : Array[ComponentSourceMapping],
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
  target : ComponentGuestTarget,
  analysis : ComponentProjection,
) -> Unit {
  let model = analysis.model_type.type_name
  output <+
    $|///|
    $|pub fn mount(entity : UInt, model : \{model}) -> Unit {
    $|  if generated_guest_records.contains(entity) {
    $|    abort("Selene Entity is already mounted")
    $|  }
    $|  let view_model = generated_compute_view_model(model)
    $|  let desired = generated_specs(view_model) catch {
    $|    error => abort(error.to_string())
    $|  }
    $|  let initial = desired.map(spec => @tree.TreeMutation::Mount(spec))
    $|  match @tree.apply(entity, initial) {
    $|    Ok(_) => ()
    $|    Err(error) => abort("Selene UI Host rejected mount: " + error.message)
    $|  }
    $|  generated_guest_records[entity] = { model, view_model, specs: desired }
    $|}
    $|
    $|///|
    $|pub fn replace(entity : UInt, model : \{model}) -> Unit {
    $|  let record = generated_guest_records[entity]
    $|  let view_model = generated_compute_view_model(model)
    $|  let desired = generated_specs(view_model) catch {
    $|    error => abort(error.to_string())
    $|  }
    $|  let mutations = generated_diff(record.specs, desired)
    $|  if mutations.length() > 0 {
    $|    match @tree.apply(entity, mutations) {
    $|      Ok(_) => ()
    $|      Err(error) => abort("Selene UI Host rejected replace: " + error.message)
    $|    }
    $|  }
    $|  generated_guest_records[entity] = { model, view_model, specs: desired }
    $|}
    $|
    $|
  match analysis.patch {
    Some(patch) => emit_apply_method(output, plan, target, analysis, patch)
    None => ()
  }
  let event_signature = "pub fn handle_event(entity : UInt, event : \{target.event_type}) -> \{target.action_type}? {"
  if event_signature.length() <= 81 {
    output <+ "///|\n\{event_signature}\n"
  } else {
    output <+
      $|///|
      $|pub fn handle_event(
      $|  entity : UInt,
      $|  event : \{target.event_type},
      $|) -> \{target.action_type}? {
  }
  output <+
    $|  let record = generated_guest_records[entity]
    $|  match event {
    $|
  let event_kinds : Map[String, Bool] = Map([])
  for route in routes {
    event_kinds[route.event_kind] = true
  }
  let kinds = event_kinds.keys().collect()
  kinds.sort()
  for event_kind in kinds {
    output <+
      $|    \{event_kind}(event_key) => {
      $|      if !generated_contains(record.specs, event_key) {
      $|        return None
      $|      }
      $|
    for route in routes {
      if route.event_kind != event_kind {
        continue
      }
      match route.collection_path {
        Some(path) => {
          let collection = analysis.collections[path]
          output.write_string(
            "      for generated_action_item in record.view_model." +
            collection.field_name +
            " {\n" +
            "        let generated_action_key = generated_action_item." +
            collection.key_field,
          )
          if collection.key_type != "String" {
            output <+ ".to_string()"
          }
          let route_expression = if route.node_template.contains(
              "__SELENE_KEY__",
            ) {
            "\"" +
            route.node_template.replace_all(
              old="__SELENE_KEY__",
              new="\\{generated_action_key}",
            ) +
            "\""
          } else {
            route.node_template.escape()
          }
          output <+ "\n        let generated_action_node_key = "
          output <+ "\{route_expression}"
          output.write_string(
            "\n        if event_key == generated_action_node_key {\n" +
            "          return Some(" +
            target.action_type +
            "::",
          )
          output <+ "\{route.variant_name}"
          output <+ "(generated_action_key))\n        }\n      }\n"
        }
        None => {
          output <+ "      if event_key == "
          output <+ "\{route.node_template.escape()}"
          output.write_string(
            " {\n        return Some(" + target.action_type + "::",
          )
          output <+ "\{route.variant_name}"
          output <+ ")\n      }\n"
        }
      }
    }
    output <+ "      None\n    }\n"
  }
  let exhaustive = match plan.contract.enums.get(target.event_type) {
    Some(event) =>
      event.variants.all(variant => event_kinds.contains(variant.name))
    None => false
  }
  if !exhaustive {
    output <+ "    _ => None\n"
  }
  output <+ "  }\n}\n\n"
  output <+
    $|///|
    $|pub fn update() -> Unit {
    $|  // Generated views currently advance only through replace/apply calls.
    $|}
    $|
    $|///|
    $|pub fn unmount(entity : UInt) -> Unit {
    $|  generated_guest_records.remove(entity)
    $|}
    $|
}

///|
fn emit_apply_method(
  output : StringBuilder,
  _plan : @viewir.ViewIR,
  _target : ComponentGuestTarget,
  analysis : ComponentProjection,
  patch : @viewir.IREnum,
) -> Unit {
  match analysis.patch_projection {
    @viewir.IRPatchProjection::Apply(function) => {
      output.write_string(
        "///|\npub fn apply(\n  entity : UInt,\n  patches : Array[" +
        patch.name +
        "],\n) -> Unit {\n" +
        "  let record = generated_guest_records[entity]\n" +
        "  replace(entity, " +
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
  let apply_signature = "pub fn apply(entity : UInt, patches : Array[" +
    patch.name +
    "]) -> Unit {"
  if apply_signature.length() <= 81 {
    output <+ "///|\n\{apply_signature}\n"
  } else {
    output.write_string(
      "///|\npub fn apply(\n" +
      "  entity : UInt,\n  patches : Array[" +
      patch.name +
      "],\n) -> Unit {\n",
    )
  }
  output.write_string("  let record = generated_guest_records[entity]\n")
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
      "          abort(\n" +
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
      "          abort(\n" +
      "            \"patch move key does not exist: \" + key.to_string(),\n" +
      "          )\n" +
      "        }\n",
    )
    output.write_string(
      "        let destination = destination.reinterpret_as_int()\n",
    )
    output.write_string(
      "        if destination < 0 || destination > retained.length() {\n" +
      "          abort(\"patch move destination is out of range\")\n" +
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
    output <+ "      _ => abort(\"unsupported patch variant\")\n"
  }
  output <+ "    }\n  }\n"
  output <+ "  replace(entity, { ..record.model"
  for collection in patch_collections {
    output <+ ", \{collection.field_name}"
  }
  output <+ ", })\n}\n\n"
}
