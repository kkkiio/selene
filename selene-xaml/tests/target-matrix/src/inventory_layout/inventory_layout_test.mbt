///|
test "INVENTORY-LAYOUT-01 wide and narrow content stays inside symmetric insets" {
  let previous_world = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  try {
    let parent = @entity.Entity()
    @ui.nodes()[parent] = @ui.Node(
      width=@ui.Val::Px(960.0),
      height=@ui.Val::Px(540.0),
    )
    let host = @component_host.SeleneHost::new()
    let layout_item : @inventory_view.InventoryItem = {
      id: "map",
      category: "setup",
      name: "Ashen Coast Map",
      image: "../assets/icons/ancient-map.png",
      count: 1,
      rarity: "QUEST RELIC",
      description: "Copper ink glows beside undiscovered roads.",
      selected: true,
      layout_width: 652.0,
    }
    let wide_state : @inventory_view.InventoryUiState = {
      viewport_width: 960.0,
      capacity: 24,
      tabs: [
        {
          id: "equip",
          icon: "equip.png",
          selected_icon: "equip-selected.png",
          selected: true,
          layout_width: 60.0,
        },
        {
          id: "use",
          icon: "use.png",
          selected_icon: "use-selected.png",
          selected: false,
          layout_width: 60.0,
        },
        {
          id: "setup",
          icon: "setup.png",
          selected_icon: "setup-selected.png",
          selected: false,
          layout_width: 60.0,
        },
      ],
      all_items: [layout_item],
      items: [layout_item],
      equipment: [
        {
          slot: "weapon",
          name: "Sunblade",
          image: "../assets/icons/sunblade.png",
          selected: true,
          layout_width: 652.0,
        },
        {
          slot: "armor",
          name: "Ember Mail",
          image: "../assets/icons/ember-mail.png",
          selected: false,
          layout_width: 652.0,
        },
      ],
      selected_tab_id: "equip",
      selected_item_id: "map",
    }
    @inventory_view.InventoryView::mount(parent, wide_state)
    @ui.ui_layout_system(0.0)

    let wide_header = @ui.global_ui_nodes()[host
      .entity(parent, "inventory-header")
      .unwrap()]
    let wide_capacity = @ui.global_ui_nodes()[host
      .entity(parent, "capacity-display")
      .unwrap()]
    let wide_pack = @ui.global_ui_nodes()[host
      .entity(parent, "pack-panel")
      .unwrap()]
    let wide_pack_header = @ui.global_ui_nodes()[host
      .entity(parent, "pack-header")
      .unwrap()]
    let wide_scroll = @ui.global_ui_nodes()[host
      .entity(parent, "item-scroll")
      .unwrap()]
    let wide_details = @ui.global_ui_nodes()[host
      .entity(parent, "details")
      .unwrap()]
    let wide_description = @ui.global_ui_nodes()[host
      .entity(parent, "selected-description")
      .unwrap()]
    debug_inspect(
      (
        (wide_header.screen_rect.position, wide_header.screen_rect.size),
        (wide_capacity.screen_rect.position, wide_capacity.screen_rect.size),
        (wide_pack.screen_rect.position, wide_pack.screen_rect.size),
        (
          wide_pack_header.screen_rect.position,
          wide_pack_header.screen_rect.size,
        ),
        (wide_scroll.screen_rect.position, wide_scroll.screen_rect.size),
        (wide_details.screen_rect.position, wide_details.screen_rect.size),
        (
          wide_description.screen_rect.position,
          wide_description.screen_rect.size,
        ),
      ),
      content=(
        #|(
        #|  (Vec2(20, 18), Vec2(920, 62)),
        #|  (Vec2(832, 27), Vec2(96, 44)),
        #|  (Vec2(20, 94), Vec2(550, 432)),
        #|  (Vec2(34, 108), Vec2(522, 26)),
        #|  (Vec2(34, 142), Vec2(522, 370)),
        #|  (Vec2(584, 94), Vec2(356, 432)),
        #|  (Vec2(598, 434), Vec2(328, 64)),
        #|)

      ),
    )

    @inventory_view.InventoryView::replace(parent, {
      ..wide_state,
      viewport_width: 720.0,
      tabs: [
        { ..wide_state.tabs[0], layout_width: 52.0 },
        { ..wide_state.tabs[1], layout_width: 52.0 },
        { ..wide_state.tabs[2], layout_width: 52.0 },
      ],
    })
    @ui.ui_layout_system(0.0)
    let narrow_header = @ui.global_ui_nodes()[host
      .entity(parent, "inventory-header")
      .unwrap()]
    let narrow_capacity = @ui.global_ui_nodes()[host
      .entity(parent, "capacity-display")
      .unwrap()]
    let narrow_panel = @ui.global_ui_nodes()[host
      .entity(parent, "narrow-panel")
      .unwrap()]
    let narrow_equipment = @ui.global_ui_nodes()[host
      .entity(parent, "narrow-panel/equipment:weapon/equipment-button-narrow")
      .unwrap()]
    let narrow_scroll = @ui.global_ui_nodes()[host
      .entity(parent, "item-scroll-narrow")
      .unwrap()]
    let narrow_description = @ui.global_ui_nodes()[host
      .entity(parent, "selected-description-narrow")
      .unwrap()]
    debug_inspect(
      (
        (narrow_header.screen_rect.position, narrow_header.screen_rect.size),
        (narrow_capacity.screen_rect.position, narrow_capacity.screen_rect.size),
        (narrow_panel.screen_rect.position, narrow_panel.screen_rect.size),
        (
          narrow_equipment.screen_rect.position,
          narrow_equipment.screen_rect.size,
        ),
        (narrow_scroll.screen_rect.position, narrow_scroll.screen_rect.size),
        (
          narrow_description.screen_rect.position,
          narrow_description.screen_rect.size,
        ),
      ),
      content=(
        #|(
        #|  (Vec2(20, 18), Vec2(680, 62)),
        #|  (Vec2(592, 27), Vec2(96, 44)),
        #|  (Vec2(20, 94), Vec2(680, 428)),
        #|  (Vec2(34, 108), Vec2(652, 56)),
        #|  (Vec2(34, 236), Vec2(652, 206)),
        #|  (Vec2(34, 450), Vec2(652, 58)),
        #|)

      ),
    )
    host.unmount(parent)
    parent.destroy()
  } catch {
    error => {
      @ecs.set_current_world(previous_world)
      raise error
    }
  }
  @ecs.set_current_world(previous_world)
}
