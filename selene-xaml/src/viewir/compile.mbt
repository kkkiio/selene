///|
priv struct BindingDraft {
  path : String
  scope_id : String
  scope_type : String
  targets : Array[IRBindingTarget]
  span : @infoset.XamlSourceSpan
}

///|
priv struct NodeContext {
  node : SyntaxNode
  scope_id : String
  scope_type : String
  collection_path : String?
  parent_template : String?
  item_prefix_template : String?
}

///|
pub fn compile(
  source_uri : String,
  source : String,
  contract_source : String,
) -> ViewIR raise ViewIRError {
  let syntax = lower_syntax(source_uri, source)
  let parsed = parse_contract(contract_source)
  if syntax.data_type.package_path != parsed.package_path {
    raise InvalidContract(
      "ui:DataType package " +
      syntax.data_type.package_path +
      " does not match .mbti package " +
      parsed.package_path,
    )
  }
  let view_model = match parsed.structs.get(syntax.data_type.type_name) {
    Some(value) => value
    None =>
      raise InvalidContract(
        "root ui:DataType is not a public struct in .mbti: " +
        syntax.data_type.type_name,
      )
  }
  let contract_alias = parsed.package_path
    .split("/")
    .last()
    .map_or(syntax.data_type.package_alias, value => value.to_owned())
  let resolved_view_model_type : IRTypeRef = {
    ..syntax.data_type,
    package_alias: contract_alias,
    package_path: parsed.package_path,
  }
  let (model_type, projection) = match
    parsed.functions.get("compute_view_model") {
    Some(function) => {
      if function.parameters.length() != 1 {
        raise InvalidContract(
          "compute_view_model must accept exactly one Model parameter",
        )
      }
      let result_name = base_type_name(function.return_type)
      if result_name != view_model.name {
        raise InvalidContract(
          "compute_view_model must return root ui:DataType " + view_model.name,
        )
      }
      let model_name = base_type_name(function.parameters[0])
      if !parsed.structs.contains(model_name) {
        raise InvalidContract(
          "compute_view_model Model is not a public struct in .mbti: " +
          model_name,
        )
      }
      (
        {
          package_alias: contract_alias,
          package_path: parsed.package_path,
          type_name: model_name,
          span: syntax.data_type.span,
        },
        IRViewModelProjection::Compute(function.name),
      )
    }
    None => (resolved_view_model_type, IRViewModelProjection::Identity)
  }
  let collections : Map[String, IRCollection] = Map([])
  let binding_drafts : Map[String, BindingDraft] = Map([])
  let action_routes : Array[IRActionRoute] = []
  let data_scopes : Array[IRDataScope] = [
    {
      id: "root",
      parent: None,
      value_type: syntax.data_type,
      kind: IRDataScopeKind::RootViewModel,
      span: syntax.identity.span,
    },
  ]
  let capabilities : Map[String, IRCapability] = Map([
    ("tree", IRCapability::TreeMutation),
  ])
  let node_scopes : Map[String, (String, String)] = Map([])
  let pending : Array[NodeContext] = [
    {
      node: syntax.root,
      scope_id: "root",
      scope_type: view_model.name,
      collection_path: None,
      parent_template: None,
      item_prefix_template: None,
    },
  ]
  while pending.length() > 0 {
    let context = pending.pop().unwrap()
    match context.node {
      SyntaxNode::Element(_, key, _, properties, children, _) => {
        let node_template = match context.item_prefix_template {
          Some(prefix) => prefix + "/" + key
          None => key
        }
        node_scopes[node_template] = (context.scope_id, context.scope_type)
        for property in properties {
          if property.name == "OnClick" || property.name == "OnFocus" {
            match property.value {
              SyntaxValue::Literal(action, span) => {
                if action.trim() == "" {
                  raise Unsupported("action name cannot be empty", span)
                }
                let event_kind = if property.name == "OnClick" {
                  "Click"
                } else {
                  "Focus"
                }
                action_routes.push({
                  id: "action:" + node_template + ":" + event_kind,
                  authored_name: action,
                  variant_name: pascal_case(action),
                  event_kind,
                  source_scope: context.scope_id,
                  collection_path: context.collection_path,
                  node_template,
                  span,
                })
                capabilities["actions"] = IRCapability::ActionRouting
              }
              SyntaxValue::Binding(_, span) =>
                raise Unsupported("actions must be literal names", span)
            }
            continue
          }
          match property.value {
            SyntaxValue::Binding(path, span) => {
              if ["Position", "Align", "Wrap", "Fit", "Direction"].contains(
                  property.name,
                ) {
                raise Unsupported(
                  "generated property does not support Binding: " +
                  property.name,
                  span,
                )
              }
              let target : IRBindingTarget = {
                node: node_template,
                property: property.name,
                target_type: property_target_type(property.name, span),
                span,
              }
              let draft_key = context.scope_id + "\u{1f}" + path
              match binding_drafts.get(draft_key) {
                Some(previous) => previous.targets.push(target)
                None =>
                  binding_drafts[draft_key] = {
                    path,
                    scope_id: context.scope_id,
                    scope_type: context.scope_type,
                    targets: [target],
                    span,
                  }
              }
            }
            SyntaxValue::Literal(text, span) =>
              ignore(lower_constant(property.name, text, span))
          }
        }
        for child in children {
          pending.push({
            ..context,
            node: child,
            parent_template: Some(node_template),
          })
        }
      }
      SyntaxNode::Conditional(path, span, then_nodes, else_nodes) => {
        let draft_key = context.scope_id + "\u{1f}" + path
        let target : IRBindingTarget = {
          node: context.parent_template.unwrap_or("root"),
          property: "$condition",
          target_type: "Bool",
          span,
        }
        match binding_drafts.get(draft_key) {
          Some(previous) => previous.targets.push(target)
          None =>
            binding_drafts[draft_key] = {
              path,
              scope_id: context.scope_id,
              scope_type: context.scope_type,
              targets: [target],
              span,
            }
        }
        capabilities["conditional"] = IRCapability::ConditionalTree
        for child in then_nodes {
          pending.push({ ..context, node: child })
        }
        for child in else_nodes {
          pending.push({ ..context, node: child })
        }
      }
      SyntaxNode::KeyedItems(
        path,
        path_span,
        key_path,
        key_span,
        template_type,
        children
      ) => {
        let scope = parsed.structs[context.scope_type]
        let field_name = snake_case(path)
        let field = match scope.field(field_name) {
          Some(value) => value
          None =>
            raise Unsupported(
              "ItemsSource must resolve to a public Array field: " + path,
              path_span,
            )
        }
        let item_type = match array_item_type(field.field_type) {
          Some(value) => value
          None =>
            raise Unsupported(
              "ItemsSource field must have type Array[T]: " + field.name,
              path_span,
            )
        }
        let item = match parsed.structs.get(item_type) {
          Some(value) => value
          None =>
            raise Unsupported(
              "ItemsSource item type is not a public struct: " + item_type,
              path_span,
            )
        }
        match template_type {
          Some(explicit) if explicit.package_path != parsed.package_path ||
            explicit.type_name != item_type =>
            raise Unsupported(
              "DataTemplate ui:DataType must match inferred item type " +
              item_type,
              explicit.span,
            )
          _ => ()
        }
        let key_field_name = snake_case(key_path)
        let key_field = match item.field(key_field_name) {
          Some(value) => value
          None =>
            raise Unsupported(
              "KeyPath must resolve to a public item field: " + key_path,
              key_span,
            )
        }
        let key_type = key_field.field_type.trim().to_owned()
        if !["String", "Int", "UInt"].contains(
            parsed.resolve_named_alias(key_type),
          ) {
          raise Unsupported(
            "KeyPath field must be String, Int, or UInt: " + key_field.name,
            key_span,
          )
        }
        let next : IRCollection = {
          field_name,
          item_type,
          key_field: key_field_name,
          key_type,
          patch_replace: None,
          patch_upsert: None,
          patch_remove: None,
          patch_move: None,
        }
        match collections.get(path) {
          Some(previous) if previous.field_name != next.field_name ||
            previous.item_type != next.item_type ||
            previous.key_field != next.key_field =>
            raise InvalidContract(
              "collection is used with inconsistent typed metadata: " + path,
            )
          None => collections[path] = next
          _ => ()
        }
        let target : IRBindingTarget = {
          node: context.parent_template.unwrap_or("root"),
          property: "$items",
          target_type: field.field_type,
          span: path_span,
        }
        binding_drafts[context.scope_id + "\u{1f}" + path] = {
          path,
          scope_id: context.scope_id,
          scope_type: context.scope_type,
          targets: [target],
          span: path_span,
        }
        let item_scope_id = "item:" + context.scope_id + ":" + path
        if !data_scopes.any(scope => scope.id == item_scope_id) {
          data_scopes.push({
            id: item_scope_id,
            parent: Some(context.scope_id),
            value_type: {
              package_alias: syntax.data_type.package_alias,
              package_path: parsed.package_path,
              type_name: item_type,
              span: template_type.map_or(path_span, value => value.span),
            },
            kind: IRDataScopeKind::TemplateItem,
            span: template_type.map_or(path_span, value => value.span),
          })
        }
        let base = context.parent_template.unwrap_or("") +
          "/" +
          kebab_case(path) +
          ":__SELENE_KEY__"
        for child in children {
          pending.push({
            node: child,
            scope_id: item_scope_id,
            scope_type: item_type,
            collection_path: Some(path),
            parent_template: context.parent_template,
            item_prefix_template: Some(base),
          })
        }
        capabilities["keyed"] = IRCapability::KeyedCollection
      }
    }
  }
  for group in syntax.visual_state_groups {
    if group.name.trim() == "" {
      raise Unsupported("VisualStateGroup.Name cannot be empty", group.span)
    }
    guard node_scopes.get(group.owner_node) is Some((scope_id, scope_type)) else {
      raise InvalidContract(
        "visual-state owner is missing from generated tree: " + group.owner_node,
      )
    }
    match group.current {
      Some(SyntaxValue::Binding(path, span)) => {
        let draft_key = scope_id + "\u{1f}" + path
        let target : IRBindingTarget = {
          node: group.owner_node,
          property: "$visual-state:" + group.name,
          target_type: "State",
          span,
        }
        match binding_drafts.get(draft_key) {
          Some(previous) => previous.targets.push(target)
          None =>
            binding_drafts[draft_key] = {
              path,
              scope_id,
              scope_type,
              targets: [target],
              span,
            }
        }
      }
      _ => ()
    }
    for state in group.states {
      for setter in state.setters {
        match setter.value {
          SyntaxValue::Binding(path, span) => {
            let draft_key = scope_id + "\u{1f}" + path
            let target : IRBindingTarget = {
              node: setter.target_node,
              property: setter.property,
              target_type: property_target_type(setter.property, span),
              span,
            }
            match binding_drafts.get(draft_key) {
              Some(previous) => previous.targets.push(target)
              None =>
                binding_drafts[draft_key] = {
                  path,
                  scope_id,
                  scope_type,
                  targets: [target],
                  span,
                }
            }
          }
          SyntaxValue::Literal(text, span) =>
            ignore(lower_constant(setter.property, text, span))
        }
      }
    }
    capabilities["visual-state"] = IRCapability::VisualState
  }
  let bindings : Array[IRBinding] = []
  let binding_ids : Map[String, String] = Map([])
  let binding_keys = binding_drafts.keys().collect()
  binding_keys.sort()
  for index, key in binding_keys {
    let draft = binding_drafts[key]
    let (steps, result_type, dependencies) = resolve_binding(
      parsed,
      draft.scope_type,
      draft.path,
      draft.span,
    )
    for target in draft.targets {
      if !binding_assignable(result_type, target.target_type) {
        raise Unsupported(
          "binding result " +
          result_type +
          " is not assignable to " +
          target.property +
          " (" +
          target.target_type +
          ")",
          target.span,
        )
      }
    }
    let id = "binding-" + index.to_string()
    binding_ids[key] = id
    bindings.push({
      id,
      path: draft.path,
      scope_id: draft.scope_id,
      steps,
      result_type,
      dependencies,
      targets: draft.targets,
      span: draft.span,
    })
  }
  action_routes.sort_by(fn(left, right) {
    let source = left.node_template.compare(right.node_template)
    if source != 0 {
      source
    } else {
      left.event_kind.compare(right.event_kind)
    }
  })
  let action_shapes : Map[String, Bool] = Map([])
  for route in action_routes {
    let item_scoped = route.collection_path is Some(_)
    match action_shapes.get(route.variant_name) {
      Some(previous) if previous != item_scoped =>
        raise InvalidContract(
          "action has conflicting root/item contexts: " + route.authored_name,
        )
      _ => action_shapes[route.variant_name] = item_scoped
    }
  }
  let action_variants : Array[IRVariant] = []
  let action_names = action_shapes.keys().collect()
  action_names.sort()
  for name in action_names {
    action_variants.push({
      name,
      payload: if action_shapes[name] {
        Some("String")
      } else {
        None
      },
    })
  }
  let action_name = syntax.identity.view_name + "Action"
  let action = match parsed.enums.get(action_name) {
    Some(declared) => {
      for expected in action_variants {
        guard declared.variants.any(variant => {
          variant.name == expected.name && variant.payload == expected.payload
        }) else {
          raise InvalidContract(
            "Action variant does not match XAML route: " + expected.name,
          )
        }
      }
      declared
    }
    None => { name: action_name, variants: action_variants }
  }
  let (patch, patch_projection) = match parsed.functions.get("apply_patches") {
    Some(function) => {
      if function.parameters.length() != 2 ||
        base_type_name(function.parameters[0]) != model_type.type_name ||
        base_type_name(function.return_type) != model_type.type_name {
        raise InvalidContract(
          "apply_patches must have type (Model, Array[Patch]) -> Model",
        )
      }
      let patch_name = array_item_type(function.parameters[1]).unwrap_or("")
      let patch = match parsed.enums.get(patch_name) {
        Some(value) => value
        None =>
          raise InvalidContract(
            "apply_patches Patch is not a public enum in .mbti: " + patch_name,
          )
      }
      (Some(patch), IRPatchProjection::Apply(function.name))
    }
    None => {
      let patch_name = if model_type.type_name.has_suffix("State") {
        model_type.type_name[:model_type.type_name.length() - 5].to_owned() +
        "Patch"
      } else if model_type.type_name.has_suffix("Model") {
        model_type.type_name[:model_type.type_name.length() - 5].to_owned() +
        "Patch"
      } else {
        model_type.type_name + "Patch"
      }
      match parsed.enums.get(patch_name) {
        Some(value) => (Some(value), IRPatchProjection::GeneratedCollections)
        None => (None, IRPatchProjection::None)
      }
    }
  }
  let resolved_collections = match patch_projection {
    IRPatchProjection::GeneratedCollections =>
      resolve_patch_families(parsed, patch, collections)
    _ => collections
  }
  if patch is Some(_) {
    capabilities["patch"] = IRCapability::TypedPatch
  }
  let capability_names = capabilities.keys().collect()
  capability_names.sort()
  let required_capabilities = capability_names.map(name => capabilities[name])
  data_scopes.sort_by(fn(left, right) { left.id.compare(right.id) })
  let visual_state_groups : Array[IRVisualStateGroup] = []
  let group_names : Map[String, Bool] = Map([])
  for group in syntax.visual_state_groups {
    let group_key = group.owner_node + "\u{1f}" + group.name
    if group_names.contains(group_key) {
      raise Unsupported(
        "duplicate VisualStateGroup on the same owner: " + group.name,
        group.span,
      )
    }
    group_names[group_key] = true
    let state_names : Map[String, Bool] = Map([])
    let states : Array[IRVisualState] = []
    for state in group.states {
      if state.name.trim() == "" {
        raise Unsupported("VisualState.Name cannot be empty", state.span)
      }
      if state_names.contains(state.name) {
        raise Unsupported(
          "duplicate VisualState in group " + group.name + ": " + state.name,
          state.span,
        )
      }
      state_names[state.name] = true
      let setters : Array[IRVisualStateSetter] = []
      for setter in state.setters {
        if setter.target_node.has_prefix("\u{0}") {
          raise Unsupported(
            "VisualState Setter target does not exist in this namescope: " +
            setter.target_node[1:].to_owned(),
            setter.span,
          )
        }
        if setter.property.trim() == "" {
          raise Unsupported("Setter.Property cannot be empty", setter.span)
        }
        let value = match setter.value {
          SyntaxValue::Literal(text, span) =>
            IRValue::Constant(lower_constant(setter.property, text, span), span)
          SyntaxValue::Binding(path, span) => {
            let (scope_id, _) = node_scopes[group.owner_node]
            IRValue::Binding(binding_ids[scope_id + "\u{1f}" + path], span)
          }
        }
        setters.push({
          target_node: setter.target_node,
          property: setter.property,
          value,
          span: setter.span,
        })
      }
      states.push({ name: state.name, setters, span: state.span })
    }
    if states.length() == 0 {
      raise Unsupported(
        "VisualStateGroup requires at least one VisualState",
        group.span,
      )
    }
    let current = match group.current {
      Some(SyntaxValue::Literal(value, span)) => {
        if !state_names.contains(value) {
          raise Unsupported(
            "VisualStateGroup.Current does not name a state: " + value,
            span,
          )
        }
        Some(IRValue::Constant(IRConstant::StringValue(value), span))
      }
      Some(SyntaxValue::Binding(path, span)) => {
        let (scope_id, _) = node_scopes[group.owner_node]
        Some(IRValue::Binding(binding_ids[scope_id + "\u{1f}" + path], span))
      }
      None => None
    }
    let transitions : Array[IRVisualTransition] = []
    for transition in group.transitions {
      let duration = @string.parse_double(transition.duration) catch {
        _ => raise Unsupported("invalid Transition.Duration", transition.span)
      }
      let delay = @string.parse_double(transition.delay) catch {
        _ => raise Unsupported("invalid Transition.Delay", transition.span)
      }
      if duration < 0.0 || delay < 0.0 {
        raise Unsupported(
          "Transition.Duration and Delay must be non-negative",
          transition.span,
        )
      }
      for endpoint in [transition.from, transition.to] {
        match endpoint {
          Some(name) if name != "*" && !state_names.contains(name) =>
            raise Unsupported(
              "Transition references an unknown state: " + name,
              transition.span,
            )
          _ => ()
        }
      }
      transitions.push({
        from: transition.from,
        to: transition.to,
        duration,
        delay,
        easing: transition.easing,
        span: transition.span,
      })
    }
    visual_state_groups.push({
      owner_node: group.owner_node,
      name: group.name,
      current,
      states,
      transitions,
      span: group.span,
    })
  }
  let contract : IRBusinessContract = {
    package_path: parsed.package_path,
    structs: parsed.structs,
    enums: parsed.enums,
    aliases: parsed.aliases,
    functions: parsed.functions,
    model_type,
    view_model_type: resolved_view_model_type,
    view_model_projection: projection,
    state: view_model,
    patch,
    patch_projection,
    action,
    collections: resolved_collections,
  }
  {
    identity: syntax.identity,
    contract,
    root: seal_node(
      syntax.root,
      "root",
      None,
      None,
      binding_ids,
      resolved_collections,
    ),
    data_scopes,
    bindings,
    action_routes,
    visual_state_groups,
    required_capabilities,
  }
}

///|
fn resolve_binding(
  contract : ParsedContract,
  scope_type : String,
  path : String,
  span : @infoset.XamlSourceSpan,
) -> (Array[IRBindingStep], String, Array[String]) raise ViewIRError {
  if path == "" || path == "." {
    return ([], scope_type, [])
  }
  let steps : Array[IRBindingStep] = []
  let dependencies : Array[String] = []
  let mut current_type = scope_type
  let mut result_type = scope_type
  let path_parts = path.split(".").collect()
  for index, raw_part in path_parts {
    let step_name = snake_case(raw_part.to_owned())
    let definition = match contract.structs.get(current_type) {
      Some(value) => value
      None =>
        raise Unsupported(
          "binding scope is not a public struct: " + current_type,
          span,
        )
    }
    match definition.field(step_name) {
      Some(field) => {
        result_type = if field.field_type.contains("[") ||
          field.field_type.contains("(") ||
          field.field_type.has_suffix("?") {
          field.field_type
        } else {
          contract.resolve_named_alias(base_type_name(field.field_type))
        }
        steps.push({
          declaring_type: current_type,
          step: field.name,
          result_type,
          span,
        })
        dependencies.push(current_type + "." + field.name)
        current_type = contract.resolve_named_alias(
          base_type_name(field.field_type),
        )
      }
      None if index + 1 == path_parts.length() => {
        let function_name = current_type + "::" + step_name
        let computation = match contract.functions.get(function_name) {
          Some(value) => value
          None =>
            raise Unsupported(
              "binding member is not public: " + raw_part.to_owned(),
              span,
            )
        }
        result_type = contract.resolve_named_alias(
          base_type_name(computation.return_type),
        )
        steps.push({
          declaring_type: current_type,
          step: step_name + "()",
          result_type,
          span,
        })
        dependencies.push(function_name)
        current_type = result_type
      }
      None =>
        raise Unsupported(
          "binding member is not a public field: " + raw_part.to_owned(),
          span,
        )
    }
  }
  (steps, result_type, dependencies)
}

///|
fn resolve_patch_families(
  _contract : ParsedContract,
  patch : IREnum?,
  collections : Map[String, IRCollection],
) -> Map[String, IRCollection] raise ViewIRError {
  guard patch is Some(definition) else { return collections }
  let claimed_variants : Map[String, String] = Map([])
  let collection_paths = collections.keys().collect()
  collection_paths.sort()
  for path in collection_paths {
    let collection = collections[path]
    let replace_prefix = pascal_case(collection.field_name)
    let operation_prefix = if replace_prefix.has_suffix("s") {
      replace_prefix[:replace_prefix.length() - 1].to_owned()
    } else {
      replace_prefix
    }
    let expected = [
      (replace_prefix + "Replace", "Array[" + collection.item_type + "]"),
      (operation_prefix + "Upsert", collection.item_type),
      (operation_prefix + "Remove", collection.key_type),
      (operation_prefix + "Move", "(" + collection.key_type + ", UInt)"),
    ]
    if !definition.variants.any(variant => {
        expected.any(item => item.0 == variant.name)
      }) {
      continue
    }
    for entry in expected {
      let (variant_name, expected_payload) = entry
      let matches = definition.variants.filter(variant => {
        variant.name == variant_name
      })
      if matches.length() != 1 {
        raise InvalidContract(
          "patch variant must occur exactly once for collection " +
          path +
          ": " +
          variant_name,
        )
      }
      if matches[0].payload != Some(expected_payload) {
        raise InvalidContract(
          "patch variant payload must be " +
          expected_payload +
          ": " +
          variant_name,
        )
      }
      match claimed_variants.get(variant_name) {
        Some(owner) if owner != path =>
          raise InvalidContract(
            "patch variant is claimed by multiple collections: " + variant_name,
          )
        _ => claimed_variants[variant_name] = path
      }
    }
    collections[path] = {
      ..collection,
      patch_replace: Some(expected[0].0),
      patch_upsert: Some(expected[1].0),
      patch_remove: Some(expected[2].0),
      patch_move: Some(expected[3].0),
    }
  }
  collections
}

///|
fn seal_node(
  node : SyntaxNode,
  scope_id : String,
  parent_template : String?,
  item_prefix_template : String?,
  binding_ids : Map[String, String],
  collections : Map[String, IRCollection],
) -> IRNode raise ViewIRError {
  match node {
    SyntaxNode::Element(kind, key, name, properties, children, span) => {
      let node_template = item_prefix_template.map_or(key, prefix => {
        prefix + "/" + key
      })
      let sealed_properties : Array[IRProperty] = []
      for property in properties {
        if property.name == "OnClick" || property.name == "OnFocus" {
          continue
        }
        let value = match property.value {
          SyntaxValue::Literal(text, value_span) =>
            IRValue::Constant(
              lower_constant(property.name, text, value_span),
              value_span,
            )
          SyntaxValue::Binding(path, value_span) =>
            IRValue::Binding(
              binding_ids[scope_id + "\u{1f}" + path],
              value_span,
            )
        }
        sealed_properties.push({ name: property.name, value })
      }
      IRNode::Element(
        kind,
        key,
        name,
        sealed_properties,
        children.map(child => {
          seal_node(
            child,
            scope_id,
            Some(node_template),
            item_prefix_template,
            binding_ids,
            collections,
          )
        }),
        span,
      )
    }
    SyntaxNode::Conditional(path, span, then_nodes, else_nodes) =>
      IRNode::Conditional(
        binding_ids[scope_id + "\u{1f}" + path],
        span,
        then_nodes.map(child => {
          seal_node(
            child, scope_id, parent_template, item_prefix_template, binding_ids,
            collections,
          )
        }),
        else_nodes.map(child => {
          seal_node(
            child, scope_id, parent_template, item_prefix_template, binding_ids,
            collections,
          )
        }),
      )
    SyntaxNode::KeyedItems(
      path,
      path_span,
      key_path,
      key_span,
      template_type,
      children
    ) => {
      let item_scope = "item:" + scope_id + ":" + path
      let base = parent_template.unwrap_or("") +
        "/" +
        kebab_case(path) +
        ":__SELENE_KEY__"
      IRNode::KeyedItems(
        binding_ids[scope_id + "\u{1f}" + path],
        path_span,
        key_path,
        key_span,
        template_type,
        children.map(child => {
          seal_node(
            child,
            item_scope,
            parent_template,
            Some(base),
            binding_ids,
            collections,
          )
        }),
      )
    }
  }
}

///|
fn property_target_type(
  property : String,
  span : @infoset.XamlSourceSpan,
) -> String raise ViewIRError {
  if [
      "Text", "Source", "Background", "BorderColor", "OutlineColor", "Color", "FontFamily",
    ].contains(property) {
    "String"
  } else if [
      "Active", "Enabled", "Focusable", "Bold", "HorizontalScroll", "VerticalScroll",
    ].contains(property) {
    "Bool"
  } else if [
      "Left", "Top", "Border", "Radius", "FontSize", "Grow", "Shrink", "RowGap",
      "Gap", "ColumnGap", "ScrollbarWidth", "OutlineWidth", "OutlineOffset",
    ].contains(property) {
    "Double"
  } else if property == "ZIndex" {
    "Int"
  } else if ["Width", "Height", "Basis"].contains(property) {
    "LayoutValue"
  } else if ["Margin", "Padding"].contains(property) {
    "Rect"
  } else if ["Position", "Align", "Wrap", "Fit", "Direction"].contains(property) {
    property
  } else {
    raise Unsupported("unsupported generated property: " + property, span)
  }
}

///|
fn lower_constant(
  property : String,
  text : String,
  span : @infoset.XamlSourceSpan,
) -> IRConstant raise ViewIRError {
  let target = property_target_type(property, span)
  match target {
    "String" => IRConstant::StringValue(text)
    "Bool" =>
      match text.to_lower() {
        "true" => IRConstant::BoolValue(true)
        "false" => IRConstant::BoolValue(false)
        _ => raise Unsupported("invalid Bool literal: " + text, span)
      }
    "Double" =>
      IRConstant::DoubleValue(
        @string.parse_double(text) catch {
          _ => raise Unsupported("invalid number literal: " + text, span)
        },
      )
    "Int" =>
      IRConstant::IntValue(
        @string.parse_int(text) catch {
          _ => raise Unsupported("invalid Int literal: " + text, span)
        },
      )
    "LayoutValue" =>
      if text == "Auto" {
        IRConstant::LayoutValue(IRLayoutValue::Auto)
      } else if text.has_suffix("%") {
        let number = @string.parse_double(text[:text.length() - 1]) catch {
          _ => raise Unsupported("invalid percentage literal: " + text, span)
        }
        IRConstant::LayoutValue(IRLayoutValue::Percent(number / 100.0))
      } else {
        let number = @string.parse_double(text) catch {
          _ => raise Unsupported("invalid layout literal: " + text, span)
        }
        IRConstant::LayoutValue(IRLayoutValue::Px(number))
      }
    "Rect" => {
      let parts = text.split(" ").filter(value => value != "").collect()
      if ![1, 2, 4].contains(parts.length()) {
        raise Unsupported(
          "rect literal requires one, two, or four numbers", span,
        )
      }
      let values : Array[Double] = []
      for part in parts {
        values.push(
          @string.parse_double(part) catch {
            _ => raise Unsupported("invalid rect literal: " + text, span)
          },
        )
      }
      match values.length() {
        1 => IRConstant::RectValue(values[0], values[0], values[0], values[0])
        2 => IRConstant::RectValue(values[1], values[0], values[1], values[0])
        _ => IRConstant::RectValue(values[3], values[0], values[1], values[2])
      }
    }
    "Position" =>
      match text {
        "Relative" | "Absolute" => IRConstant::EnumValue(text)
        _ =>
          raise Unsupported("invalid generated Position literal: " + text, span)
      }
    "Align" =>
      match text {
        "Left" | "Center" | "Right" => IRConstant::EnumValue(text)
        _ => raise Unsupported("invalid generated Align literal: " + text, span)
      }
    "Wrap" =>
      match text {
        "NoWrap" | "no-wrap" => IRConstant::EnumValue("NoWrap")
        "Wrap" | "WordWrap" | "word-wrap" => IRConstant::EnumValue("WordWrap")
        _ => raise Unsupported("invalid generated Wrap literal: " + text, span)
      }
    "Fit" =>
      match text {
        "Fill" | "Stretch" => IRConstant::EnumValue("Fill")
        "Contain" | "Cover" => IRConstant::EnumValue(text)
        _ => raise Unsupported("invalid generated Fit literal: " + text, span)
      }
    "Direction" =>
      match text {
        "Column" | "Row" | "RowReverse" | "ColumnReverse" =>
          IRConstant::EnumValue(text)
        _ =>
          raise Unsupported(
            "invalid generated Direction literal: " + text,
            span,
          )
      }
    _ => raise Unsupported("unsupported generated property: " + property, span)
  }
}

///|
fn binding_assignable(source : String, target : String) -> Bool {
  if source == target {
    return true
  }
  match target {
    "Double" => ["Float", "Int", "UInt", "Double"].contains(source)
    "Int" => ["Int", "UInt"].contains(source)
    "LayoutValue" | "Rect" =>
      ["Float", "Int", "UInt", "Double", "String"].contains(source)
    "String" => true
    "State" => source == "String" || source == "Bool"
    _ => false
  }
}
