///|
#cfg(target="js")
priv struct BrowserStyle {
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
#cfg(target="js")
priv struct BrowserNodeSpec {
  key : String
  parent : String
  kind : String
  text : String
  source : String
  active : Bool
  enabled : Bool
  focusable : Bool
  style : BrowserStyle
  visual_state_groups : Array[BrowserVisualStateGroup]
} derive(FromJson)

///|
#cfg(target="js")
priv struct BrowserVisualStateValue {
  tag : String
  string_value : String
  bool_value : Bool
  number_value : Double
  layout_kind : String
  layout_value : Double
} derive(FromJson)

///|
#cfg(target="js")
priv struct BrowserVisualStateSetter {
  target : String
  property : String
  value : BrowserVisualStateValue
} derive(FromJson)

///|
#cfg(target="js")
priv struct BrowserVisualStateDefinition {
  name : String
  setters : Array[BrowserVisualStateSetter]
} derive(FromJson)

///|
#cfg(target="js")
priv struct BrowserVisualTransition {
  from : String
  to : String
  duration : Double
  delay : Double
  easing : String
} derive(FromJson)

///|
#cfg(target="js")
priv struct BrowserVisualStateGroup {
  order : Int
  name : String
  current : String
  interaction : Bool
  states : Array[BrowserVisualStateDefinition]
  transitions : Array[BrowserVisualTransition]
} derive(FromJson)

///|
#cfg(target="js")
fn browser_visual_state_value(
  value : BrowserVisualStateValue,
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
#cfg(target="js")
fn browser_visual_state_groups(
  groups : Array[BrowserVisualStateGroup],
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
        value: browser_visual_state_value(setter.value),
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
#cfg(target="js")
priv struct BrowserMutation {
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
#cfg(target="js")
priv struct BrowserBridgeView {
  entity : @entity.Entity
  host : SeleneHost
  mut mounted : Bool
}

///|
#cfg(target="js")
let browser_views : Map[UInt, Map[UInt, BrowserBridgeView]] = Map([])

///|
#cfg(target="js")
extern "js" fn install_browser_callbacks(
  apply_callback : (UInt, String) -> String,
  is_alive_callback : (UInt) -> Bool,
  release_callback : (UInt) -> Unit,
) =
  #| (apply, isAlive, release) => {
  #|   globalThis.__seleneUiComponentHost = { apply, isAlive, release };
  #| }

///|
#cfg(target="js")
pub fn install_browser_host() -> Unit {
  install_browser_callbacks(
    fn(entity_id, payload) {
      let world_id = @ecs.require_current_world().id()
      let selected = match browser_views.get(world_id) {
        Some(views) => views.get(entity_id)
        None => None
      }
      match selected {
        None => "SH3001: unknown browser Entity " + entity_id.to_string()
        Some(view) =>
          try {
            let decoded : Array[BrowserMutation] = @json.from_json(
              @json.parse(payload),
            )
            let mutations : Array[@ui_host.TreeMutation] = []
            for mutation in decoded {
              match mutation.tag {
                "mount" | "update" => {
                  let value : BrowserNodeSpec = match mutation.spec {
                    Null =>
                      raise @ui_host.HostError::InvalidMutation(
                        "SH3004",
                        "browser " + mutation.tag + " mutation requires spec",
                      )
                    spec => @json.from_json(spec)
                  }
                  let kind = match value.kind {
                    "view" => @ui_host.NodeKind::View
                    "flex" => @ui_host.NodeKind::Flex
                    "text" => @ui_host.NodeKind::Text
                    "image" => @ui_host.NodeKind::Image
                    "button" => @ui_host.NodeKind::Button
                    "scroll-view" => @ui_host.NodeKind::ScrollView
                    _ =>
                      raise @ui_host.HostError::InvalidMutation(
                        "SH3002",
                        "unknown browser node kind: " + value.kind,
                      )
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
                    visual_state_groups: browser_visual_state_groups(
                      value.visual_state_groups,
                    ),
                    style: {
                      absolute: value.style.absolute,
                      left: value.style.left,
                      top: value.style.top,
                      width: match value.style.width_kind {
                        "px" =>
                          @ui_host.LayoutValue::Px(value.style.width_value)
                        "percent" => Percent(value.style.width_value)
                        _ => Auto
                      },
                      height: match value.style.height_kind {
                        "px" =>
                          @ui_host.LayoutValue::Px(value.style.height_value)
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
                        "px" =>
                          @ui_host.LayoutValue::Px(value.style.flex_basis_value)
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
                      Mount(spec)
                    } else {
                      Update(spec)
                    },
                  )
                }
                "set-text" =>
                  mutations.push(SetText(mutation.key, mutation.text_value))
                "set-source" =>
                  mutations.push(SetSource(mutation.key, mutation.text_value))
                "set-background" =>
                  mutations.push(
                    SetBackground(mutation.key, mutation.text_value),
                  )
                "set-active" =>
                  mutations.push(SetActive(mutation.key, mutation.bool_value))
                "set-enabled" =>
                  mutations.push(SetEnabled(mutation.key, mutation.bool_value))
                "set-top" =>
                  mutations.push(SetTop(mutation.key, mutation.number_value))
                "move" =>
                  mutations.push(
                    Move(mutation.key, mutation.parent, mutation.index),
                  )
                "remove" => mutations.push(Remove(mutation.key))
                tag =>
                  raise @ui_host.HostError::InvalidMutation(
                    "SH3003",
                    "unknown browser mutation: " + tag,
                  )
              }
            }
            if view.mounted {
              view.host.apply(view.entity, mutations)
            } else {
              let specs : Array[@ui_host.NodeSpec] = []
              for mutation in mutations {
                match mutation {
                  Mount(spec) => specs.push(spec)
                  _ =>
                    raise @ui_host.HostError::InvalidMutation(
                      "SH3005", "the first browser batch must contain only Mount operations",
                    )
                }
              }
              view.host.mount(view.entity, specs)
              view.mounted = true
            }
            ""
          } catch {
            error => error.to_string()
          }
      }
    },
    fn(entity_id) {
      match browser_views.get(@ecs.require_current_world().id()) {
        Some(views) =>
          views.get(entity_id).map_or(false, view => view.entity.is_alive())
        None => false
      }
    },
    fn(entity_id) {
      let world_id = @ecs.require_current_world().id()
      match browser_views.get(world_id) {
        Some(views) =>
          match views.get(entity_id) {
            Some(view) => {
              if view.mounted {
                view.host.unmount(view.entity) catch {
                  _ => ()
                }
                view.mounted = false
              }
              if !view.entity.is_alive() {
                views.remove(entity_id)
              }
            }
            None => ()
          }
        None => ()
      }
    },
  )
}

///|
#cfg(target="js")
pub fn register_browser_entity(entity : @entity.Entity) -> UInt {
  let world_id = @ecs.require_current_world().id()
  if !entity.is_alive() {
    abort("browser Component Entity must be alive")
  }
  let views = browser_views.get_or_init(world_id, fn() { Map([]) })
  if views.contains(entity.id()) {
    abort("browser Component Entity is already registered")
  }
  views[entity.id()] = { entity, host: SeleneHost::new(), mounted: false }
  entity.id()
}

///|
#cfg(not(target="js"))
pub fn install_browser_host() -> Unit {
  abort("browser component host bridge is only available on the JS target")
}

///|
#cfg(not(target="js"))
pub fn register_browser_entity(_entity : @entity.Entity) -> UInt {
  abort("browser component host bridge is only available on the JS target")
}
