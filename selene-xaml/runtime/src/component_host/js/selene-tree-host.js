function bridge() {
  const value = globalThis.__seleneUiComponentHost;
  if (!value) {
    throw new Error("install_browser_host() must run before registering the Selene tree host");
  }
  return value;
}

function normalizeLayoutValue(value) {
  return {
    kind: value.tag,
    value: value.val ?? 0,
  };
}

function normalizeVisualStateValue(value) {
  const base = {
    tag: "",
    string_value: "",
    bool_value: false,
    number_value: 0,
    layout_kind: "auto",
    layout_value: 0,
  };
  if (value.tag === "string-value") {
    return { ...base, tag: "string", string_value: value.val };
  }
  if (value.tag === "bool-value") {
    return { ...base, tag: "bool", bool_value: value.val };
  }
  if (value.tag === "double-value" || value.tag === "int-value") {
    return { ...base, tag: value.tag === "double-value" ? "double" : "int", number_value: value.val };
  }
  const layout = normalizeLayoutValue(value.val);
  return { ...base, tag: "layout", layout_kind: layout.kind, layout_value: layout.value };
}

function normalizeVisualStateGroup(group) {
  return {
    order: group.order,
    name: group.name,
    current: group.current,
    interaction: group.interaction,
    states: group.states.map((state) => ({
      name: state.name,
      setters: state.setters.map((setter) => ({
        target: setter.target,
        property: setter.property,
        value: normalizeVisualStateValue(setter.value),
      })),
    })),
    transitions: group.transitions.map((transition) => ({
      from: transition.from ?? "",
      to: transition.to ?? "",
      duration: transition.duration,
      delay: transition.delay,
      easing: transition.easing,
    })),
  };
}

function normalize(mutation) {
  const { tag, val } = mutation;
  const base = {
    tag,
    key: "",
    text_value: "",
    bool_value: false,
    number_value: 0,
    parent: "",
    index: 0,
    spec: null,
  };
  if (tag === "mount" || tag === "update") {
    return {
      ...base,
      spec: {
        key: val.key,
        parent: val.parent ?? "",
        kind: val.kind,
        text: val.text,
        source: val.source,
        active: val.active,
        enabled: val.enabled,
        focusable: val.focusable,
        style: {
          absolute: val.style.absolute,
          left: val.style.left,
          top: val.style.top,
          width_kind: val.style.width.tag,
          width_value: val.style.width.val ?? 0,
          height_kind: val.style.height.tag,
          height_value: val.style.height.val ?? 0,
          margin_left: val.style.marginLeft,
          margin_top: val.style.marginTop,
          margin_right: val.style.marginRight,
          margin_bottom: val.style.marginBottom,
          padding_left: val.style.paddingLeft,
          padding_top: val.style.paddingTop,
          padding_right: val.style.paddingRight,
          padding_bottom: val.style.paddingBottom,
          background: val.style.background,
          border_color: val.style.borderColor,
          border: val.style.border,
          radius: val.style.radius,
          outline_color: val.style.outlineColor,
          outline_width: val.style.outlineWidth,
          outline_offset: val.style.outlineOffset,
          color: val.style.color,
          font_family: val.style.fontFamily,
          font_size: val.style.fontSize,
          bold: val.style.bold,
          align: val.style.align,
          wrap: val.style.wrap,
          z_index: val.style.zIndex,
          fit: val.style.fit,
          direction: val.style.direction,
          flex_basis_kind: val.style.flexBasis.tag,
          flex_basis_value: val.style.flexBasis.val ?? 0,
          flex_grow: val.style.flexGrow,
          flex_shrink: val.style.flexShrink,
          row_gap: val.style.rowGap,
          column_gap: val.style.columnGap,
          horizontal_scroll: val.style.horizontalScroll,
          vertical_scroll: val.style.verticalScroll,
          scrollbar_width: val.style.scrollbarWidth,
        },
        visual_state_groups: val.visualStateGroups.map(normalizeVisualStateGroup),
      },
    };
  }
  if (tag === "remove") return { ...base, key: val };
  if (tag === "move") return { ...base, key: val.key, parent: val.parent, index: val.index };
  if (tag === "set-text" || tag === "set-source" || tag === "set-background") {
    return { ...base, key: val.key, text_value: val.value };
  }
  if (tag === "set-active" || tag === "set-enabled") {
    return { ...base, key: val.key, bool_value: val.value };
  }
  if (tag === "set-top") return { ...base, key: val.key, number_value: val.value };
  throw new Error(`unknown Selene tree mutation: ${tag}`);
}

export function createSeleneTreeHost() {
  let activeEntities = null;
  return {
    invoke(entities, operation) {
      if (activeEntities) throw new Error("nested Component Guest call is unsupported");
      activeEntities = new Set(entities);
      try {
        return operation();
      } finally {
        activeEntities = null;
      }
    },
    apply(entity, mutations) {
      if (!activeEntities?.has(entity)) {
        throw new Error("Component instance does not own the Selene Entity");
      }
      const error = bridge().apply(entity, JSON.stringify(mutations.map(normalize)));
      if (error) throw new Error(error);
    },
    isAlive(entity) {
      return bridge().isAlive(entity);
    },
    release(entity) {
      bridge().release(entity);
    },
  };
}
