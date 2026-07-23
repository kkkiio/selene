///|
fn benchmark_inventory_state(size : Int) -> @view.InventoryUiState {
  let items : Array[@view.InventoryItem] = []
  for index = 0; index < size; index = index + 1 {
    items.push({
      id: "item-" + index.to_string(),
      category: "benchmark",
      name: "Benchmark Item " + index.to_string(),
      image: "benchmark.png",
      count: 1,
      rarity: "BENCHMARK",
      description: "Generated inventory benchmark item.",
      selected: index == 0,
      layout_width: 656.0,
    })
  }
  {
    viewport_width: 960.0,
    capacity: size + 16,
    tabs: [],
    all_items: items,
    items,
    equipment: [],
    selected_tab_id: "",
    selected_item_id: if size > 0 {
      "item-0"
    } else {
      ""
    },
  }
}

///|
fn benchmark_host_specs(size : Int) -> Array[@ui_view.NodeSpec] {
  let style = @ui_view.NodeStyle::default()
  let specs : Array[@ui_view.NodeSpec] = [
    {
      key: "root",
      parent: None,
      kind: Flex,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: false,
      tab_index: 0,
      focus_scope: false,
      auto_focus: false,
      navigation_up: "",
      navigation_down: "",
      navigation_left: "",
      navigation_right: "",
      style,
      visual_state_groups: [],
    },
  ]
  for index = 0; index < size; index = index + 1 {
    specs.push({
      key: "text-" + index.to_string(),
      parent: Some("root"),
      kind: Text,
      text: "Initial",
      source: "",
      active: true,
      enabled: true,
      focusable: false,
      tab_index: 0,
      focus_scope: false,
      auto_focus: false,
      navigation_up: "",
      navigation_down: "",
      navigation_left: "",
      navigation_right: "",
      style,
      visual_state_groups: [],
    })
  }
  specs
}

///|
test "BENCH-XAML-01 Embedded View replacement and typed patches" (b : @bench.T) {
  let previous_world = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  defer @ecs.set_current_world(previous_world)
  let host = @ui_view.ViewHost::new()
  for size in [32, 128, 512] {
    let state = benchmark_inventory_state(size)
    let unchanged_root = @entity.Entity()
    @view.InventoryView::mount(unchanged_root, state) catch {
      error => abort(error.to_string())
    }
    b.bench(
      name="embedded/replace-no-change/n=" + size.to_string(),
      fn() {
        @view.InventoryView::replace(unchanged_root, state) catch {
          error => abort(error.to_string())
        }
      },
      count=5,
    )
    host.unmount(unchanged_root) catch {
      error => abort(error.to_string())
    }
    unchanged_root.destroy()

    let upsert_root = @entity.Entity()
    @view.InventoryView::mount(upsert_root, state) catch {
      error => abort(error.to_string())
    }
    let middle = state.items[size / 2]
    let low_patch = [@view.InventoryUiPatch::ItemUpsert({ ..middle, count: 1 })]
    let high_patch = [
      @view.InventoryUiPatch::ItemUpsert({ ..middle, count: 2 }),
    ]
    let mut high = false
    b.bench(
      name="embedded/apply-upsert-middle/n=" + size.to_string(),
      fn() {
        high = !high
        @view.InventoryView::apply(
          upsert_root,
          if high {
            high_patch
          } else {
            low_patch
          },
        ) catch {
          error => abort(error.to_string())
        }
      },
      count=5,
    )
    host.unmount(upsert_root) catch {
      error => abort(error.to_string())
    }
    upsert_root.destroy()

    let move_root = @entity.Entity()
    @view.InventoryView::mount(move_root, state) catch {
      error => abort(error.to_string())
    }
    let moved_key = state.items[size - 1].id
    let move_first = [@view.InventoryUiPatch::ItemMove((moved_key, 0U))]
    let move_last = [
      @view.InventoryUiPatch::ItemMove(
        (moved_key, (size - 1).reinterpret_as_uint()),
      ),
    ]
    let mut at_front = false
    b.bench(
      name="embedded/apply-move-last-first/n=" + size.to_string(),
      fn() {
        at_front = !at_front
        @view.InventoryView::apply(
          move_root,
          if at_front {
            move_first
          } else {
            move_last
          },
        ) catch {
          error => abort(error.to_string())
        }
      },
      count=5,
    )
    host.unmount(move_root) catch {
      error => abort(error.to_string())
    }
    move_root.destroy()

    let toggle_root = @entity.Entity()
    @view.InventoryView::mount(toggle_root, state) catch {
      error => abort(error.to_string())
    }
    let added_item : @view.InventoryItem = {
      id: "inserted",
      category: "benchmark",
      name: "Inserted Benchmark Item",
      image: "benchmark.png",
      count: 1,
      rarity: "BENCHMARK",
      description: "Inserted and removed at the collection head.",
      selected: false,
      layout_width: 656.0,
    }
    let insert_head = [
      @view.InventoryUiPatch::ItemUpsert(added_item),
      @view.InventoryUiPatch::ItemMove(("inserted", 0U)),
    ]
    let remove_head = [@view.InventoryUiPatch::ItemRemove("inserted")]
    let mut inserted = false
    b.bench(
      name="embedded/apply-toggle-head/n=" + size.to_string(),
      fn() {
        inserted = !inserted
        @view.InventoryView::apply(
          toggle_root,
          if inserted {
            insert_head
          } else {
            remove_head
          },
        ) catch {
          error => abort(error.to_string())
        }
      },
      count=5,
    )
    host.unmount(toggle_root) catch {
      error => abort(error.to_string())
    }
    toggle_root.destroy()
  }
}

///|
test "BENCH-XAML-02 ViewHost property and sibling mutations" (b : @bench.T) {
  let previous_world = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  defer @ecs.set_current_world(previous_world)
  let host = @ui_view.ViewHost::new()
  for size in [32, 128, 512] {
    let specs = benchmark_host_specs(size)
    let text_root = @entity.Entity()
    host.mount(text_root, specs) catch {
      error => abort(error.to_string())
    }
    let target = "text-" + (size / 2).to_string()
    let set_low = [@ui_view.TreeMutation::SetText(target, "Low")]
    let set_high = [@ui_view.TreeMutation::SetText(target, "High")]
    let mut high = false
    b.bench(
      name="host/set-text/n=" + size.to_string(),
      fn() {
        high = !high
        host.apply(text_root, if high { set_high } else { set_low }) catch {
          error => abort(error.to_string())
        }
      },
      count=5,
    )
    host.unmount(text_root) catch {
      error => abort(error.to_string())
    }
    text_root.destroy()

    let move_root = @entity.Entity()
    host.mount(move_root, specs) catch {
      error => abort(error.to_string())
    }
    let moved_key = "text-" + (size - 1).to_string()
    let move_first = [@ui_view.TreeMutation::Move(moved_key, "root", 0)]
    let move_last = [@ui_view.TreeMutation::Move(moved_key, "root", size - 1)]
    let mut at_front = false
    b.bench(
      name="host/move-last-first/n=" + size.to_string(),
      fn() {
        at_front = !at_front
        host.apply(move_root, if at_front { move_first } else { move_last }) catch {
          error => abort(error.to_string())
        }
      },
      count=5,
    )
    host.unmount(move_root) catch {
      error => abort(error.to_string())
    }
    move_root.destroy()
  }
}
