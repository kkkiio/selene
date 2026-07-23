///|
priv struct NativeBridgeStyle {
  absolute : Bool
  left : Double
  top : Double
  width_kind : String
  width_value : Double
  height_kind : String
  height_value : Double
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
  align : String
  wrap : Bool
  z_index : Int
  fit : String
  direction : String
  flex_basis_kind : String
  flex_basis_value : Double
  flex_grow : Double
  flex_shrink : Double
  row_gap : Double
  column_gap : Double
  horizontal_scroll : Bool
  vertical_scroll : Bool
  scrollbar_width : Double
} derive(FromJson)

///|
priv struct NativeBridgeNodeSpec {
  key : String
  parent : String
  kind : String
  text : String
  source : String
  active : Bool
  enabled : Bool
  focusable : Bool
  style : NativeBridgeStyle
  visual_state_groups : Array[NativeBridgeVisualStateGroup]
} derive(FromJson)

///|
priv struct NativeBridgeVisualStateValue {
  tag : String
  string_value : String
  bool_value : Bool
  number_value : Double
  layout_kind : String
  layout_value : Double
} derive(FromJson)

///|
priv struct NativeBridgeVisualStateSetter {
  target : String
  property : String
  value : NativeBridgeVisualStateValue
} derive(FromJson)

///|
priv struct NativeBridgeVisualStateDefinition {
  name : String
  setters : Array[NativeBridgeVisualStateSetter]
} derive(FromJson)

///|
priv struct NativeBridgeVisualTransition {
  from : String
  to : String
  duration : Double
  delay : Double
  easing : String
} derive(FromJson)

///|
priv struct NativeBridgeVisualStateGroup {
  order : Int
  name : String
  current : String
  interaction : Bool
  states : Array[NativeBridgeVisualStateDefinition]
  transitions : Array[NativeBridgeVisualTransition]
} derive(FromJson)

///|
fn native_visual_state_value(
  value : NativeBridgeVisualStateValue,
) -> @ui_host.VisualStateValue {
  match value.tag {
    "string" => StringValue(value.string_value)
    "bool" => BoolValue(value.bool_value)
    "double" => DoubleValue(value.number_value)
    "int" => IntValue(value.number_value.to_int())
    "layout" =>
      LayoutValueValue(
        match value.layout_kind {
          "px" => @ui_host.LayoutValue::Px(value.layout_value)
          "percent" => Percent(value.layout_value)
          _ => Auto
        },
      )
    _ => StringValue("")
  }
}

///|
fn native_visual_state_groups(
  groups : Array[NativeBridgeVisualStateGroup],
) -> Array[@ui_host.VisualStateGroup] {
  groups.map(group => {
    order: group.order,
    name: group.name,
    current: group.current,
    interaction: group.interaction,
    states: group.states.map(state => {
      name: state.name,
      setters: state.setters.map(setter => {
        target: setter.target,
        property: setter.property,
        value: native_visual_state_value(setter.value),
      }),
    }),
    transitions: group.transitions.map(transition => {
      from: if transition.from == "" {
        None
      } else {
        Some(transition.from)
      },
      to: if transition.to == "" {
        None
      } else {
        Some(transition.to)
      },
      duration: transition.duration,
      delay: transition.delay,
      easing: transition.easing,
    }),
  })
}

///|
priv struct NativeBridgeMutation {
  tag : String
  key : String
  text_value : String
  bool_value : Bool
  number_value : Double
  parent : String
  index : Int
  spec : Json
} derive(FromJson)

///|
pub(all) enum NativeComponentKind {
  Survivors
} derive(Eq, Debug)

///|
pub suberror NativeComponentLoaderError {
  NativeComponentLoaderError(String)
} derive(Eq, Debug)

///|
pub impl Show for NativeComponentLoaderError with fn output(self, logger) {
  match self {
    NativeComponentLoaderError(message) => logger.write_string(message)
  }
}

///|
pub struct NativeUiComponent {
  handle : UInt64
  world_id : UInt
  entities : Set[@entity.Entity]
  mut unloaded : Bool
}

///|
priv struct NativeBridgeView {
  entity : @entity.Entity
  host : @component_host.SeleneHost
  mut mounted : Bool
}

///|
let native_views : Map[UInt, Map[UInt, NativeBridgeView]] = Map([])

///|
let native_callbacks_installed : Ref[Bool] = { val: false }

///|
extern "C" fn register_native_host_callbacks(
  apply_callback : FuncRef[(UInt, Bytes) -> Int],
) -> Unit = "selene_component_loader_register_host"

///|
#borrow(path)
extern "C" fn native_load(kind : Int, path : Bytes) -> UInt64 = "selene_component_loader_load"

///|
#borrow(payload)
extern "C" fn native_mount(
  component : UInt64,
  entity : UInt,
  payload : Bytes,
) -> Int = "selene_component_loader_mount"

///|
#borrow(payload)
extern "C" fn native_replace(
  component : UInt64,
  entity : UInt,
  payload : Bytes,
) -> Int = "selene_component_loader_replace"

///|
#borrow(payload)
extern "C" fn native_apply(
  component : UInt64,
  entity : UInt,
  payload : Bytes,
) -> Int = "selene_component_loader_apply"

///|
#borrow(payload)
extern "C" fn native_handle_event(
  component : UInt64,
  entity : UInt,
  payload : Bytes,
) -> Int = "selene_component_loader_handle_event"

///|
extern "C" fn native_update(component : UInt64) -> Int = "selene_component_loader_update"

///|
extern "C" fn native_unmount(component : UInt64, entity : UInt) -> Int = "selene_component_loader_unmount"

///|
extern "C" fn native_unload(component : UInt64) -> Int = "selene_component_loader_unload"

///|
extern "C" fn native_last_error() -> Bytes = "selene_component_loader_last_error"

///|
extern "C" fn native_last_result() -> Bytes = "selene_component_loader_last_result"

///|
fn apply_native_host_batch(entity_id : UInt, payload : Bytes) -> Int {
  let world_id = @ecs.require_current_world().id()
  guard native_views.get(world_id) is Some(world_views) &&
    world_views.get(entity_id) is Some(view) else {
    return 1
  }
  try {
    let decoded : Array[NativeBridgeMutation] = @json.from_json(
      @json.parse(@utf8.decode(payload)),
    )
    let mutations : Array[@ui_host.TreeMutation] = []
    for mutation in decoded {
      match mutation.tag {
        "mount" | "update" => {
          let value : NativeBridgeNodeSpec = @json.from_json(mutation.spec)
          let kind = match value.kind {
            "view" => @ui_host.NodeKind::View
            "flex" => @ui_host.NodeKind::Flex
            "text" => @ui_host.NodeKind::Text
            "image" => @ui_host.NodeKind::Image
            "button" => @ui_host.NodeKind::Button
            "scroll-view" => @ui_host.NodeKind::ScrollView
            _ => return 1
          }
          let align = match value.style.align {
            "center" => @ui_host.TextAlign::Center
            "right" => @ui_host.TextAlign::Right
            _ => @ui_host.TextAlign::Left
          }
          let fit = match value.style.fit {
            "contain" => @ui_host.ImageFit::Contain
            "cover" => @ui_host.ImageFit::Cover
            _ => @ui_host.ImageFit::Fill
          }
          let direction = match value.style.direction {
            "row" => @ui_host.FlexDirection::Row
            "row-reverse" => @ui_host.FlexDirection::RowReverse
            "column-reverse" => @ui_host.FlexDirection::ColumnReverse
            _ => @ui_host.FlexDirection::Column
          }
          let spec : @ui_host.NodeSpec = {
            key: value.key,
            parent: if value.parent == "" {
              None
            } else {
              Some(value.parent)
            },
            kind,
            text: value.text,
            source: value.source,
            active: value.active,
            enabled: value.enabled,
            focusable: value.focusable,
            visual_state_groups: native_visual_state_groups(
              value.visual_state_groups,
            ),
            style: {
              absolute: value.style.absolute,
              left: value.style.left,
              top: value.style.top,
              width: match value.style.width_kind {
                "px" => @ui_host.LayoutValue::Px(value.style.width_value)
                "percent" => Percent(value.style.width_value)
                _ => Auto
              },
              height: match value.style.height_kind {
                "px" => @ui_host.LayoutValue::Px(value.style.height_value)
                "percent" => Percent(value.style.height_value)
                _ => Auto
              },
              margin_left: value.style.margin_left,
              margin_top: value.style.margin_top,
              margin_right: value.style.margin_right,
              margin_bottom: value.style.margin_bottom,
              padding_left: value.style.padding_left,
              padding_top: value.style.padding_top,
              padding_right: value.style.padding_right,
              padding_bottom: value.style.padding_bottom,
              background: value.style.background,
              border_color: value.style.border_color,
              border: value.style.border,
              radius: value.style.radius,
              outline_color: value.style.outline_color,
              outline_width: value.style.outline_width,
              outline_offset: value.style.outline_offset,
              color: value.style.color,
              font_family: value.style.font_family,
              font_size: value.style.font_size,
              bold: value.style.bold,
              align,
              wrap: value.style.wrap,
              z_index: value.style.z_index,
              fit,
              direction,
              flex_basis: match value.style.flex_basis_kind {
                "px" => @ui_host.LayoutValue::Px(value.style.flex_basis_value)
                "percent" => Percent(value.style.flex_basis_value)
                _ => Auto
              },
              flex_grow: value.style.flex_grow,
              flex_shrink: value.style.flex_shrink,
              row_gap: value.style.row_gap,
              column_gap: value.style.column_gap,
              horizontal_scroll: value.style.horizontal_scroll,
              vertical_scroll: value.style.vertical_scroll,
              scrollbar_width: value.style.scrollbar_width,
            },
          }
          mutations.push(
            if mutation.tag == "mount" {
              @ui_host.TreeMutation::Mount(spec)
            } else {
              @ui_host.TreeMutation::Update(spec)
            },
          )
        }
        "set-text" => mutations.push(SetText(mutation.key, mutation.text_value))
        "set-source" =>
          mutations.push(SetSource(mutation.key, mutation.text_value))
        "set-background" =>
          mutations.push(SetBackground(mutation.key, mutation.text_value))
        "set-active" =>
          mutations.push(SetActive(mutation.key, mutation.bool_value))
        "set-enabled" =>
          mutations.push(SetEnabled(mutation.key, mutation.bool_value))
        "set-top" => mutations.push(SetTop(mutation.key, mutation.number_value))
        "move" =>
          mutations.push(Move(mutation.key, mutation.parent, mutation.index))
        "remove" => mutations.push(Remove(mutation.key))
        _ => return 1
      }
    }
    if view.mounted {
      view.host.apply(view.entity, mutations)
    } else {
      let specs : Array[@ui_host.NodeSpec] = []
      for mutation in mutations {
        match mutation {
          Mount(spec) => specs.push(spec)
          _ => return 1
        }
      }
      view.host.mount(view.entity, specs)
      view.mounted = true
    }
    0
  } catch {
    error => {
      println(
        "Selene native Host rejected a mutation batch: " + error.to_string(),
      )
      1
    }
  }
}

///|
fn install_native_host_callbacks() -> Unit {
  if native_callbacks_installed.val {
    return
  }
  register_native_host_callbacks(fn(entity, payload) {
    apply_native_host_batch(entity, payload)
  })
  native_callbacks_installed.val = true
}

///|
fn require_native_success(
  status : Int,
) -> Unit raise NativeComponentLoaderError {
  if status == 0 {
    raise NativeComponentLoaderError(@utf8.decode_lossy(native_last_error()))
  }
}

///|
pub fn NativeUiComponent::load(
  kind : NativeComponentKind,
  path : String,
) -> NativeUiComponent raise NativeComponentLoaderError {
  install_native_host_callbacks()
  let handle = native_load(
    match kind {
      Survivors => 1
    },
    @utf8.encode(path),
  )
  if handle == 0UL {
    raise NativeComponentLoaderError(@utf8.decode_lossy(native_last_error()))
  }
  {
    handle,
    world_id: @ecs.require_current_world().id(),
    entities: Set([]),
    unloaded: false,
  }
}

///|
pub fn NativeUiComponent::mount(
  self : NativeUiComponent,
  entity : @entity.Entity,
  state : Json,
) -> Unit raise NativeComponentLoaderError {
  let world = @ecs.require_current_world()
  if self.unloaded ||
    world.id() != self.world_id ||
    !entity.is_alive() ||
    self.entities.contains(entity) {
    raise NativeComponentLoaderError(
      "native UI component mount requires a live, unused Entity in its World",
    )
  }
  let world_views = native_views.get_or_init(world.id(), fn() { Map([]) })
  if world_views.contains(entity.id()) {
    raise NativeComponentLoaderError(
      "Selene Entity is already mounted by a native UI component",
    )
  }
  world_views[entity.id()] = {
    entity,
    host: @component_host.SeleneHost::new(),
    mounted: false,
  }
  require_native_success(
    native_mount(self.handle, entity.id(), @utf8.encode(state.stringify())),
  ) catch {
    error => {
      match world_views.get(entity.id()) {
        Some(view) if view.mounted =>
          view.host.unmount(entity) catch {
            _ => ()
          }
        _ => ()
      }
      world_views.remove(entity.id())
      raise error
    }
  }
  self.entities.add(entity)
}

///|
pub fn NativeUiComponent::replace(
  self : NativeUiComponent,
  entity : @entity.Entity,
  state : Json,
) -> Unit raise NativeComponentLoaderError {
  if self.unloaded ||
    @ecs.require_current_world().id() != self.world_id ||
    !self.entities.contains(entity) {
    raise NativeComponentLoaderError(
      "native UI view does not belong to this component",
    )
  }
  require_native_success(
    native_replace(self.handle, entity.id(), @utf8.encode(state.stringify())),
  )
}

///|
pub fn NativeUiComponent::apply(
  self : NativeUiComponent,
  entity : @entity.Entity,
  patches : Json,
) -> Unit raise NativeComponentLoaderError {
  if self.unloaded ||
    @ecs.require_current_world().id() != self.world_id ||
    !self.entities.contains(entity) {
    raise NativeComponentLoaderError(
      "native UI view does not belong to this component",
    )
  }
  require_native_success(
    native_apply(self.handle, entity.id(), @utf8.encode(patches.stringify())),
  )
}

///|
pub fn NativeUiComponent::handle_event(
  self : NativeUiComponent,
  entity : @entity.Entity,
  event : Json,
) -> String raise NativeComponentLoaderError {
  if self.unloaded ||
    @ecs.require_current_world().id() != self.world_id ||
    !self.entities.contains(entity) {
    raise NativeComponentLoaderError(
      "native UI view does not belong to this component",
    )
  }
  require_native_success(
    native_handle_event(
      self.handle,
      entity.id(),
      @utf8.encode(event.stringify()),
    ),
  )
  @utf8.decode_lossy(native_last_result())
}

///|
pub fn NativeUiComponent::update(
  self : NativeUiComponent,
) -> Unit raise NativeComponentLoaderError {
  let world = @ecs.require_current_world()
  if self.unloaded || world.id() != self.world_id {
    raise NativeComponentLoaderError(
      "native UI component update must run in its World",
    )
  }
  let dead : Array[@entity.Entity] = []
  for entity in self.entities {
    if !entity.is_alive() {
      dead.push(entity)
    }
  }
  for entity in dead {
    require_native_success(native_unmount(self.handle, entity.id()))
    match native_views[world.id()].get(entity.id()) {
      Some(view) if view.mounted => view.host.unmount(entity) catch { _ => () }
      _ => ()
    }
    native_views[world.id()].remove(entity.id())
    self.entities.remove(entity)
  }
  require_native_success(native_update(self.handle))
}

///|
pub fn NativeUiComponent::unmount(
  self : NativeUiComponent,
  entity : @entity.Entity,
) -> Unit raise NativeComponentLoaderError {
  let world = @ecs.require_current_world()
  if self.unloaded ||
    world.id() != self.world_id ||
    !self.entities.contains(entity) {
    raise NativeComponentLoaderError(
      "native UI view does not belong to this component",
    )
  }
  require_native_success(native_unmount(self.handle, entity.id()))
  match native_views[world.id()].get(entity.id()) {
    Some(view) if view.mounted =>
      view.host.unmount(entity) catch {
        error => raise NativeComponentLoaderError(error.to_string())
      }
    _ => ()
  }
  native_views[world.id()].remove(entity.id())
  self.entities.remove(entity)
}

///|
pub fn NativeUiComponent::unload(
  self : NativeUiComponent,
) -> Unit raise NativeComponentLoaderError {
  if self.entities.length() != 0 {
    raise NativeComponentLoaderError(
      "unmount all UI views before unloading their component module",
    )
  }
  if !self.unloaded {
    require_native_success(native_unload(self.handle))
    self.unloaded = true
  }
}
