///|
fn with_component_host_world(action : () -> Unit raise) -> Unit raise {
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
test "CH-SEMANTICS-01 projects Update style and behavior into Selene stores" {
  with_component_host_world(fn() raise {
    let host = @component_host.MountedView::new()
    let base = @ui_host.NodeStyle::default()
    let title : @ui_host.NodeSpec = {
      key: "title",
      parent: Some("root"),
      kind: Text,
      text: "Before",
      source: "",
      active: true,
      enabled: true,
      focusable: false,
      visual_state_groups: [],
      style: { ..base, color: "white", font_size: 20.0 },
    }
    let action_spec : @ui_host.NodeSpec = {
      key: "action",
      parent: Some("root"),
      kind: Button,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: true,
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
        visual_state_groups: [],
        style: {
          ..base,
          width: @ui_host.LayoutValue::Percent(1.0),
          height: @ui_host.LayoutValue::Px(320.0),
          direction: Row,
          flex_basis: @ui_host.LayoutValue::Percent(0.5),
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
test "CH-ATOMIC-01 validates the full batch before retaining final identities" {
  with_component_host_world(fn() raise {
    let host = @component_host.MountedView::new()
    let base = @ui_host.NodeStyle::default()
    let title : @ui_host.NodeSpec = {
      key: "title",
      parent: Some("root"),
      kind: Text,
      text: "Ready",
      source: "",
      active: true,
      enabled: true,
      focusable: false,
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
      @ui_host.HostError::InvalidMutation(code, _) =>
        inspect(code, content="SH1015")
      error => raise error
    } noraise {
      _ => fail("expected the invalid target kind to reject the batch")
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
test "CH-INCREMENTAL-01 commits only mutation targets and affected hierarchy" {
  with_component_host_world(fn() raise {
    let host = @component_host.MountedView::new()
    let base = @ui_host.NodeStyle::default()
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
test "CH-LIMIT-01 enforces mutation and node limits atomically" {
  with_component_host_world(fn() raise {
    let base = @ui_host.NodeStyle::default()
    let accepted = @component_host.MountedView::new()
    let accepted_batch : Array[@ui_host.TreeMutation] = [
      Mount({
        key: "root",
        parent: None,
        kind: View,
        text: "",
        source: "",
        active: true,
        enabled: true,
        focusable: false,
        visual_state_groups: [],
        style: base,
      }),
    ]
    for index = 0; index < 128; index = index + 1 {
      accepted_batch.push(
        Mount({
          key: "child-" + index.to_string(),
          parent: Some("root"),
          kind: View,
          text: "",
          source: "",
          active: true,
          enabled: true,
          focusable: false,
          visual_state_groups: [],
          style: base,
        }),
      )
    }
    accepted.apply(accepted_batch)
    debug_inspect(
      (
        accepted.entity("root") is Some(_),
        accepted.entity("child-127") is Some(_),
      ),
      content="(true, true)",
    )
    let maximum_mutations : Array[@ui_host.TreeMutation] = []
    for index = 0; index < 512; index = index + 1 {
      maximum_mutations.push(SetActive("root", index % 2 == 0))
    }
    accepted.apply(maximum_mutations)
    let root = accepted.entity("root").unwrap()
    inspect(@ui.nodes()[root].active, content="false")
    let oversized_mutations = maximum_mutations.copy()
    oversized_mutations.push(SetActive("root", true))
    try accepted.apply(oversized_mutations) catch {
      @ui_host.HostError::InvalidMutation(code, message) =>
        debug_inspect(
          (code, message),
          content="(\"SH1010\", \"mutation batch exceeds the 512 operation limit\")",
        )
      error => raise error
    } noraise {
      _ => fail("513 mutations must exceed the component limit")
    }
    debug_inspect(
      (accepted.entity("root") == Some(root), @ui.nodes()[root].active),
      content="(true, false)",
    )
    let rejected = @component_host.MountedView::new()
    let rejected_batch : Array[@ui_host.TreeMutation] = [
      Mount({
        key: "root",
        parent: None,
        kind: View,
        text: "",
        source: "",
        active: true,
        enabled: true,
        focusable: false,
        visual_state_groups: [],
        style: base,
      }),
    ]
    for index = 0; index < 256; index = index + 1 {
      rejected_batch.push(
        Mount({
          key: "child-" + index.to_string(),
          parent: Some("root"),
          kind: View,
          text: "",
          source: "",
          active: true,
          enabled: true,
          focusable: false,
          visual_state_groups: [],
          style: base,
        }),
      )
    }
    try rejected.apply(rejected_batch) catch {
      @ui_host.HostError::InvalidMutation(code, message) =>
        debug_inspect(
          (code, message),
          content="(\"SH1011\", \"component view exceeds the 256 node limit\")",
        )
      error => raise error
    } noraise {
      _ => fail("257 live nodes must exceed the component limit")
    }
    debug_inspect(rejected.container().get_children(), content="[]")
    accepted.release()
    rejected.release()
  })
}

///|
test "CH-RELOAD-01 swap restores focus and scroll by stable key" {
  with_component_host_world(fn() raise {
    let parent = @entity.Entity()
    let base = @ui_host.NodeStyle::default()
    let app = @app.App()
      .with_world(@ecs.require_current_world())
      .add_message(@ui.click_event_bus)
      .add_plugin(@component_host.plugin)
    let focus_reader : @event.EventReader[@component_host.UiComponentEvent] = @event.EventReader()
    let live = @component_host.MountedView::new()
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
        visual_state_groups: [],
        style: {
          ..base,
          width: @ui_host.LayoutValue::Px(200.0),
          height: @ui_host.LayoutValue::Px(100.0),
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
      focus_reader
      .read(@component_host.component_event_bus)
      .map(event => event.event),
      content="[{ kind: Focus, key: \"play\" }]",
    )
    try live.swap(live) catch {
      @ui_host.HostError::InvalidMutation(code, message) =>
        debug_inspect(
          (code, message),
          content="(\"SH2002\", \"live and staged view entities must be distinct\")",
        )
      error => raise error
    } noraise {
      _ => fail("a component host cannot be swapped with itself")
    }
    debug_inspect(
      (
        live.entity("play") == Some(old_play),
        live.container().get_parent() == Some(parent),
        @ui.focused_entity() == Some(old_play),
      ),
      content="(true, true, true)",
    )
    let staged = @component_host.MountedView::new()
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
        visual_state_groups: [],
        style: {
          ..base,
          width: @ui_host.LayoutValue::Px(240.0),
          height: @ui_host.LayoutValue::Px(120.0),
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
      focus_reader
      .read(@component_host.component_event_bus)
      .map(event => event.event),
      content="[]",
    )
    let disabled = @component_host.MountedView::new()
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
      focus_reader
      .read(@component_host.component_event_bus)
      .map(event => event.event),
      content="[]",
    )
    disabled.release()
  })
}

///|
test "CH-EVENT-01 plugin routes click and focus to typed stable-key events" {
  with_component_host_world(fn() raise {
    let host = @component_host.MountedView::new()
    let style = @ui_host.NodeStyle::default()
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
        visual_state_groups: [],
        style,
      }),
    ])
    let app = @app.App()
      .with_world(@ecs.require_current_world())
      .add_message(@ui.click_event_bus)
      .add_plugin(@component_host.plugin)
    let reader : @event.EventReader[@component_host.UiComponentEvent] = @event.EventReader()
    app.run_frames(1)
    let restart = host.entity("restart").unwrap()
    @ui.click_event_bus.send({ entity: restart, button: @inputs.Left })
    app.run_frames(1)
    debug_inspect(
      reader.read(@component_host.component_event_bus).map(value => value.event),
      content="[{ kind: Click, key: \"restart\" }]",
    )
    @ui.focus(restart)
    app.run_frames(1)
    debug_inspect(
      reader.read(@component_host.component_event_bus).map(value => value.event),
      content="[{ kind: Focus, key: \"restart\" }]",
    )
    host.release()
  })
}

///|
test "CH-VISUAL-STATE-01 overlays selection and interaction on retained atlas nodes" {
  with_component_host_world(fn() raise {
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
    let base = @ui_host.NodeStyle::default()
    let selection : @ui_host.VisualStateGroup = {
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
              value: @ui_host.VisualStateValue::StringValue(
                "assets/tabs.atlas.json#equip.normal",
              ),
            },
          ],
        },
        {
          name: "Selected",
          setters: [
            {
              target: "tab",
              property: "Background",
              value: @ui_host.VisualStateValue::StringValue("#6b3d26"),
            },
            {
              target: "icon",
              property: "Source",
              value: @ui_host.VisualStateValue::StringValue(
                "assets/tabs.atlas.json#equip.selected",
              ),
            },
            {
              target: "label",
              property: "Bold",
              value: @ui_host.VisualStateValue::BoolValue(true),
            },
          ],
        },
      ],
      transitions: [],
    }
    let interaction : @ui_host.VisualStateGroup = {
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
              value: @ui_host.VisualStateValue::StringValue("#ffd779"),
            },
            {
              target: "tab",
              property: "OutlineWidth",
              value: @ui_host.VisualStateValue::DoubleValue(2.0),
            },
          ],
        },
        {
          name: "Pressed",
          setters: [
            {
              target: "tab",
              property: "Background",
              value: @ui_host.VisualStateValue::StringValue("#4d2a1c"),
            },
          ],
        },
      ],
      transitions: [],
    }
    let tab_spec : @ui_host.NodeSpec = {
      key: "tab",
      parent: None,
      kind: Button,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: true,
      visual_state_groups: [selection, interaction],
      style: { ..base, background: "#3a281f" },
    }
    let host = @component_host.MountedView::new()
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
        @ui.background_colors()[tab].color,
        @ui.text_fonts()[label].bold,
      ),
      content="(Vec2(32, 0), { r: 107, g: 61, b: 38, a: 1 }, true)",
    )
    let app = @app.App()
      .with_world(@ecs.require_current_world())
      .add_plugin(@component_host.plugin)
    @ui.interactions()[tab] = @ui.Interaction::Pressed
    app.run_frames(1)
    debug_inspect(
      (
        host.entity("tab") == Some(tab),
        host.entity("icon") == Some(icon),
        @ui.ui_images()[icon].image == selected_image.image,
        @ui.ui_images()[icon].source.unwrap().position,
        @ui.background_colors()[tab].color,
      ),
      content=(
        #|(true, true, true, Vec2(32, 0), { r: 77, g: 42, b: 28, a: 1 })
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
      ),
      content="(true, true, true, Vec2(0, 0))",
    )
    host.release()
    @atlas.clear_texture_atlas_cache()
    @asset.set_io(fn(_path) { None })
  })
}

///|
test "CH-VISUAL-STATE-02 transitions colors without replacing the target Entity" {
  with_component_host_world(fn() raise {
    let base = @ui_host.NodeStyle::default()
    let normal_group : @ui_host.VisualStateGroup = {
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
              value: @ui_host.VisualStateValue::StringValue("#000000"),
            },
          ],
        },
        {
          name: "Selected",
          setters: [
            {
              target: "tab",
              property: "Background",
              value: @ui_host.VisualStateValue::StringValue("#ffffff"),
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
    let tab_spec : @ui_host.NodeSpec = {
      key: "tab",
      parent: None,
      kind: Button,
      text: "",
      source: "",
      active: true,
      enabled: true,
      focusable: true,
      visual_state_groups: [normal_group],
      style: base,
    }
    let host = @component_host.MountedView::new()
    host.apply([Mount(tab_spec)])
    let tab = host.entity("tab").unwrap()
    let app = @app.App()
      .with_world(@ecs.require_current_world())
      .add_plugin(@component_host.plugin)
    host.apply([
      Update({
        ..tab_spec,
        visual_state_groups: [{ ..normal_group, current: "Selected" }],
      }),
    ])
    debug_inspect(
      @ui.background_colors()[tab].color,
      content="{ r: 0, g: 0, b: 0, a: 1 }",
    )
    app.run_frames(1, raw_delta=0.5)
    debug_inspect(
      (host.entity("tab") == Some(tab), @ui.background_colors()[tab].color),
      content="(true, { r: 128, g: 128, b: 128, a: 1 })",
    )
    app.run_frames(1, raw_delta=0.5)
    debug_inspect(
      @ui.background_colors()[tab].color,
      content="{ r: 255, g: 255, b: 255, a: 1 }",
    )
    host.release()
  })
}
