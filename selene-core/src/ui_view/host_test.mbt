///|
fn with_view_host_world(action : () -> Unit raise) -> Unit raise {
  let previous = @ecs.current_world().unwrap_or(@ecs.bootstrap_world())
  let world = @ecs.World()
  @ecs.set_current_world(world)
  action() catch {
    error => {
      @ecs.set_current_world(previous)
      raise error
    }
  }
  @ecs.set_current_world(previous)
}

///|
test "VH-SEMANTICS-01 projects Update style and behavior into Selene stores" {
  with_view_host_world(fn() raise {
    let host = @ui_view.MountedView::new()
    let base = @ui_view.NodeStyle::default()
    let title : @ui_view.NodeSpec = {
      key: "title",
      parent: Some("root"),
      kind: Text,
      text: "Before",
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
      visual_state_groups: [],
      style: { ..base, color: "white", font_size: 20.0 },
    }
    let action_spec : @ui_view.NodeSpec = {
      key: "action",
      parent: Some("root"),
      kind: Button,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: true,
      tab_index: 0,
      focus_scope: false,
      auto_focus: false,
      navigation_up: "",
      navigation_down: "",
      navigation_left: "",
      navigation_right: "",
      visual_state_groups: [],
      style: base,
    }
    host.apply([
      Mount({
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
        visual_state_groups: [],
        style: {
          ..base,
          width: @ui_view.LayoutValue::Percent(1.0),
          height: @ui_view.LayoutValue::Px(320.0),
          direction: Row,
          flex_basis: @ui_view.LayoutValue::Percent(0.5),
          flex_grow: 2.0,
          flex_shrink: 0.0,
          row_gap: 8.0,
          margin_left: 1.0,
          margin_top: 2.0,
          margin_right: 3.0,
          margin_bottom: 4.0,
          padding_left: 4.0,
          padding_top: 5.0,
          padding_right: 6.0,
          padding_bottom: 7.0,
        },
      }),
      Mount(title),
      Mount(action_spec),
    ])
    let title_entity = host.entity("title").unwrap()
    host.apply([
      Update({ ..title, text: "After", style: { ..title.style, wrap: true } }),
    ])
    let root = host.entity("root").unwrap()
    let action = host.entity("action").unwrap()
    debug_inspect(
      (
        @ui.texts()[title_entity].content,
        @ui.text_layouts()[title_entity].wrap,
        @ui.focusables().contains(action),
        @ui.nodes()[root].margin,
        @ui.nodes()[root].padding,
        @ui.nodes()[root].width,
        @ui.nodes()[root].height,
        @ui.nodes()[root].flex_basis,
        @ui.nodes()[root].flex_grow,
        @ui.nodes()[root].flex_shrink,
        host.entity("title") == Some(title_entity),
      ),
      content=(
        #|(
        #|  "After",
        #|  WordWrap,
        #|  true,
        #|  { left: Px(1), right: Px(3), top: Px(2), bottom: Px(4) },
        #|  { left: Px(4), right: Px(6), top: Px(5), bottom: Px(7) },
        #|  Percent(1),
        #|  Px(320),
        #|  Percent(0.5),
        #|  2,
        #|  0,
        #|  true,
        #|)
      ),
    )
    @ui.focus(action)
    host.apply([Update({ ..action_spec, focusable: false })])
    let focus_after_update = @ui.focused_entity()
    let focusable_after_update = @ui.focusables().contains(action)
    host.apply([Update(action_spec)])
    @ui.focus(action)
    host.apply([SetEnabled("action", false)])
    let focus_after_disable = @ui.focused_entity()
    let enabled_after_disable = @ui.buttons()[action].enabled
    let focusable_after_disable = @ui.focusables().contains(action)
    host.apply([Update(action_spec)])
    @ui.focus(action)
    host.apply([SetActive("action", false)])
    let focus_after_deactivate = @ui.focused_entity()
    let active_after_deactivate = @ui.nodes()[action].active
    let focusable_after_deactivate = @ui.focusables().contains(action)
    host.apply([Update(action_spec)])
    @ui.focus(action)
    host.apply([Remove("action")])
    let focus_after_remove = @ui.focused_entity()
    let removed_action = host.entity("action")
    host.apply([Mount(action_spec)])
    @ui.focus(host.entity("action").unwrap())
    host.release()
    debug_inspect(
      (
        focus_after_update,
        focusable_after_update,
        focus_after_disable,
        enabled_after_disable,
        focusable_after_disable,
        focus_after_deactivate,
        active_after_deactivate,
        focusable_after_deactivate,
        focus_after_remove,
        removed_action,
        @ui.focused_entity(),
      ),
      content=(
        #|(
        #|  None,
        #|  false,
        #|  None,
        #|  false,
        #|  false,
        #|  None,
        #|  false,
        #|  false,
        #|  None,
        #|  None,
        #|  None,
        #|)
      ),
    )
  })
}

///|
test "VH-GRID-01 projects Grid tracks, flow, placement, and spans" {
  with_view_host_world(fn() raise {
    let host = @ui_view.MountedView::new()
    let base = @ui_view.NodeStyle::default()
    host.apply([
      Mount({
        key: "grid",
        parent: None,
        kind: Grid,
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
        visual_state_groups: [],
        style: {
          ..base,
          width: @ui_view.LayoutValue::Px(300.0),
          height: @ui_view.LayoutValue::Px(180.0),
          grid_rows: [
            @ui_view.GridTrack::Auto,
            @ui_view.GridTrack::MinMax(
              @ui_view.GridTrack::Px(40.0),
              @ui_view.GridTrack::Fr(1.0),
            ),
          ],
          grid_columns: [
            @ui_view.GridTrack::Repeat(@ui_view.GridTrackRepetition::Count(3), [
              @ui_view.GridTrack::Fr(1.0),
            ]),
          ],
          grid_auto_flow: ColumnDense,
        },
      }),
      Mount({
        key: "cell",
        parent: Some("grid"),
        kind: View,
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
        visual_state_groups: [],
        style: {
          ..base,
          grid_row: Some(1),
          grid_column: Some(2),
          grid_row_span: 2,
          grid_column_span: 3,
        },
      }),
    ])
    let grid = @ui.nodes()[host.entity("grid").unwrap()]
    let cell = @ui.nodes()[host.entity("cell").unwrap()]
    debug_inspect(
      (
        grid.display,
        grid.grid_template_rows,
        grid.grid_template_columns,
        grid.grid_auto_flow,
        cell.grid_row,
        cell.grid_column,
      ),
      content=(
        #|(
        #|  Grid,
        #|  [Auto, MinMax(Px(40), Fr(1))],
        #|  [Repeat(Count(3), [Fr(1)])],
        #|  ColumnDense,
        #|  { start: Line(2), end: Span(2) },
        #|  { start: Line(3), end: Span(3) },
        #|)
      ),
    )
    host.release()
  })
}

///|
test "VH-FOCUS-01 projects declarative scopes and navigation keys" {
  with_view_host_world(fn() raise {
    let host = @ui_view.MountedView::new()
    let base = @ui_view.NodeStyle::default()
    let root : @ui_view.NodeSpec = {
      key: "root",
      parent: None,
      kind: Flex,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: false,
      tab_index: 0,
      focus_scope: true,
      auto_focus: false,
      navigation_up: "",
      navigation_down: "",
      navigation_left: "",
      navigation_right: "",
      style: {
        ..base,
        width: @ui_view.LayoutValue::Px(200.0),
        height: @ui_view.LayoutValue::Px(80.0),
        direction: Row,
      },
      visual_state_groups: [],
    }
    let first : @ui_view.NodeSpec = {
      key: "first",
      parent: Some("root"),
      kind: Button,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: true,
      tab_index: 10,
      focus_scope: false,
      auto_focus: true,
      navigation_up: "Stop",
      navigation_down: "",
      navigation_left: "",
      navigation_right: "second",
      style: {
        ..base,
        width: @ui_view.LayoutValue::Px(40.0),
        height: @ui_view.LayoutValue::Px(40.0),
      },
      visual_state_groups: [],
    }
    let second : @ui_view.NodeSpec = {
      ..first,
      key: "second",
      auto_focus: false,
      tab_index: 11,
      navigation_up: "",
      navigation_right: "",
      navigation_left: "first",
    }
    host.apply([Mount(root), Mount(first), Mount(second)])
    let root_entity = host.entity("root").unwrap()
    let first_entity = host.entity("first").unwrap()
    let second_entity = host.entity("second").unwrap()
    assert_eq(@ui.focus_scopes().length(), 1)
    assert_eq(@ui.focus_scopes()[0].root, root_entity)
    assert_eq(@ui.focus_scopes()[0].initial_focus, Some(first_entity))
    assert_eq(@ui.tab_indexes()[first_entity], @ui.TabIndex(10))
    assert_eq(@ui.tab_indexes()[second_entity], @ui.TabIndex(11))
    assert_eq(
      @ui.navigation_links()[first_entity].up,
      @ui.UiNavigationRule::Stop,
    )
    assert_eq(
      @ui.navigation_links()[first_entity].right,
      @ui.UiNavigationRule::Explicit(second_entity),
    )
    assert_eq(
      @ui.navigation_links()[second_entity].left,
      @ui.UiNavigationRule::Explicit(first_entity),
    )
    let rect : @math.Rect = {
      position: @math.Vec2(0.0, 0.0),
      size: @math.Vec2(40.0, 40.0),
    }
    @ui.global_ui_nodes()[first_entity] = {
      logical_rect: rect,
      screen_rect: rect,
      logical_content_rect: rect,
      screen_content_rect: rect,
      target_camera: None,
      target_viewport: rect,
    }
    assert_eq(@ui.focused_entity(), Some(first_entity))
    host.release()
    assert_eq(@ui.focus_scopes().is_empty(), true)
  })
}

///|
test "VH-ATOMIC-01 validates the full batch before retaining final identities" {
  with_view_host_world(fn() raise {
    let host = @ui_view.MountedView::new()
    let base = @ui_view.NodeStyle::default()
    let title : @ui_view.NodeSpec = {
      key: "title",
      parent: Some("root"),
      kind: Text,
      text: "Ready",
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
      visual_state_groups: [],
      style: base,
    }
    host.apply([
      Mount({
        key: "root",
        parent: None,
        kind: View,
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
        visual_state_groups: [],
        style: base,
      }),
      Mount(title),
    ])
    let title_entity = host.entity("title").unwrap()
    try
      host.apply([
        SetText("title", "Rejected"),
        SetSource("title", "invalid.png"),
      ])
    catch {
      @ui_view.HostError::InvalidMutation(code, _) =>
        inspect(code, content="SH1015")
      error => raise error
    } noraise {
      _ => fail("expected the invalid target kind to reject the batch")
    }
    inspect(@ui.texts()[title_entity].content, content="Ready")
    try
      host.apply([
        SetText("title", "Still rejected"),
        SetText("missing", "Invalid target"),
      ])
    catch {
      @ui_view.HostError::InvalidMutation(code, _) =>
        inspect(code, content="SH1003")
      error => raise error
    } noraise {
      _ => fail("expected the invalid text target to reject the whole batch")
    }
    inspect(@ui.texts()[title_entity].content, content="Ready")
    host.apply([
      Mount({
        key: "transient",
        parent: Some("root"),
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
        visual_state_groups: [],
        style: base,
      }),
      Remove("transient"),
      Mount({
        key: "panel",
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
        visual_state_groups: [],
        style: base,
      }),
      Move("title", "panel", 0),
      Update({ ..title, parent: Some("panel"), text: "Committed" }),
    ])
    let panel = host.entity("panel").unwrap()
    debug_inspect(
      (
        host.entity("transient"),
        host.entity("title") == Some(title_entity),
        title_entity.get_parent() == Some(panel),
        @ui.texts()[title_entity].content,
      ),
      content="(None, true, true, \"Committed\")",
    )
    host.release()
  })
}

///|
test "VH-INCREMENTAL-01 commits only mutation targets and affected hierarchy" {
  with_view_host_world(fn() raise {
    let host = @ui_view.MountedView::new()
    let base = @ui_view.NodeStyle::default()
    host.apply([
      Mount({
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
        visual_state_groups: [],
        style: base,
      }),
      Mount({
        key: "left",
        parent: Some("root"),
        kind: Text,
        text: "Left",
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
        visual_state_groups: [],
        style: { ..base, font_family: "ThaleahFat", font_size: 18.0 },
      }),
      Mount({
        key: "right",
        parent: Some("root"),
        kind: Text,
        text: "Right",
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
        visual_state_groups: [],
        style: { ..base, font_family: "ThaleahFat", font_size: 18.0 },
      }),
      Mount({
        key: "panel",
        parent: Some("root"),
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
        visual_state_groups: [],
        style: base,
      }),
    ])
    let root = host.entity("root").unwrap()
    let left = host.entity("left").unwrap()
    let right = host.entity("right").unwrap()
    let panel = host.entity("panel").unwrap()
    let root_node = @ui.nodes()[root]
    let panel_node = @ui.nodes()[panel]
    let left_text = @ui.texts()[left]
    let right_text = @ui.texts()[right]
    let right_font = @ui.text_fonts()[right]
    host.apply([
      SetText("left", "Updated"),
      SetBackground("left", "#123456"),
      SetTop("panel", 24.0),
      Move("right", "panel", 0),
    ])
    assert_eq(physical_equal(root_node, @ui.nodes()[root]), true)
    assert_eq(physical_equal(panel_node, @ui.nodes()[panel]), false)
    assert_eq(physical_equal(left_text, @ui.texts()[left]), true)
    assert_eq(physical_equal(right_text, @ui.texts()[right]), true)
    assert_eq(physical_equal(right_font, @ui.text_fonts()[right]), true)
    debug_inspect(
      (
        @ui.texts()[left].content,
        @ui.nodes()[panel].top,
        right.get_parent() == Some(panel),
        root.get_children() == [left, panel],
        panel.get_children() == [right],
      ),
      content="(\"Updated\", Px(24), true, true, true)",
    )
    host.release()
  })
}

///|
test "VH-RELOAD-01 swap restores focus and scroll by stable key" {
  with_view_host_world(fn() raise {
    let parent = @entity.Entity()
    let base = @ui_view.NodeStyle::default()
    let app = @app.App()
      .with_world(@ecs.require_current_world())
      .add_message(@ui.click_event_bus)
      .add_plugin(@ui_view.plugin)
    let focus_reader : @event.EventReader[@ui_view.UiViewEvent] = @event.EventReader()
    let live = @ui_view.MountedView::new()
    live.apply([
      Mount({
        key: "root",
        parent: None,
        kind: View,
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
        visual_state_groups: [],
        style: base,
      }),
      Mount({
        key: "list",
        parent: Some("root"),
        kind: ScrollView,
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
        visual_state_groups: [],
        style: {
          ..base,
          width: @ui_view.LayoutValue::Px(200.0),
          height: @ui_view.LayoutValue::Px(100.0),
        },
      }),
      Mount({
        key: "play",
        parent: Some("root"),
        kind: Button,
        text: "",
        source: "",
        active: true,
        enabled: true,
        focusable: true,
        tab_index: 0,
        focus_scope: false,
        auto_focus: false,
        navigation_up: "",
        navigation_down: "",
        navigation_left: "",
        navigation_right: "",
        visual_state_groups: [],
        style: base,
      }),
    ])
    live.activate(parent)
    let old_list = live.entity("list").unwrap()
    let old_play = live.entity("play").unwrap()
    @ui.scroll_positions()[old_list] = { x: 3.0, y: 87.0 }
    @ui.focus(old_play)
    app.run_frames(1)
    debug_inspect(
      focus_reader.read(@ui_view.view_event_bus).map(event => event.event),
      content="[{ kind: Focus, key: \"play\" }]",
    )
    try live.swap(live) catch {
      @ui_view.HostError::InvalidMutation(code, message) =>
        debug_inspect(
          (code, message),
          content="(\"SH2002\", \"live and staged view entities must be distinct\")",
        )
      error => raise error
    } noraise {
      _ => fail("a view host cannot be swapped with itself")
    }
    debug_inspect(
      (
        live.entity("play") == Some(old_play),
        live.container().get_parent() == Some(parent),
        @ui.focused_entity() == Some(old_play),
      ),
      content="(true, true, true)",
    )
    let staged = @ui_view.MountedView::new()
    staged.apply([
      Mount({
        key: "root",
        parent: None,
        kind: View,
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
        visual_state_groups: [],
        style: base,
      }),
      Mount({
        key: "list",
        parent: Some("root"),
        kind: ScrollView,
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
        visual_state_groups: [],
        style: {
          ..base,
          width: @ui_view.LayoutValue::Px(240.0),
          height: @ui_view.LayoutValue::Px(120.0),
        },
      }),
      Mount({
        key: "play",
        parent: Some("root"),
        kind: Button,
        text: "",
        source: "",
        active: true,
        enabled: true,
        focusable: true,
        tab_index: 0,
        focus_scope: false,
        auto_focus: false,
        navigation_up: "",
        navigation_down: "",
        navigation_left: "",
        navigation_right: "",
        visual_state_groups: [],
        style: base,
      }),
    ])
    live.swap(staged)
    app.run_frames(1)
    let new_list = staged.entity("list").unwrap()
    let new_play = staged.entity("play").unwrap()
    debug_inspect(
      (
        new_list == old_list,
        @ui.scroll_positions()[new_list],
        @ui.focused_entity() == Some(new_play),
        parent.get_children() == [staged.container()],
      ),
      content="(false, { x: 3, y: 87 }, true, true)",
    )
    debug_inspect(
      focus_reader.read(@ui_view.view_event_bus).map(event => event.event),
      content="[]",
    )
    let disabled = @ui_view.MountedView::new()
    disabled.apply([
      Mount({
        key: "root",
        parent: None,
        kind: View,
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
        visual_state_groups: [],
        style: base,
      }),
      Mount({
        key: "play",
        parent: Some("root"),
        kind: Button,
        text: "",
        source: "",
        active: true,
        enabled: false,
        focusable: true,
        tab_index: 0,
        focus_scope: false,
        auto_focus: false,
        navigation_up: "",
        navigation_down: "",
        navigation_left: "",
        navigation_right: "",
        visual_state_groups: [],
        style: base,
      }),
    ])
    staged.swap(disabled)
    app.run_frames(1)
    let disabled_play = disabled.entity("play").unwrap()
    debug_inspect(
      (
        @ui.buttons()[disabled_play].enabled,
        @ui.focusables().contains(disabled_play),
        @ui.focused_entity(),
        parent.get_children() == [disabled.container()],
      ),
      content="(false, false, None, true)",
    )
    debug_inspect(
      focus_reader.read(@ui_view.view_event_bus).map(event => event.event),
      content="[]",
    )
    disabled.release()
  })
}

///|
test "VH-EVENT-01 plugin routes click and focus to typed stable-key events" {
  with_view_host_world(fn() raise {
    let host = @ui_view.MountedView::new()
    let style = @ui_view.NodeStyle::default()
    host.apply([
      Mount({
        key: "root",
        parent: None,
        kind: View,
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
        visual_state_groups: [],
        style,
      }),
      Mount({
        key: "restart",
        parent: Some("root"),
        kind: Button,
        text: "",
        source: "",
        active: true,
        enabled: true,
        focusable: true,
        tab_index: 0,
        focus_scope: false,
        auto_focus: false,
        navigation_up: "",
        navigation_down: "",
        navigation_left: "",
        navigation_right: "",
        visual_state_groups: [],
        style,
      }),
    ])
    let app = @app.App()
      .with_world(@ecs.require_current_world())
      .add_message(@ui.click_event_bus)
      .add_plugin(@ui_view.plugin)
    let reader : @event.EventReader[@ui_view.UiViewEvent] = @event.EventReader()
    app.run_frames(1)
    let restart = host.entity("restart").unwrap()
    @ui.click_event_bus.send({ entity: restart, button: @inputs.Left })
    app.run_frames(1)
    debug_inspect(
      reader.read(@ui_view.view_event_bus).map(value => value.event),
      content="[{ kind: Click, key: \"restart\" }]",
    )
    @ui.focus(restart)
    app.run_frames(1)
    debug_inspect(
      reader.read(@ui_view.view_event_bus).map(value => value.event),
      content="[{ kind: Focus, key: \"restart\" }]",
    )
    host.release()
  })
}

///|
test "VH-VISUAL-STATE-01 overlays selection and interaction on retained atlas nodes" {
  with_view_host_world(fn() raise {
    @atlas.clear_texture_atlas_cache()
    @asset.set_io(fn(path) {
      match path {
        "assets/tabs.atlas.json" =>
          Some(
            @utf8.encode(
              (
                #|{"schema":"selene/atlas_asset_document","version":1,"data":{
                #|  "source_image":"tabs.png","regions":[
                #|    {"name":"equip.normal","index":0,"rect":{"x":0,"y":0,"width":32,"height":32}},
                #|    {"name":"equip.selected","index":1,"rect":{"x":32,"y":0,"width":32,"height":32}}
                #|  ]}}
              ),
            ),
          )
        "assets/tabs.png" => {
          let png = @buffer.Buffer()
          png.write_bytes(b"\x89PNG\r\n\x1a\n")
          png.write_uint_be(13U)
          png.write_bytes(b"IHDR")
          png.write_uint_be(64U)
          png.write_uint_be(32U)
          Some(png.contents())
        }
        _ => None
      }
    })
    let base = @ui_view.NodeStyle::default()
    let selection : @ui_view.VisualStateGroup = {
      order: 0,
      name: "SelectionStates",
      current: "Selected",
      interaction: false,
      states: [
        {
          name: "Normal",
          setters: [
            {
              target: "icon",
              property: "Source",
              value: @ui_view.VisualStateValue::StringValue(
                "assets/tabs.atlas.json#equip.normal",
              ),
            },
            {
              target: "icon",
              property: "Tint",
              value: @ui_view.VisualStateValue::StringValue("#ffffff"),
            },
          ],
        },
        {
          name: "Selected",
          setters: [
            {
              target: "tab",
              property: "Background",
              value: @ui_view.VisualStateValue::StringValue("#6b3d26"),
            },
            {
              target: "icon",
              property: "Source",
              value: @ui_view.VisualStateValue::StringValue(
                "assets/tabs.atlas.json#equip.selected",
              ),
            },
            {
              target: "icon",
              property: "Tint",
              value: @ui_view.VisualStateValue::StringValue("#d08040"),
            },
            {
              target: "label",
              property: "Bold",
              value: @ui_view.VisualStateValue::BoolValue(true),
            },
          ],
        },
      ],
      transitions: [],
    }
    let interaction : @ui_view.VisualStateGroup = {
      order: 1,
      name: "InteractionStates",
      current: "",
      interaction: true,
      states: [
        { name: "Normal", setters: [] },
        {
          name: "Focused",
          setters: [
            {
              target: "tab",
              property: "OutlineColor",
              value: @ui_view.VisualStateValue::StringValue("#ffd779"),
            },
            {
              target: "tab",
              property: "OutlineWidth",
              value: @ui_view.VisualStateValue::DoubleValue(2.0),
            },
          ],
        },
        {
          name: "Pressed",
          setters: [
            {
              target: "tab",
              property: "Background",
              value: @ui_view.VisualStateValue::StringValue("#4d2a1c"),
            },
          ],
        },
      ],
      transitions: [],
    }
    let tab_spec : @ui_view.NodeSpec = {
      key: "tab",
      parent: None,
      kind: Button,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: true,
      tab_index: 0,
      focus_scope: false,
      auto_focus: false,
      navigation_up: "",
      navigation_down: "",
      navigation_left: "",
      navigation_right: "",
      visual_state_groups: [selection, interaction],
      style: { ..base, background: "#3a281f" },
    }
    let host = @ui_view.MountedView::new()
    host.apply([
      Mount(tab_spec),
      Mount({
        key: "icon",
        parent: Some("tab"),
        kind: Image,
        text: "",
        source: "assets/tabs.atlas.json#equip.normal",
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
        visual_state_groups: [],
        style: base,
      }),
      Mount({
        key: "label",
        parent: Some("tab"),
        kind: Text,
        text: "Equip",
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
        visual_state_groups: [],
        style: base,
      }),
    ])
    let tab = host.entity("tab").unwrap()
    let icon = host.entity("icon").unwrap()
    let label = host.entity("label").unwrap()
    let selected_image = @ui.ui_images()[icon]
    debug_inspect(
      (
        selected_image.source.unwrap().position,
        selected_image.tint,
        @ui.background_colors()[tab].color,
        @ui.text_fonts()[label].bold,
      ),
      content=(
        #|(
        #|  Vec2(32, 0),
        #|  { r: 208, g: 128, b: 64, a: 1 },
        #|  { r: 107, g: 61, b: 38, a: 1 },
        #|  true,
        #|)
      ),
    )
    let app = @app.App()
      .with_world(@ecs.require_current_world())
      .add_plugin(@ui_view.plugin)
    @ui.interactions()[tab] = @ui.Interaction::Pressed
    app.run_frames(1)
    debug_inspect(
      (
        host.entity("tab") == Some(tab),
        host.entity("icon") == Some(icon),
        @ui.ui_images()[icon].image == selected_image.image,
        @ui.ui_images()[icon].source.unwrap().position,
        @ui.ui_images()[icon].tint,
        @ui.background_colors()[tab].color,
      ),
      content=(
        #|(
        #|  true,
        #|  true,
        #|  true,
        #|  Vec2(32, 0),
        #|  { r: 208, g: 128, b: 64, a: 1 },
        #|  { r: 77, g: 42, b: 28, a: 1 },
        #|)
      ),
    )
    @ui.interactions()[tab] = @ui.Interaction::None
    @ui.focus(tab)
    app.run_frames(1)
    debug_inspect(
      (@ui.outlines()[tab].width, @ui.outlines()[tab].color),
      content="(Px(2), { r: 255, g: 215, b: 121, a: 1 })",
    )
    host.apply([
      Update({
        ..tab_spec,
        visual_state_groups: [{ ..selection, current: "Normal" }, interaction],
      }),
    ])
    debug_inspect(
      (
        host.entity("tab") == Some(tab),
        host.entity("icon") == Some(icon),
        @ui.ui_images()[icon].image == selected_image.image,
        @ui.ui_images()[icon].source.unwrap().position,
        @ui.ui_images()[icon].tint,
      ),
      content=(
        #|(true, true, true, Vec2(0, 0), { r: 255, g: 255, b: 255, a: 1 })
      ),
    )
    host.release()
    @atlas.clear_texture_atlas_cache()
    @asset.set_io(fn(_path) { None })
  })
}

///|
test "VH-IMAGE-01 projects explicit source regions and rejects atlas conflicts" {
  with_view_host_world(fn() raise {
    @atlas.clear_texture_atlas_cache()
    @asset.set_io(fn(path) {
      match path {
        "assets/sheet.atlas.json" =>
          Some(
            @utf8.encode(
              (
                #|{"schema":"selene/atlas_asset_document","version":1,"data":{
                #|  "source_image":"sheet.png","regions":[
                #|    {"name":"first","index":0,"rect":{"x":0,"y":0,"width":16,"height":12}}
                #|  ]}}
              ),
            ),
          )
        "assets/sheet.png" => {
          let png = @buffer.Buffer()
          png.write_bytes(b"\x89PNG\r\n\x1a\n")
          png.write_uint_be(13U)
          png.write_bytes(b"IHDR")
          png.write_uint_be(128U)
          png.write_uint_be(64U)
          Some(png.contents())
        }
        _ => None
      }
    })
    let base = @ui_view.NodeStyle::default()
    let selected_region : @render2d_types.ImageRegion2D = {
      position: @math.Vec2(40.0, 8.0),
      size: @math.Vec2(16.0, 12.0),
    }
    let normal_region : @render2d_types.ImageRegion2D = {
      position: @math.Vec2(4.0, 2.0),
      size: @math.Vec2(20.0, 14.0),
    }
    let selected : @ui_view.VisualStateGroup = {
      order: 0,
      name: "SelectionStates",
      current: "Selected",
      interaction: false,
      states: [
        {
          name: "Normal",
          setters: [
            {
              target: "icon",
              property: "SourceRegion",
              value: @ui_view.VisualStateValue::ImageRegionValue(
                Some(normal_region),
              ),
            },
          ],
        },
        {
          name: "Selected",
          setters: [
            {
              target: "icon",
              property: "SourceRegion",
              value: @ui_view.VisualStateValue::ImageRegionValue(
                Some(selected_region),
              ),
            },
          ],
        },
        {
          name: "Clear",
          setters: [
            {
              target: "icon",
              property: "SourceRegion",
              value: @ui_view.VisualStateValue::ImageRegionValue(None),
            },
          ],
        },
      ],
      transitions: [],
    }
    let icon_spec : @ui_view.NodeSpec = {
      key: "icon",
      parent: None,
      kind: Image,
      text: "",
      source: "assets/sheet.png",
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
      visual_state_groups: [selected],
      style: { ..base, source_region: Some(normal_region) },
    }
    let host = @ui_view.MountedView::new()
    host.apply([Mount(icon_spec)])
    let icon = host.entity("icon").unwrap()
    debug_inspect(
      (@ui.ui_images()[icon].source, @ui.ui_images()[icon].intrinsic_size()),
      content=(
        #|(Some({ position: Vec2(40, 8), size: Vec2(16, 12) }), Vec2(16, 12))
      ),
    )
    host.apply([
      Update({
        ..icon_spec,
        visual_state_groups: [{ ..selected, current: "Normal" }],
      }),
    ])
    debug_inspect(
      (
        host.entity("icon") == Some(icon),
        @ui.ui_images()[icon].source,
        @ui.ui_images()[icon].intrinsic_size(),
      ),
      content=(
        #|(
        #|  true,
        #|  Some({ position: Vec2(4, 2), size: Vec2(20, 14) }),
        #|  Vec2(20, 14),
        #|)
      ),
    )
    host.apply([
      Update({
        ..icon_spec,
        visual_state_groups: [{ ..selected, current: "Clear" }],
      }),
    ])
    debug_inspect(
      (
        host.entity("icon") == Some(icon),
        @ui.ui_images()[icon].source,
        @ui.ui_images()[icon].intrinsic_size(),
      ),
      content=(
        #|(true, None, Vec2(128, 64))
      ),
    )
    try
      host.apply([
        Update({ ..icon_spec, source: "assets/sheet.atlas.json#first" }),
      ])
    catch {
      @ui_view.HostError::InvalidMutation(code, message) =>
        debug_inspect(
          (code, message),
          content=(
            #|(
            #|  "SH1024",
            #|  "Image cannot combine atlas #region Source with SourceRegion: icon",
            #|)
          ),
        )
      error => raise error
    } noraise {
      _ => fail("atlas #region and SourceRegion must be rejected atomically")
    }
    debug_inspect(
      (host.entity("icon") == Some(icon), @ui.ui_images()[icon].source),
      content=(
        #|(true, None)
      ),
    )
    host.release()
    @atlas.clear_texture_atlas_cache()
    @asset.set_io(fn(_path) { None })
  })
}

///|
test "VH-VISUAL-STATE-02 transitions colors without replacing the target Entity" {
  with_view_host_world(fn() raise {
    let base = @ui_view.NodeStyle::default()
    let normal_group : @ui_view.VisualStateGroup = {
      order: 0,
      name: "SelectionStates",
      current: "Normal",
      interaction: false,
      states: [
        {
          name: "Normal",
          setters: [
            {
              target: "tab",
              property: "Background",
              value: @ui_view.VisualStateValue::StringValue("#000000"),
            },
            {
              target: "icon",
              property: "Tint",
              value: @ui_view.VisualStateValue::StringValue("#000000"),
            },
          ],
        },
        {
          name: "Selected",
          setters: [
            {
              target: "tab",
              property: "Background",
              value: @ui_view.VisualStateValue::StringValue("#ffffff"),
            },
            {
              target: "icon",
              property: "Tint",
              value: @ui_view.VisualStateValue::StringValue("#ffffff"),
            },
          ],
        },
      ],
      transitions: [
        {
          from: Some("Normal"),
          to: Some("Selected"),
          duration: 1.0,
          delay: 0.0,
          easing: "Linear",
        },
      ],
    }
    let tab_spec : @ui_view.NodeSpec = {
      key: "tab",
      parent: None,
      kind: Button,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: true,
      tab_index: 0,
      focus_scope: false,
      auto_focus: false,
      navigation_up: "",
      navigation_down: "",
      navigation_left: "",
      navigation_right: "",
      visual_state_groups: [normal_group],
      style: base,
    }
    let host = @ui_view.MountedView::new()
    host.apply([
      Mount(tab_spec),
      Mount({
        key: "icon",
        parent: Some("tab"),
        kind: Image,
        text: "",
        source: "assets/icon.png",
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
        visual_state_groups: [],
        style: base,
      }),
    ])
    let tab = host.entity("tab").unwrap()
    let icon = host.entity("icon").unwrap()
    let app = @app.App()
      .with_world(@ecs.require_current_world())
      .add_plugin(@ui_view.plugin)
    host.apply([
      Update({
        ..tab_spec,
        visual_state_groups: [{ ..normal_group, current: "Selected" }],
      }),
    ])
    debug_inspect(
      (@ui.background_colors()[tab].color, @ui.ui_images()[icon].tint),
      content=(
        #|({ r: 0, g: 0, b: 0, a: 1 }, { r: 0, g: 0, b: 0, a: 1 })
      ),
    )
    app.run_frames(1, raw_delta=0.5)
    debug_inspect(
      (
        host.entity("tab") == Some(tab),
        host.entity("icon") == Some(icon),
        @ui.background_colors()[tab].color,
        @ui.ui_images()[icon].tint,
      ),
      content=(
        #|(
        #|  true,
        #|  true,
        #|  { r: 128, g: 128, b: 128, a: 1 },
        #|  { r: 128, g: 128, b: 128, a: 1 },
        #|)
      ),
    )
    app.run_frames(1, raw_delta=0.5)
    debug_inspect(
      (@ui.background_colors()[tab].color, @ui.ui_images()[icon].tint),
      content=(
        #|({ r: 255, g: 255, b: 255, a: 1 }, { r: 255, g: 255, b: 255, a: 1 })
      ),
    )
    host.release()
  })
}

///|
test "VH-RECONCILE-01 marks retained keyed siblings in an LIS" {
  debug_inspect(
    [
      @ui_view.retained_lis_mask([0, 1, 2, 3]),
      @ui_view.retained_lis_mask([3, 0, 1, 2]),
      @ui_view.retained_lis_mask([1, 2, 3, 0]),
      @ui_view.retained_lis_mask([-1, 0, 1, 2]),
      @ui_view.retained_lis_mask([3, 2, 1, 0]),
      @ui_view.retained_lis_mask([]),
    ],
    content=(
      #|[
      #|  [true, true, true, true],
      #|  [false, true, true, true],
      #|  [true, true, true, false],
      #|  [false, true, true, true],
      #|  [false, false, false, true],
      #|  [],
      #|]
    ),
  )
}
