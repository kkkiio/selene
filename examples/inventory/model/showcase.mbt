///|
pub fn showcase_state(viewport_width : Double) -> InventoryUiState {
  let content_width = if viewport_width < 40.0 {
    0.0
  } else if viewport_width > 960.0 {
    920.0
  } else {
    viewport_width - 40.0
  }
  let layout_width = content_width - 28.0
  let tab_width = if viewport_width >= 900.0 { 60.0 } else { 52.0 }
  let all_items : Array[InventoryItem] = [
    {
      id: "torch",
      category: "equip",
      name: "Emberglass Torch",
      image: "assets/icons/ember-torch.png",
      count: 3,
      rarity: "FIELD GEAR",
      description: "A smokeless flame burns inside the amber glass.",
      selected: true,
      layout_width,
    },
    {
      id: "ruby",
      category: "equip",
      name: "Cinder Ruby",
      image: "assets/icons/ruby.png",
      count: 2,
      rarity: "RARE GEM",
      description: "A coal-red inclusion turns like a tiny storm cloud.",
      selected: false,
      layout_width,
    },
    {
      id: "tonic",
      category: "use",
      name: "Crimson Tonic",
      image: "assets/icons/crimson-tonic.png",
      count: 5,
      rarity: "RESTORATIVE",
      description: "Bitter mountain herbs restore strength after a march.",
      selected: false,
      layout_width,
    },
    {
      id: "coin",
      category: "use",
      name: "Sun-Court Coin",
      image: "assets/icons/sun-coin.png",
      count: 18,
      rarity: "OLD CURRENCY",
      description: "Warm to the touch despite centuries beneath the sand.",
      selected: false,
      layout_width,
    },
    {
      id: "map",
      category: "setup",
      name: "Ashen Coast Map",
      image: "assets/icons/ancient-map.png",
      count: 1,
      rarity: "QUEST RELIC",
      description: "Copper ink glows beside undiscovered roads.",
      selected: false,
      layout_width,
    },
    {
      id: "key",
      category: "setup",
      name: "Brass Waystone Key",
      image: "assets/icons/brass-key.png",
      count: 1,
      rarity: "ANCIENT KEY",
      description: "Its teeth realign when held near a sealed waypoint.",
      selected: false,
      layout_width,
    },
  ]
  {
    viewport_width,
    capacity: 24,
    tabs: [
      {
        id: "equip",
        icon: "assets/ui/inventory-tabs.atlas.json#equip.normal",
        selected_icon: "assets/ui/inventory-tabs.atlas.json#equip.selected",
        selected: true,
        layout_width: tab_width,
      },
      {
        id: "use",
        icon: "assets/ui/inventory-tabs.atlas.json#use.normal",
        selected_icon: "assets/ui/inventory-tabs.atlas.json#use.selected",
        selected: false,
        layout_width: tab_width,
      },
      {
        id: "setup",
        icon: "assets/ui/inventory-tabs.atlas.json#setup.normal",
        selected_icon: "assets/ui/inventory-tabs.atlas.json#setup.selected",
        selected: false,
        layout_width: tab_width,
      },
    ],
    all_items,
    items: all_items.filter(item => item.category == "equip"),
    equipment: [
      {
        slot: "weapon",
        name: "Sunblade",
        image: "assets/icons/sunblade.png",
        selected: true,
        layout_width,
      },
      {
        slot: "armor",
        name: "Ember Mail",
        image: "assets/icons/ember-mail.png",
        selected: false,
        layout_width,
      },
    ],
    selected_tab_id: "equip",
    selected_item_id: "torch",
  }
}
