///|
test "INVENTORY-01 Embedded View uses Entity identity and typed transactions" {
  let previous_world = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  defer @ecs.set_current_world(previous_world)
  let host = @ui_view.ViewHost::new()
  let entity = @entity.Entity()
  let map_item : @view.InventoryItem = {
    id: "map",
    category: "setup",
    name: "Ashen Coast Map",
    image: "map.png",
    count: 1,
    rarity: "QUEST RELIC",
    description: "Copper ink glows beside undiscovered roads.",
    selected: true,
    layout_width: 656.0,
  }
  let key_item : @view.InventoryItem = {
    id: "key",
    category: "setup",
    name: "Brass Waystone Key",
    image: "key.png",
    count: 1,
    rarity: "ANCIENT KEY",
    description: "Its teeth realign near a sealed waypoint.",
    selected: false,
    layout_width: 656.0,
  }
  let initial : @view.InventoryUiState = {
    viewport_width: 960.0,
    capacity: 24,
    tabs: [
      { id: "equip", icon: "equip.png", selected: true, layout_width: 60.0 },
      { id: "setup", icon: "setup.png", selected: false, layout_width: 60.0 },
    ],
    all_items: [map_item, key_item],
    items: [map_item, key_item],
    equipment: [
      {
        slot: "weapon",
        name: "Sunblade",
        image: "sword.png",
        selected: true,
        layout_width: 656.0,
      },
    ],
    selected_tab_id: "equip",
    selected_item_id: "map",
  }
  @view.InventoryView::mount(entity, initial)
  let map_button = host
    .entity(entity, "pack-grid/items:map/item-button-wide")
    .unwrap()
  let key_button = host
    .entity(entity, "pack-grid/items:key/item-button-wide")
    .unwrap()
  let pack_grid = host.entity(entity, "pack-grid").unwrap()
  let equip_tab = host
    .entity(entity, "inventory-header/tabs:equip/tab-button")
    .unwrap()
  let equip_icon = host
    .entity(entity, "inventory-header/tabs:equip/tab-icon")
    .unwrap()
  debug_inspect(
    (
      @ui.texts()[host.entity(entity, "pack-grid/items:map/item-count").unwrap()].content,
      @ui.texts()[host.entity(entity, "selected-name").unwrap()].content,
    ),
    content=(
      #|("1", "Ashen Coast Map")
    ),
  )
  @view.InventoryView::replace(entity, {
    ..initial,
    selected_item_id: "key",
    selected_tab_id: "setup",
    tabs: initial.tabs.map(tab => { ..tab, selected: tab.id == "setup" }),
    items: [{ ..map_item, selected: false }, { ..key_item, selected: true }],
  })
  inspect(
    host.entity(entity, "pack-grid/items:map/item-button-wide").unwrap() ==
    map_button,
    content="true",
  )
  debug_inspect(
    (
      host.entity(entity, "inventory-header/tabs:equip/tab-button") ==
      Some(equip_tab),
      host.entity(entity, "inventory-header/tabs:equip/tab-icon") ==
      Some(equip_icon),
      @ui.background_colors()[host
      .entity(entity, "inventory-header/tabs:setup/tab-button")
      .unwrap()].color,
    ),
    content=(
      #|(true, true, { r: 107, g: 61, b: 38, a: 1 })
    ),
  )
  @view.InventoryView::apply(entity, [
    @view.InventoryUiPatch::ItemUpsert({ ..map_item, count: 5 }),
    @view.InventoryUiPatch::ItemMove(("map", 1U)),
  ])
  debug_inspect(
    @ui.texts()[host.entity(entity, "pack-grid/items:map/item-count").unwrap()].content,
    content="\"5\"",
  )
  assert_eq(pack_grid.get_children(), [key_button, map_button])
  try @view.InventoryView::mount(entity, initial) catch {
    @view.InventoryViewError::AlreadyMounted => inspect(true, content="true")
    error => raise error
  } noraise {
    _ => fail("mounting the same Entity twice must fail")
  }
  try
    @view.InventoryView::replace(entity, {
      ..initial,
      items: [map_item, map_item],
    })
  catch {
    @view.InventoryViewError::DuplicateKey(path, key) =>
      debug_inspect((path, key), content="(\"items\", \"map\")")
    error => raise error
  } noraise {
    _ => fail("duplicate keyed items must fail atomically")
  }
  try
    @view.InventoryView::apply(entity, [
      @view.InventoryUiPatch::ItemRemove("missing"),
    ])
  catch {
    @view.InventoryViewError::InvalidPatch(message) =>
      debug_inspect(
        message,
        content="\"patch remove key does not exist: missing\"",
      )
    error => raise error
  } noraise {
    _ => fail("invalid typed Patch must preserve committed state")
  }
  host.unmount(entity)
  entity.destroy()
}

///|
test "INVENTORY-02 Embedded View records are isolated by World" {
  let previous_world = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  defer @ecs.set_current_world(previous_world)
  let first_world = @ecs.World()
  @ecs.set_current_world(first_world)
  let first_root = @entity.Entity()
  let state : @view.InventoryUiState = {
    viewport_width: 960.0,
    capacity: 0,
    tabs: [],
    all_items: [],
    items: [],
    equipment: [],
    selected_tab_id: "",
    selected_item_id: "",
  }
  @view.InventoryView::mount(first_root, state)
  first_root.destroy()
  let second_world = @ecs.World()
  @ecs.set_current_world(second_world)
  let second_root = @entity.Entity()
  debug_inspect(
    (first_world.id() != second_world.id(), first_root.id(), second_root.id()),
    content="(true, 0, 0)",
  )
  @view.InventoryView::mount(second_root, state)
  inspect(
    @ui_view.ViewHost::new().entity(second_root, "inventory-root") is Some(_),
    content="true",
  )
  second_root.destroy()
}
