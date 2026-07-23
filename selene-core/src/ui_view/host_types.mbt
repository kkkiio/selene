///|
pub struct ViewHost {
  world_id : UInt
} derive(Eq, Hash, Debug)

///|
pub struct MountedView {
  host : ViewHost
  entity : @entity.Entity
  mut mounted : Bool
} derive(Eq, Debug)

///|
struct ScrollSnapshot {
  key : String
  x : Double
  y : Double
} derive(Eq, Debug)

///|
struct ViewSnapshot {
  focus_key : String?
  scroll : Array[ScrollSnapshot]
} derive(Eq, Debug)

///|
pub(all) struct UiViewEvent {
  entity : @entity.Entity
  event : UiEvent
} derive(Eq, Debug)

///|
priv struct HostNode {
  spec : NodeSpec
  effective_spec : NodeSpec
  children : Array[String]
}

///|
priv struct ActiveVisualTransition {
  target : String
  property : String
  from : VisualStateValue
  to : VisualStateValue
  start : Double
  duration : Double
  delay : Double
  easing : String
}

///|
priv struct ViewRecord {
  container : @entity.Entity
  nodes : Map[String, HostNode]
  entities : Map[String, @entity.Entity]
  entity_keys : Map[@entity.Entity, String]
  roots : Array[String]
  visual_states : Map[String, String]
  visual_transitions : Map[String, ActiveVisualTransition]
}

///|
priv struct HostWorldStore {
  views : Map[@entity.Entity, ViewRecord]
  mut last_focused : @entity.Entity?
}

///|
let host_world_stores : Map[UInt, HostWorldStore] = Map([])

///|
pub let view_event_bus : @event.Events[UiViewEvent] = @event.Events()

///|
let view_click_reader : @event.EventReader[@ui.UiClickEvent] = @event.EventReader()
