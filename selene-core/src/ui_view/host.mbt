///|
fn current_store() -> HostWorldStore {
  let world = @ecs.require_current_world()
  host_world_stores.get_or_init(world.id(), fn() {
    { views: Map([]), last_focused: None }
  })
}

///|
fn require_record(
  host : ViewHost,
  entity : @entity.Entity,
) -> ViewRecord raise HostError {
  let actual = @ecs.require_current_world().id()
  if actual != host.world_id {
    raise HostError::WrongWorld(host.world_id, actual)
  }
  match current_store().views.get(entity) {
    Some(record) => record
    None => raise HostError::Released
  }
}

///|
pub fn ViewHost::new() -> ViewHost {
  { world_id: @ecs.require_current_world().id() }
}

///|
pub fn MountedView::new() -> MountedView {
  let entity = @entity.Entity()
  @ui.nodes()[entity] = @ui.Node(active=false)
  { host: ViewHost::new(), entity, mounted: false }
}

///|
pub fn MountedView::apply(
  self : MountedView,
  mutations : Array[TreeMutation],
) -> Unit raise HostError {
  if self.mounted {
    self.host.apply(self.entity, mutations)
    return
  }
  let specs : Array[NodeSpec] = []
  for mutation in mutations {
    match mutation {
      Mount(spec) => specs.push(spec)
      _ =>
        raise HostError::InvalidMutation(
          "SH1018", "the first view batch must contain only Mount operations",
        )
    }
  }
  self.host.mount(self.entity, specs)
  self.mounted = true
}

///|
pub fn MountedView::entity(
  self : MountedView,
  key : String,
) -> @entity.Entity? raise HostError {
  self.host.entity(self.entity, key)
}

///|
pub fn MountedView::container(self : MountedView) -> @entity.Entity {
  self.entity
}

///|
pub fn MountedView::activate(
  self : MountedView,
  parent : @entity.Entity,
) -> Unit raise HostError {
  if !self.mounted {
    raise HostError::InvalidMutation(
      "SH1019", "view must mount before activation",
    )
  }
  self.entity.set_parent(parent)
  let node = @ui.nodes()[self.entity]
  @ui.nodes()[self.entity] = { ..node, active: true }
}

///|
pub fn MountedView::release(self : MountedView) -> Unit raise HostError {
  if self.mounted {
    self.host.unmount(self.entity)
  }
  remove_ui_components(self.entity)
  if self.entity.is_alive() {
    self.entity.destroy()
  }
  self.mounted = false
}

///|
pub fn MountedView::swap(
  self : MountedView,
  staged : MountedView,
) -> Unit raise HostError {
  self.host.swap(self.entity, staged.entity)
  remove_ui_components(self.entity)
  if self.entity.is_alive() {
    self.entity.destroy()
  }
  self.mounted = false
}

///|
pub fn ViewHost::entity(
  self : ViewHost,
  root : @entity.Entity,
  key : String,
) -> @entity.Entity? raise HostError {
  require_record(self, root).entities.get(key)
}

///|
fn ViewHost::snapshot(
  self : ViewHost,
  root : @entity.Entity,
) -> ViewSnapshot raise HostError {
  let record = require_record(self, root)
  let mut focus_key : String? = None
  match @ui.focused_entity() {
    Some(focused) => focus_key = record.entity_keys.get(focused)
    None => ()
  }
  let scroll : Array[ScrollSnapshot] = []
  for key, target in record.entities {
    match @ui.scroll_positions().get(target) {
      Some(position) => scroll.push({ key, x: position.x, y: position.y })
      None => ()
    }
  }
  { focus_key, scroll }
}

///|
fn ViewHost::restore(
  self : ViewHost,
  root : @entity.Entity,
  saved : ViewSnapshot,
) -> Unit raise HostError {
  let record = require_record(self, root)
  for position in saved.scroll {
    match record.entities.get(position.key) {
      Some(target) if @ui.scroll_positions().contains(target) =>
        @ui.scroll_positions()[target] = { x: position.x, y: position.y }
      _ => ()
    }
  }
  match saved.focus_key {
    Some(key) =>
      match record.entities.get(key) {
        Some(target) if @ui.focusables().contains(target) => @ui.focus(target)
        _ => @ui.blur()
      }
    None => ()
  }
}

///|
pub fn ViewHost::swap(
  self : ViewHost,
  live : @entity.Entity,
  staged : @entity.Entity,
) -> Unit raise HostError {
  if live == staged {
    raise HostError::InvalidMutation(
      "SH2002", "live and staged view entities must be distinct",
    )
  }
  ignore(require_record(self, live))
  ignore(require_record(self, staged))
  let parent = match live.get_parent() {
    Some(value) => value
    None =>
      raise HostError::InvalidMutation("SH2001", "live view has no host parent")
  }
  let saved = self.snapshot(live)
  let focused_before = @ui.focused_entity()
  let transfer_focus_cursor = saved.focus_key is Some(_) &&
    current_store().last_focused == focused_before
  let siblings = parent.get_children().copy()
  let mut live_index = siblings.length()
  for index, sibling in siblings {
    if sibling == live {
      live_index = index
      break
    }
  }
  live.remove_parent()
  for sibling in parent.get_children().copy() {
    sibling.remove_parent()
  }
  for index = 0; index <= siblings.length(); index = index + 1 {
    if index == live_index {
      staged.set_parent(parent)
    }
    if index < siblings.length() && siblings[index] != live {
      siblings[index].set_parent(parent)
    }
  }
  self.restore(staged, saved)
  if transfer_focus_cursor {
    current_store().last_focused = @ui.focused_entity()
  }
  self.unmount(live)
}

///|
pub fn ViewHost::unmount(
  self : ViewHost,
  entity : @entity.Entity,
) -> Unit raise HostError {
  let record = require_record(self, entity)
  let store = current_store()
  let scopes = @ui.focus_scopes()
  let mut scope_index = scopes.length() - 1
  while scope_index >= 0 {
    if record.active_focus_scopes.contains(scopes[scope_index].root) {
      ignore(scopes.remove(scope_index))
    }
    scope_index = scope_index - 1
  }
  record.active_focus_scopes.clear()
  match @ui.focused_entity() {
    Some(target) =>
      if target == record.container || record.entity_keys.contains(target) {
        @ui.blur()
        store.last_focused = None
      }
    None => ()
  }
  let keys = record.entities.keys().collect()
  for key in keys {
    match record.entities.get(key) {
      Some(target) => remove_ui_components(target)
      None => ()
    }
  }
  for key in record.roots {
    match record.entities.get(key) {
      Some(target) => {
        target.remove_parent()
        target.destroy()
      }
      None => ()
    }
  }
  store.views.remove(entity)
}

///|
pub fn ViewHost::mount(
  self : ViewHost,
  entity : @entity.Entity,
  specs : Array[NodeSpec],
) -> Unit raise HostError {
  let store = current_store()
  if !entity.is_alive() || store.views.contains(entity) {
    raise HostError::InvalidMutation(
      "SH1017", "mount entity must be alive and unused",
    )
  }
  store.views[entity] = {
    container: entity,
    nodes: Map([]),
    entities: Map([]),
    entity_keys: Map([]),
    roots: [],
    active_focus_scopes: [],
    visual_states: Map([]),
    visual_transitions: Map([]),
  }
  self.apply(entity, specs.map(spec => TreeMutation::Mount(spec))) catch {
    error => {
      store.views.remove(entity)
      raise error
    }
  }
}

///|
pub fn ViewHost::apply(
  self : ViewHost,
  entity : @entity.Entity,
  mutations : Array[TreeMutation],
) -> Unit raise HostError {
  let record = require_record(self, entity)
  let planned_nodes : Map[String, HostNode] = Map([])
  for key, node in record.nodes {
    planned_nodes[key] = {
      spec: node.spec,
      effective_spec: node.effective_spec,
      children: node.children.copy(),
    }
  }
  let planned_roots = record.roots.copy()
  let style_keys_to_validate : Map[String, Bool] = Map([])
  for mutation in mutations {
    match mutation {
      Mount(spec) => {
        if spec.key == "" || planned_nodes.contains(spec.key) {
          raise HostError::InvalidMutation(
            "SH1001",
            "mount key must be unique and non-empty: " + spec.key,
          )
        }
        match spec.parent {
          Some(parent) =>
            match planned_nodes.get(parent) {
              Some(parent_node) => parent_node.children.push(spec.key)
              None =>
                raise HostError::InvalidMutation(
                  "SH1002",
                  "mount parent does not exist: " + parent,
                )
            }
          None => planned_roots.push(spec.key)
        }
        planned_nodes[spec.key] = { spec, effective_spec: spec, children: [] }
        style_keys_to_validate[spec.key] = true
      }
      Update(spec) => {
        let previous = match planned_nodes.get(spec.key) {
          Some(value) => value
          None =>
            raise HostError::InvalidMutation(
              "SH1003",
              "update target does not exist: " + spec.key,
            )
        }
        if previous.spec.parent != spec.parent {
          raise HostError::InvalidMutation(
            "SH1013",
            "Update cannot change a node parent: " + spec.key,
          )
        }
        planned_nodes[spec.key] = {
          spec,
          effective_spec: previous.effective_spec,
          children: previous.children,
        }
        style_keys_to_validate[spec.key] = true
      }
      SetText(key, value) => {
        let node = match planned_nodes.get(key) {
          Some(current) if current.spec.kind == Text => current
          Some(_) =>
            raise HostError::InvalidMutation(
              "SH1014",
              "set-text target is not a Text node: " + key,
            )
          None =>
            raise HostError::InvalidMutation(
              "SH1003",
              "mutation target does not exist: " + key,
            )
        }
        planned_nodes[key] = { ..node, spec: { ..node.spec, text: value } }
      }
      SetSource(key, value) => {
        let node = match planned_nodes.get(key) {
          Some(current) if current.spec.kind == Image => current
          Some(_) =>
            raise HostError::InvalidMutation(
              "SH1015",
              "set-source target is not an Image node: " + key,
            )
          None =>
            raise HostError::InvalidMutation(
              "SH1003",
              "mutation target does not exist: " + key,
            )
        }
        planned_nodes[key] = { ..node, spec: { ..node.spec, source: value } }
      }
      SetBackground(key, value) => {
        let node = match planned_nodes.get(key) {
          Some(current) => current
          None =>
            raise HostError::InvalidMutation(
              "SH1003",
              "mutation target does not exist: " + key,
            )
        }
        planned_nodes[key] = {
          ..node,
          spec: { ..node.spec, style: { ..node.spec.style, background: value } },
        }
        style_keys_to_validate[key] = true
      }
      SetActive(key, value) => {
        let node = match planned_nodes.get(key) {
          Some(current) => current
          None =>
            raise HostError::InvalidMutation(
              "SH1003",
              "mutation target does not exist: " + key,
            )
        }
        planned_nodes[key] = { ..node, spec: { ..node.spec, active: value } }
      }
      SetEnabled(key, value) => {
        let node = match planned_nodes.get(key) {
          Some(current) if current.spec.kind == Button => current
          Some(_) =>
            raise HostError::InvalidMutation(
              "SH1016",
              "set-enabled target is not a Button node: " + key,
            )
          None =>
            raise HostError::InvalidMutation(
              "SH1003",
              "mutation target does not exist: " + key,
            )
        }
        planned_nodes[key] = { ..node, spec: { ..node.spec, enabled: value } }
      }
      SetTop(key, value) => {
        let node = match planned_nodes.get(key) {
          Some(current) => current
          None =>
            raise HostError::InvalidMutation(
              "SH1003",
              "mutation target does not exist: " + key,
            )
        }
        planned_nodes[key] = {
          ..node,
          spec: { ..node.spec, style: { ..node.spec.style, top: value } },
        }
      }
      Move(key, parent, index) => {
        let node = match planned_nodes.get(key) {
          Some(value) => value
          None =>
            raise HostError::InvalidMutation(
              "SH1004",
              "move target does not exist: " + key,
            )
        }
        let new_parent = match planned_nodes.get(parent) {
          Some(value) => value
          None =>
            raise HostError::InvalidMutation(
              "SH1005",
              "move parent does not exist: " + parent,
            )
        }
        let mut ancestor : String? = Some(parent)
        while ancestor is Some(value) {
          if value == key {
            raise HostError::InvalidMutation(
              "SH1006",
              "move would create a cycle: " + key,
            )
          }
          ancestor = planned_nodes[value].spec.parent
        }
        match node.spec.parent {
          Some(old_parent) =>
            for old_index, child in planned_nodes[old_parent].children {
              if child == key {
                ignore(planned_nodes[old_parent].children.remove(old_index))
                break
              }
            }
          None =>
            for old_index, root in planned_roots {
              if root == key {
                ignore(planned_roots.remove(old_index))
                break
              }
            }
        }
        if index < 0 || index > new_parent.children.length() {
          raise HostError::InvalidMutation(
            "SH1007",
            "move index is out of range: " + index.to_string(),
          )
        }
        new_parent.children.insert(index, key)
        planned_nodes[key] = {
          ..node,
          spec: { ..node.spec, parent: Some(parent) },
        }
      }
      Remove(key) => {
        let node = match planned_nodes.get(key) {
          Some(value) => value
          None =>
            raise HostError::InvalidMutation(
              "SH1008",
              "remove target does not exist: " + key,
            )
        }
        match node.spec.parent {
          Some(parent) =>
            for old_index, child in planned_nodes[parent].children {
              if child == key {
                ignore(planned_nodes[parent].children.remove(old_index))
                break
              }
            }
          None =>
            for old_index, root in planned_roots {
              if root == key {
                ignore(planned_roots.remove(old_index))
                break
              }
            }
        }
        let pending = [key]
        while pending.length() > 0 {
          let removed = pending.pop().unwrap()
          for child in planned_nodes[removed].children {
            pending.push(child)
          }
          planned_nodes.remove(removed)
        }
      }
    }
  }
  for key, _ in style_keys_to_validate {
    guard planned_nodes.get(key) is Some(node) else { continue }
    let spec = node.spec
    let style = spec.style
    if style.background != "" {
      ignore(@ui.BackgroundColor::from_css(style.background))
    }
    if style.border_color != "" {
      ignore(@ui.BorderColor::from_css(style.border_color))
    }
    if spec.kind == Text && style.color != "" {
      ignore(@ui.TextColor::from_css(style.color))
    }
    if style.outline_color != "" {
      ignore(@ui.BackgroundColor::from_css(style.outline_color))
    }
  }
  for _, node in planned_nodes {
    for
      target in [
        node.spec.navigation_up,
        node.spec.navigation_down,
        node.spec.navigation_left,
        node.spec.navigation_right,
      ] {
      if target != "" &&
        target != "Auto" &&
        target != "Stop" &&
        !planned_nodes.contains(target) {
        raise HostError::InvalidMutation(
          "SH1023",
          "navigation target does not exist: " + target,
        )
      }
    }
    if node.spec.kind == Image && node.spec.source.contains("#") {
      ignore(@atlas.resolve_texture_atlas_region(node.spec.source)) catch {
        error => raise HostError::InvalidMutation("SH1022", error.to_string())
      }
    }
    for group in node.spec.visual_state_groups {
      for state in group.states {
        for setter in state.setters {
          if !planned_nodes.contains(setter.target) {
            raise HostError::InvalidMutation(
              "SH1020",
              "visual-state target does not exist: " + setter.target,
            )
          }
          if !visual_state_setter_is_valid(setter) {
            raise HostError::InvalidMutation(
              "SH1021",
              "visual-state setter has an incompatible property/value: " +
              setter.property,
            )
          }
          match setter.value {
            StringValue(source) if setter.property == "Source" &&
              source.contains("#") =>
              ignore(@atlas.resolve_texture_atlas_region(source)) catch {
                error =>
                  raise HostError::InvalidMutation("SH1022", error.to_string())
              }
            _ => ()
          }
        }
      }
    }
  }
  let clear_focused_node = match @ui.focused_entity() {
    Some(target) =>
      match record.entity_keys.get(target) {
        Some(key) =>
          match planned_nodes.get(key) {
            Some(node) =>
              !node.spec.focusable ||
              !node.spec.active ||
              (node.spec.kind == Button && !node.spec.enabled)
            None => true
          }
        None => false
      }
    None => false
  }
  commit_validated_mutations(record, mutations)
  synchronize_focus_metadata(record)
  refresh_visual_states(record)
  if clear_focused_node {
    @ui.blur()
    current_store().last_focused = None
  }
}

///|
fn visual_state_setter_is_valid(setter : VisualStateSetter) -> Bool {
  match (setter.property, setter.value) {
    (
      "Source"
      | "Background"
      | "BorderColor"
      | "Color"
      | "OutlineColor",
      StringValue(_),
    ) => true
    (
      "Border"
      | "Radius"
      | "FontSize"
      | "Left"
      | "Top"
      | "OutlineWidth"
      | "OutlineOffset",
      DoubleValue(_),
    ) => true
    ("Bold", BoolValue(_)) => true
    ("Width" | "Height", LayoutValueValue(_)) => true
    _ => false
  }
}

///|
fn apply_visual_state_setter(
  spec : NodeSpec,
  setter : VisualStateSetter,
) -> NodeSpec {
  match (setter.property, setter.value) {
    ("Source", StringValue(value)) => { ..spec, source: value }
    ("Background", StringValue(value)) =>
      { ..spec, style: { ..spec.style, background: value } }
    ("BorderColor", StringValue(value)) =>
      { ..spec, style: { ..spec.style, border_color: value } }
    ("Color", StringValue(value)) =>
      { ..spec, style: { ..spec.style, color: value } }
    ("OutlineColor", StringValue(value)) =>
      { ..spec, style: { ..spec.style, outline_color: value } }
    ("Border", DoubleValue(value)) =>
      { ..spec, style: { ..spec.style, border: value } }
    ("Radius", DoubleValue(value)) =>
      { ..spec, style: { ..spec.style, radius: value } }
    ("FontSize", DoubleValue(value)) =>
      { ..spec, style: { ..spec.style, font_size: value } }
    ("Left", DoubleValue(value)) =>
      { ..spec, style: { ..spec.style, left: value } }
    ("Top", DoubleValue(value)) =>
      { ..spec, style: { ..spec.style, top: value } }
    ("OutlineWidth", DoubleValue(value)) =>
      { ..spec, style: { ..spec.style, outline_width: value } }
    ("OutlineOffset", DoubleValue(value)) =>
      { ..spec, style: { ..spec.style, outline_offset: value } }
    ("Bold", BoolValue(value)) =>
      { ..spec, style: { ..spec.style, bold: value } }
    ("Width", LayoutValueValue(value)) =>
      { ..spec, style: { ..spec.style, width: value } }
    ("Height", LayoutValueValue(value)) =>
      { ..spec, style: { ..spec.style, height: value } }
    _ => spec
  }
}

///|
fn visual_state_exists(group : VisualStateGroup, name : String) -> Bool {
  group.states.any(state => state.name == name)
}

///|
fn effective_visual_state(
  record : ViewRecord,
  owner : String,
  group : VisualStateGroup,
) -> String {
  if !group.interaction {
    if group.current != "" && visual_state_exists(group, group.current) {
      return group.current
    }
    return if visual_state_exists(group, "Normal") {
      "Normal"
    } else {
      group.states[0].name
    }
  }
  let node = record.nodes[owner]
  if !node.spec.enabled && visual_state_exists(group, "Disabled") {
    return "Disabled"
  }
  let target = record.entities[owner]
  if @ui.interactions().get(target) == Some(@ui.Interaction::Pressed) &&
    visual_state_exists(group, "Pressed") {
    return "Pressed"
  }
  if @ui.focuseds().contains(target) && visual_state_exists(group, "Focused") {
    return "Focused"
  }
  if @ui.interactions().get(target) == Some(@ui.Interaction::Hovered) &&
    visual_state_exists(group, "Hovered") {
    return "Hovered"
  }
  if visual_state_exists(group, "Normal") {
    "Normal"
  } else {
    group.states[0].name
  }
}

///|
fn visual_state_value(spec : NodeSpec, property : String) -> VisualStateValue? {
  let style = spec.style
  match property {
    "Source" => Some(StringValue(spec.source))
    "Background" => Some(StringValue(style.background))
    "BorderColor" => Some(StringValue(style.border_color))
    "Color" => Some(StringValue(style.color))
    "OutlineColor" => Some(StringValue(style.outline_color))
    "Border" => Some(DoubleValue(style.border))
    "Radius" => Some(DoubleValue(style.radius))
    "FontSize" => Some(DoubleValue(style.font_size))
    "Left" => Some(DoubleValue(style.left))
    "Top" => Some(DoubleValue(style.top))
    "OutlineWidth" => Some(DoubleValue(style.outline_width))
    "OutlineOffset" => Some(DoubleValue(style.outline_offset))
    "Bold" => Some(BoolValue(style.bold))
    "Width" => Some(LayoutValueValue(style.width))
    "Height" => Some(LayoutValueValue(style.height))
    _ => None
  }
}

///|
fn interpolate_visual_state_value(
  property : String,
  from : VisualStateValue,
  to : VisualStateValue,
  progress : Double,
  easing : String,
) -> VisualStateValue? {
  let linear = if progress < 0.0 {
    0.0
  } else if progress > 1.0 {
    1.0
  } else {
    progress
  }
  let amount = match easing {
    "EaseIn" => linear * linear
    "EaseOut" => 1.0 - (1.0 - linear) * (1.0 - linear)
    "EaseInOut" =>
      if linear < 0.5 {
        2.0 * linear * linear
      } else {
        1.0 - (-2.0 * linear + 2.0) * (-2.0 * linear + 2.0) / 2.0
      }
    _ => linear
  }
  match (from, to) {
    (DoubleValue(left), DoubleValue(right)) =>
      Some(DoubleValue(left + (right - left) * amount))
    (LayoutValueValue(Px(left)), LayoutValueValue(Px(right))) =>
      Some(LayoutValueValue(Px(left + (right - left) * amount)))
    (LayoutValueValue(Percent(left)), LayoutValueValue(Percent(right))) =>
      Some(LayoutValueValue(Percent(left + (right - left) * amount)))
    (StringValue(left), StringValue(right)) if [
        "Background", "BorderColor", "Color", "OutlineColor",
      ].contains(property) => {
      let left_color = @ui.BackgroundColor::from_css(left).color
      let right_color = @ui.BackgroundColor::from_css(right).color
      let red = (left_color.r.to_double() +
        (right_color.r.to_double() - left_color.r.to_double()) * amount)
        .round()
        .to_int()
      let green = (left_color.g.to_double() +
        (right_color.g.to_double() - left_color.g.to_double()) * amount)
        .round()
        .to_int()
      let blue = (left_color.b.to_double() +
        (right_color.b.to_double() - left_color.b.to_double()) * amount)
        .round()
        .to_int()
      let alpha = left_color.a + (right_color.a - left_color.a) * amount
      Some(
        StringValue(
          "rgba(" +
          red.to_string() +
          "," +
          green.to_string() +
          "," +
          blue.to_string() +
          "," +
          alpha.to_string() +
          ")",
        ),
      )
    }
    _ => None
  }
}

///|
fn refresh_visual_states(record : ViewRecord) -> Unit {
  let effective : Map[String, NodeSpec] = Map([])
  let groups : Array[(Int, String, VisualStateGroup)] = []
  for key, node in record.nodes {
    effective[key] = node.spec
    for group in node.spec.visual_state_groups {
      groups.push((group.order, key, group))
    }
  }
  groups.sort_by(fn(left, right) {
    let order = left.0 - right.0
    if order != 0 {
      order
    } else {
      left.1.compare(right.1)
    }
  })
  let now = @time.elapsed()
  for entry in groups {
    let (_, owner, group) = entry
    let current = effective_visual_state(record, owner, group)
    let state_key = owner + "\u{1f}" + group.name
    match record.visual_states.get(state_key) {
      Some(previous) if previous != current => {
        let mut selected_transition : VisualTransition? = None
        let mut selected_score = -1
        for transition in group.transitions {
          let from_matches = transition.from is None ||
            transition.from == Some(previous)
          let to_matches = transition.to is None ||
            transition.to == Some(current)
          if from_matches && to_matches {
            let score = (if transition.from is Some(_) { 2 } else { 0 }) +
              (if transition.to is Some(_) { 1 } else { 0 })
            if score > selected_score {
              selected_transition = Some(transition)
              selected_score = score
            }
          }
        }
        match selected_transition {
          Some(transition) if transition.duration > 0.0 ||
            transition.delay > 0.0 =>
            for state in group.states {
              if state.name == current {
                for setter in state.setters {
                  let transition_key = setter.target +
                    "\u{1f}" +
                    setter.property
                  record.visual_transitions.remove(transition_key)
                  match record.nodes.get(setter.target) {
                    Some(target_node) =>
                      match
                        visual_state_value(
                          target_node.effective_spec,
                          setter.property,
                        ) {
                        Some(from) =>
                          match
                            interpolate_visual_state_value(
                              setter.property,
                              from,
                              setter.value,
                              0.0,
                              transition.easing,
                            ) {
                            Some(_) =>
                              record.visual_transitions[transition_key] = {
                                target: setter.target,
                                property: setter.property,
                                from,
                                to: setter.value,
                                start: now,
                                duration: transition.duration,
                                delay: transition.delay,
                                easing: transition.easing,
                              }
                            None => ()
                          }
                        None => ()
                      }
                    None => ()
                  }
                }
                break
              }
            }
          _ => ()
        }
        record.visual_states[state_key] = current
      }
      Some(_) => ()
      None => record.visual_states[state_key] = current
    }
    for state in group.states {
      if state.name == current {
        for setter in state.setters {
          match effective.get(setter.target) {
            Some(spec) =>
              effective[setter.target] = apply_visual_state_setter(spec, setter)
            None => ()
          }
        }
        break
      }
    }
  }
  let completed : Array[String] = []
  for key, transition in record.visual_transitions {
    match effective.get(transition.target) {
      Some(spec) => {
        let elapsed = now - transition.start - transition.delay
        if elapsed >= transition.duration {
          completed.push(key)
        } else {
          let progress = if transition.duration <= 0.0 {
            0.0
          } else {
            elapsed / transition.duration
          }
          match
            interpolate_visual_state_value(
              transition.property,
              transition.from,
              transition.to,
              progress,
              transition.easing,
            ) {
            Some(value) =>
              effective[transition.target] = apply_visual_state_setter(spec, {
                target: transition.target,
                property: transition.property,
                value,
              })
            None => completed.push(key)
          }
        }
      }
      None => completed.push(key)
    }
  }
  for key in completed {
    record.visual_transitions.remove(key)
  }
  for key, spec in effective {
    let node = record.nodes[key]
    if node.effective_spec != spec {
      write_visual_state_delta(record.entities[key], node.effective_spec, spec)
      record.nodes[key] = { ..node, effective_spec: spec }
    }
  }
}

///|
fn write_visual_state_delta(
  target : @entity.Entity,
  previous : NodeSpec,
  current : NodeSpec,
) -> Unit {
  let before = previous.style
  let after = current.style
  if before.background != after.background {
    if after.background == "" {
      @ui.background_colors().remove(target)
    } else {
      @ui.background_colors()[target] = @ui.BackgroundColor::from_css(
        after.background,
      )
    }
  }
  if before.border_color != after.border_color {
    if after.border_color == "" {
      @ui.border_colors().remove(target)
    } else {
      @ui.border_colors()[target] = @ui.BorderColor::from_css(
        after.border_color,
      )
    }
  }
  if before.radius != after.radius {
    if after.radius == 0.0 {
      @ui.border_radii().remove(target)
    } else {
      @ui.border_radii()[target] = @ui.BorderRadius::all(
        @ui.Val::Px(after.radius),
      )
    }
  }
  if before.outline_color != after.outline_color ||
    before.outline_width != after.outline_width ||
    before.outline_offset != after.outline_offset {
    if after.outline_width == 0.0 || after.outline_color == "" {
      @ui.outlines().remove(target)
    } else {
      @ui.outlines()[target] = @ui.Outline(
        @ui.Val::Px(after.outline_width),
        @ui.BackgroundColor::from_css(after.outline_color).color,
        offset=@ui.Val::Px(after.outline_offset),
      )
    }
  }
  if current.kind == Text && before.color != after.color {
    if after.color == "" {
      @ui.text_colors().remove(target)
    } else {
      @ui.text_colors()[target] = @ui.TextColor::from_css(after.color)
    }
  }
  if current.kind == Text &&
    (before.font_size != after.font_size || before.bold != after.bold) {
    @ui.text_fonts()[target] = {
      ..@ui.text_fonts()[target],
      size: after.font_size,
      bold: after.bold,
    }
  }
  if current.kind == Image &&
    (previous.source != current.source || before.fit != after.fit) {
    @ui.ui_images()[target] = ui_image_from_source(
      current.source,
      match after.fit {
        Fill => @ui.ImageFit::Stretch
        Contain => @ui.ImageFit::Contain
        Cover => @ui.ImageFit::Cover
      },
    )
  }
  if before.left != after.left ||
    before.top != after.top ||
    before.width != after.width ||
    before.height != after.height ||
    before.border != after.border {
    @ui.nodes()[target] = {
      ..@ui.nodes()[target],
      left: @ui.Val::Px(after.left),
      top: @ui.Val::Px(after.top),
      width: match after.width {
        Auto => @ui.Val::Auto
        Px(value) => @ui.Val::Px(value)
        Percent(value) => @ui.Val::Percent(value)
      },
      height: match after.height {
        Auto => @ui.Val::Auto
        Px(value) => @ui.Val::Px(value)
        Percent(value) => @ui.Val::Percent(value)
      },
      border: @ui.UiRectValues::all(after.border),
    }
  }
}

///|
fn ui_image_from_source(source : String, fit : @ui.ImageFit) -> @ui.UiImage {
  if source.contains("#") {
    let resolved = @atlas.resolve_texture_atlas_region(source) catch {
      _ => return @ui.UiImage(source, fit~)
    }
    return @ui.UiImage::from_image(
      resolved.image,
      fit~,
      source=Some(resolved.source),
    )
  }
  @ui.UiImage(source, fit~)
}

///|
fn synchronize_focus_metadata(record : ViewRecord) -> Unit {
  let ordered_keys : Array[String] = []
  let pending : Array[String] = []
  for index = record.roots.length() - 1; index >= 0; index = index - 1 {
    pending.push(record.roots[index])
  }
  while !pending.is_empty() {
    let key = pending.pop().unwrap()
    ordered_keys.push(key)
    let children = record.nodes[key].children
    for index = children.length() - 1; index >= 0; index = index - 1 {
      pending.push(children[index])
    }
  }
  let resolve_rule = fn(value : String) {
    if value == "" || value == "Auto" {
      @ui.UiNavigationRule::Auto
    } else if value == "Stop" {
      @ui.UiNavigationRule::Stop
    } else {
      @ui.UiNavigationRule::Explicit(record.entities[value])
    }
  }
  for key in ordered_keys {
    let spec = record.nodes[key].spec
    let target = record.entities[key]
    if spec.navigation_up == "" &&
      spec.navigation_down == "" &&
      spec.navigation_left == "" &&
      spec.navigation_right == "" {
      @ui.navigation_links().remove(target)
    } else {
      @ui.navigation_links()[target] = @ui.UiNavigationLinks(
        up=resolve_rule(spec.navigation_up),
        down=resolve_rule(spec.navigation_down),
        left=resolve_rule(spec.navigation_left),
        right=resolve_rule(spec.navigation_right),
      )
    }
  }
  let desired_scopes : Array[@ui.FocusScope] = []
  for scope_key in ordered_keys {
    let scope_node = record.nodes[scope_key]
    guard scope_node.spec.focus_scope && scope_node.spec.active else {
      continue
    }
    let mut initial_focus : @entity.Entity? = None
    for candidate_key in ordered_keys {
      let candidate = record.nodes[candidate_key]
      guard candidate.spec.auto_focus &&
        candidate.spec.focusable &&
        candidate.spec.active else {
        continue
      }
      let mut ancestor : String? = Some(candidate_key)
      while ancestor is Some(key) {
        if key == scope_key {
          initial_focus = Some(record.entities[candidate_key])
          break
        }
        if key != candidate_key && record.nodes[key].spec.focus_scope {
          break
        }
        ancestor = record.nodes[key].spec.parent
      }
      if initial_focus is Some(_) {
        break
      }
    }
    desired_scopes.push(
      @ui.FocusScope(record.entities[scope_key], initial_focus~),
    )
  }
  let scopes = @ui.focus_scopes()
  let mut insertion_index = scopes.length()
  let mut index = scopes.length() - 1
  while index >= 0 {
    if record.active_focus_scopes.contains(scopes[index].root) {
      insertion_index = index
      ignore(scopes.remove(index))
    }
    index = index - 1
  }
  if insertion_index > scopes.length() {
    insertion_index = scopes.length()
  }
  for offset, scope in desired_scopes {
    scopes.insert(insertion_index + offset, scope)
  }
  record.active_focus_scopes.clear()
  for scope in desired_scopes {
    record.active_focus_scopes.push(scope.root)
  }
}

///|
fn commit_validated_mutations(
  record : ViewRecord,
  mutations : Array[TreeMutation],
) -> Unit {
  for mutation in mutations {
    match mutation {
      Mount(spec) => {
        let target = @entity.Entity()
        record.entities[spec.key] = target
        record.entity_keys[target] = spec.key
        record.nodes[spec.key] = { spec, effective_spec: spec, children: [] }
        match spec.parent {
          Some(parent) => record.nodes[parent].children.push(spec.key)
          None => record.roots.push(spec.key)
        }
        write_node_components(target, spec)
        target.set_parent(
          spec.parent.map_or(record.container, parent => record.entities[parent]),
        )
      }
      Update(spec) => {
        let previous = record.nodes[spec.key]
        record.nodes[spec.key] = {
          spec,
          effective_spec: previous.effective_spec,
          children: previous.children,
        }
        write_node_components(record.entities[spec.key], spec)
      }
      SetText(key, value) => {
        let node = record.nodes[key]
        record.nodes[key] = { ..node, spec: { ..node.spec, text: value } }
        @ui.texts()[record.entities[key]].content = value
      }
      SetSource(key, value) => {
        let node = record.nodes[key]
        let style = node.spec.style
        record.nodes[key] = { ..node, spec: { ..node.spec, source: value } }
        @ui.ui_images()[record.entities[key]] = ui_image_from_source(
          value,
          match style.fit {
            Fill => @ui.ImageFit::Stretch
            Contain => @ui.ImageFit::Contain
            Cover => @ui.ImageFit::Cover
          },
        )
      }
      SetBackground(key, value) => {
        let node = record.nodes[key]
        record.nodes[key] = {
          ..node,
          spec: { ..node.spec, style: { ..node.spec.style, background: value } },
        }
        if value == "" {
          @ui.background_colors().remove(record.entities[key])
        } else {
          @ui.background_colors()[record.entities[key]] = @ui.BackgroundColor::from_css(
            value,
          )
        }
      }
      SetActive(key, value) => {
        let node = record.nodes[key]
        let target = record.entities[key]
        record.nodes[key] = { ..node, spec: { ..node.spec, active: value } }
        @ui.nodes()[target] = { ..@ui.nodes()[target], active: value }
        if node.spec.focusable &&
          value &&
          (node.spec.kind != Button || node.spec.enabled) {
          @ui.focusables()[target] = @ui.Focusable()
          @ui.tab_indexes()[target] = @ui.TabIndex(node.spec.tab_index)
        } else {
          @ui.focusables().remove(target)
          @ui.tab_indexes().remove(target)
        }
      }
      SetEnabled(key, value) => {
        let node = record.nodes[key]
        let target = record.entities[key]
        record.nodes[key] = { ..node, spec: { ..node.spec, enabled: value } }
        @ui.buttons()[target] = @ui.Button(enabled=value)
        if node.spec.focusable && node.spec.active && value {
          @ui.focusables()[target] = @ui.Focusable()
          @ui.tab_indexes()[target] = @ui.TabIndex(node.spec.tab_index)
        } else {
          @ui.focusables().remove(target)
          @ui.tab_indexes().remove(target)
        }
      }
      SetTop(key, value) => {
        let node = record.nodes[key]
        let target = record.entities[key]
        record.nodes[key] = {
          ..node,
          spec: { ..node.spec, style: { ..node.spec.style, top: value } },
        }
        @ui.nodes()[target] = { ..@ui.nodes()[target], top: @ui.Val::Px(value) }
      }
      Move(key, parent, index) => {
        let node = record.nodes[key]
        match node.spec.parent {
          Some(old_parent) => {
            let siblings = record.nodes[old_parent].children
            for old_index, sibling in siblings {
              if sibling == key {
                ignore(siblings.remove(old_index))
                break
              }
            }
          }
          None =>
            for old_index, root in record.roots {
              if root == key {
                ignore(record.roots.remove(old_index))
                break
              }
            }
        }
        record.nodes[parent].children.insert(index, key)
        record.nodes[key] = {
          ..node,
          spec: { ..node.spec, parent: Some(parent) },
        }
        let target = record.entities[key]
        let parent_entity = record.entities[parent]
        target.remove_parent()
        let siblings = parent_entity.get_children().copy()
        for sibling_index = index
            sibling_index < siblings.length()
            sibling_index = sibling_index + 1 {
          siblings[sibling_index].remove_parent()
        }
        target.set_parent(parent_entity)
        for sibling_index = index
            sibling_index < siblings.length()
            sibling_index = sibling_index + 1 {
          siblings[sibling_index].set_parent(parent_entity)
        }
      }
      Remove(key) => {
        let node = record.nodes[key]
        match node.spec.parent {
          Some(parent) => {
            let siblings = record.nodes[parent].children
            for child_index, child in siblings {
              if child == key {
                ignore(siblings.remove(child_index))
                break
              }
            }
          }
          None =>
            for root_index, root in record.roots {
              if root == key {
                ignore(record.roots.remove(root_index))
                break
              }
            }
        }
        let removed_root = record.entities[key]
        let pending = [key]
        while pending.length() > 0 {
          let removed = pending.pop().unwrap()
          for child in record.nodes[removed].children {
            pending.push(child)
          }
          let target = record.entities[removed]
          remove_ui_components(target)
          record.entity_keys.remove(target)
          record.entities.remove(removed)
          record.nodes.remove(removed)
        }
        removed_root.remove_parent()
        removed_root.destroy()
      }
    }
  }
}

///|
fn grid_track_to_ui(track : GridTrack) -> @ui.GridTrack {
  match track {
    Auto => @ui.GridTrack::Auto
    Px(value) => @ui.GridTrack::Px(value)
    Percent(value) => @ui.GridTrack::Percent(value)
    Fr(value) => @ui.GridTrack::Fr(value)
    MinContent => @ui.GridTrack::MinContent
    MaxContent => @ui.GridTrack::MaxContent
    FitContent(value) => @ui.GridTrack::FitContent(grid_track_to_ui(value))
    MinMax(minimum, maximum) =>
      @ui.GridTrack::MinMax(
        grid_track_to_ui(minimum),
        grid_track_to_ui(maximum),
      )
    Repeat(repetition, tracks) =>
      @ui.GridTrack::Repeat(
        match repetition {
          Count(value) => @ui.GridTrackRepetition::Count(value)
          AutoFill => @ui.GridTrackRepetition::AutoFill
          AutoFit => @ui.GridTrackRepetition::AutoFit
        },
        tracks.map(grid_track_to_ui),
      )
  }
}

///|
fn write_node_components(target : @entity.Entity, spec : NodeSpec) -> Unit {
  let style = spec.style
  @ui.nodes()[target] = @ui.Node(
    width=match style.width {
      Auto => @ui.Val::Auto
      Px(value) => @ui.Val::Px(value)
      Percent(value) => @ui.Val::Percent(value)
    },
    height=match style.height {
      Auto => @ui.Val::Auto
      Px(value) => @ui.Val::Px(value)
      Percent(value) => @ui.Val::Percent(value)
    },
    left=@ui.Val::Px(style.left),
    top=@ui.Val::Px(style.top),
    margin=@ui.UiRectValues::px(
      left=style.margin_left,
      top=style.margin_top,
      right=style.margin_right,
      bottom=style.margin_bottom,
    ),
    padding=@ui.UiRectValues::px(
      left=style.padding_left,
      top=style.padding_top,
      right=style.padding_right,
      bottom=style.padding_bottom,
    ),
    border=@ui.UiRectValues::all(style.border),
    display=if spec.kind == Grid {
      @ui.Display::Grid
    } else {
      @ui.Display::Flex
    },
    position_type=if style.absolute { @ui.Absolute } else { @ui.Relative },
    flex_direction=match style.direction {
      Row => @ui.FlexDirection::Row
      RowReverse => @ui.FlexDirection::RowReverse
      Column => @ui.FlexDirection::Column
      ColumnReverse => @ui.FlexDirection::ColumnReverse
    },
    flex_basis=match style.flex_basis {
      Auto => @ui.Val::Auto
      Px(value) => @ui.Val::Px(value)
      Percent(value) => @ui.Val::Percent(value)
    },
    flex_grow=style.flex_grow,
    flex_shrink=style.flex_shrink,
    row_gap=style.row_gap,
    column_gap=style.column_gap,
    grid_template_rows=style.grid_rows.map(grid_track_to_ui),
    grid_template_columns=style.grid_columns.map(grid_track_to_ui),
    grid_auto_flow=match style.grid_auto_flow {
      Row => @ui.GridAutoFlow::Row
      Column => @ui.GridAutoFlow::Column
      RowDense => @ui.GridAutoFlow::RowDense
      ColumnDense => @ui.GridAutoFlow::ColumnDense
    },
    grid_row=@ui.GridLine(
      start=style.grid_row.map_or(@ui.GridPlacement::Auto, row => {
        @ui.GridPlacement::Line(row + 1)
      }),
      end=if style.grid_row_span == 1 {
        @ui.GridPlacement::Auto
      } else {
        @ui.GridPlacement::Span(style.grid_row_span)
      },
    ),
    grid_column=@ui.GridLine(
      start=style.grid_column.map_or(@ui.GridPlacement::Auto, column => {
        @ui.GridPlacement::Line(column + 1)
      }),
      end=if style.grid_column_span == 1 {
        @ui.GridPlacement::Auto
      } else {
        @ui.GridPlacement::Span(style.grid_column_span)
      },
    ),
    overflow_x=if style.horizontal_scroll { @ui.Scroll } else { @ui.Visible },
    overflow_y=if style.vertical_scroll { @ui.Scroll } else { @ui.Visible },
    scrollbar_width=style.scrollbar_width,
    active=spec.active,
  )
  if style.background == "" {
    @ui.background_colors().remove(target)
  } else {
    @ui.background_colors()[target] = @ui.BackgroundColor::from_css(
      style.background,
    )
  }
  if style.border_color == "" {
    @ui.border_colors().remove(target)
  } else {
    @ui.border_colors()[target] = @ui.BorderColor::from_css(style.border_color)
  }
  if style.radius == 0.0 {
    @ui.border_radii().remove(target)
  } else {
    @ui.border_radii()[target] = @ui.BorderRadius::all(
      @ui.Val::Px(style.radius),
    )
  }
  if style.outline_width == 0.0 || style.outline_color == "" {
    @ui.outlines().remove(target)
  } else {
    @ui.outlines()[target] = @ui.Outline(
      @ui.Val::Px(style.outline_width),
      @ui.BackgroundColor::from_css(style.outline_color).color,
      offset=@ui.Val::Px(style.outline_offset),
    )
  }
  if style.z_index == 0 {
    @ui.z_indexes().remove(target)
  } else {
    @ui.z_indexes()[target] = @ui.ZIndex(style.z_index)
  }
  @ui.texts().remove(target)
  @ui.text_colors().remove(target)
  @ui.text_fonts().remove(target)
  @ui.text_layouts().remove(target)
  @ui.ui_images().remove(target)
  @ui.buttons().remove(target)
  @ui.focusables().remove(target)
  if spec.kind != ScrollView {
    @ui.scroll_positions().remove(target)
  }
  match spec.kind {
    Text => {
      @ui.texts()[target] = @ui.Text(spec.text)
      if style.color != "" {
        @ui.text_colors()[target] = @ui.TextColor::from_css(style.color)
      }
      @ui.text_fonts()[target] = @ui.TextFont(
        family=style.font_family,
        size=style.font_size,
        bold=style.bold,
      )
      @ui.text_layouts()[target] = @ui.TextLayout(
        align=match style.align {
          Left => @math.Left
          Center => @math.Center
          Right => @math.Right
        },
        wrap=if style.wrap { @ui.WordWrap } else { @ui.NoWrap },
      )
    }
    Image => {
      let fit : @ui.ImageFit = match style.fit {
        Fill => @ui.ImageFit::Stretch
        Contain => @ui.ImageFit::Contain
        Cover => @ui.ImageFit::Cover
      }
      @ui.ui_images()[target] = ui_image_from_source(spec.source, fit)
    }
    Button => @ui.buttons()[target] = @ui.Button(enabled=spec.enabled)
    ScrollView =>
      if !@ui.scroll_positions().contains(target) {
        @ui.scroll_positions()[target] = @ui.ScrollPosition::zero()
      }
    View | Flex | Grid => ()
  }
  if spec.focusable && spec.active && (spec.kind != Button || spec.enabled) {
    @ui.focusables()[target] = @ui.Focusable()
    @ui.tab_indexes()[target] = @ui.TabIndex(spec.tab_index)
  } else {
    @ui.tab_indexes().remove(target)
  }
}

///|
fn remove_ui_components(target : @entity.Entity) -> Unit {
  @ui.nodes().remove(target)
  @ui.background_colors().remove(target)
  @ui.border_colors().remove(target)
  @ui.border_radii().remove(target)
  @ui.outlines().remove(target)
  @ui.z_indexes().remove(target)
  @ui.texts().remove(target)
  @ui.text_colors().remove(target)
  @ui.text_fonts().remove(target)
  @ui.text_layouts().remove(target)
  @ui.ui_images().remove(target)
  @ui.buttons().remove(target)
  @ui.focusables().remove(target)
  @ui.focuseds().remove(target)
  @ui.tab_indexes().remove(target)
  @ui.navigation_links().remove(target)
  @ui.scroll_positions().remove(target)
}

///|
fn route_view_events(_world : @ecs.World) -> Unit {
  let store = current_store()
  let dead_views : Array[@entity.Entity] = []
  for entity, _ in store.views {
    if !entity.is_alive() {
      dead_views.push(entity)
    }
  }
  for entity in dead_views {
    store.views.remove(entity)
  }
  for click in view_click_reader.read(@ui.click_event_bus) {
    for entity, view in store.views {
      match view.entity_keys.get(click.entity) {
        Some(key) =>
          view_event_bus.send({ entity, event: { kind: Click, key } })
        None => ()
      }
    }
  }
  let focused = @ui.focused_entity()
  if focused != store.last_focused {
    store.last_focused = focused
    match focused {
      Some(target) =>
        for entity, view in store.views {
          match view.entity_keys.get(target) {
            Some(key) =>
              view_event_bus.send({ entity, event: { kind: Focus, key } })
            None => ()
          }
        }
      None => ()
    }
  }
}

///|
fn refresh_view_visual_states(_world : @ecs.World) -> Unit {
  for _, record in current_store().views {
    refresh_visual_states(record)
  }
}

///|
pub fn plugin(app : @app.App) -> @app.App {
  app
  .add_message(view_event_bus)
  .add_system(
    @system.PostUpdate,
    refresh_view_visual_states,
    system_name="selene_ui_visual_states",
  )
  .add_system(
    @system.PostUpdate,
    route_view_events,
    system_name="selene_ui_view_events",
  )
}
