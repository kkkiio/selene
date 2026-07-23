///|
let live_inventory_entity : Ref[@entity.Entity?] = { val: None }

///|
let live_inventory_state : Ref[@model.InventoryUiState?] = { val: None }

///|
let inventory_event_reader : @event.EventReader[
  @inventory_view.InventoryViewActionEvent,
] = @event.EventReader()

///|
extern "js" fn browser_viewport_width() -> Double =
  #| () => Number(globalThis.__seleneExampleViewportWidth ?? 960)

///|
extern "js" fn mark_inventory_mounted() -> Unit =
  #| () => { globalThis.__seleneInventoryExample = { mounted: true }; }

///|
fn to_view_state(
  state : @model.InventoryUiState,
) -> @inventory_view.InventoryUiState {
  {
    viewport_width: state.viewport_width,
    capacity: state.capacity,
    tabs: state.tabs.map(tab => {
      let projected : @inventory_view.InventoryTab = {
        id: tab.id,
        icon: tab.icon,
        selected_icon: tab.selected_icon,
        selected: tab.selected,
        layout_width: tab.layout_width,
      }
      projected
    }),
    items: state.items.map(item => {
      let projected : @inventory_view.InventoryItem = {
        id: item.id,
        category: item.category,
        name: item.name,
        image: item.image,
        count: item.count,
        rarity: item.rarity,
        description: item.description,
        selected: item.selected,
        layout_width: item.layout_width,
      }
      projected
    }),
    all_items: state.all_items.map(item => {
      let projected : @inventory_view.InventoryItem = {
        id: item.id,
        category: item.category,
        name: item.name,
        image: item.image,
        count: item.count,
        rarity: item.rarity,
        description: item.description,
        selected: item.selected,
        layout_width: item.layout_width,
      }
      projected
    }),
    equipment: state.equipment.map(item => {
      let projected : @inventory_view.EquipmentItem = {
        slot: item.slot,
        name: item.name,
        image: item.image,
        selected: item.selected,
        layout_width: item.layout_width,
      }
      projected
    }),
    selected_tab_id: state.selected_tab_id,
    selected_item_id: state.selected_item_id,
  }
}

///|
fn setup_inventory_view(_world : @ecs.World) -> Unit {
  try {
    let viewport_width = browser_viewport_width()
    let parent = @entity.Entity()
    @ui.nodes()[parent] = @ui.Node(
      width=@ui.Val::Px(viewport_width),
      height=@ui.Val::Px(540.0),
    )
    let state = @model.showcase_state(viewport_width)
    @inventory_view.InventoryView::mount(parent, to_view_state(state))
    live_inventory_state.val = Some(state)
    live_inventory_entity.val = Some(parent)
    mark_inventory_mounted()
  } catch {
    error => abort(error.to_string())
  }
}

///|
fn dispatch_inventory_events(_world : @ecs.World) -> Unit {
  guard live_inventory_entity.val is Some(entity) &&
    live_inventory_state.val is Some(state) else {
    return
  }
  for envelope in inventory_event_reader.read(@inventory_view.action_event_bus) {
    if envelope.entity != entity {
      continue
    }
    try {
      let mut next = state
      let mut changed = false
      match envelope.action {
        SelectItem(key) => {
          next = {
            ..next,
            selected_item_id: key,
            items: next.items.map(item => { ..item, selected: item.id == key }),
            all_items: next.all_items.map(item => {
              ..item,
              selected: item.id == key,
            }),
          }
          changed = true
        }
        FocusItem(key) => {
          next = {
            ..next,
            selected_item_id: key,
            items: next.items.map(item => { ..item, selected: item.id == key }),
            all_items: next.all_items.map(item => {
              ..item,
              selected: item.id == key,
            }),
          }
          changed = true
        }
        SelectTab(key) => {
          let visible_items : Array[@model.InventoryItem] = []
          for item in next.all_items {
            if item.category == key {
              visible_items.push({
                ..item,
                selected: visible_items.length() == 0,
              })
            }
          }
          let selected_item_id = if visible_items.length() > 0 {
            visible_items[0].id
          } else {
            ""
          }
          next = {
            ..next,
            tabs: next.tabs.map(tab => { ..tab, selected: tab.id == key }),
            all_items: next.all_items.map(item => {
              ..item,
              selected: item.id == selected_item_id,
            }),
            items: visible_items,
            selected_tab_id: key,
            selected_item_id,
          }
          changed = true
        }
        SelectEquipment(key) => {
          next = {
            ..next,
            equipment: next.equipment.map(item => {
              ..item,
              selected: item.slot == key,
            }),
          }
          changed = true
        }
      }
      if changed {
        @inventory_view.InventoryView::replace(entity, to_view_state(next))
        live_inventory_state.val = Some(next)
      }
    } catch {
      error => abort(error.to_string())
    }
  }
}

///|
fn main {
  @selene_app.App()
  .with_viewport_width(browser_viewport_width())
  .with_viewport_height(540.0)
  .with_fps(60)
  .with_image_smooth(false)
  .add_plugin(@plugins.default_plugin)
  .add_plugin(@inventory_view.plugin)
  .add_system(@system.Startup, setup_inventory_view)
  .add_system(
    @system.PostUpdate,
    dispatch_inventory_events,
    system_name="inventory_view_actions",
  )
  .run()
}
