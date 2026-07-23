export function createMockTreeHost(limits = {}) {
  const configured = {
    maxInstances: limits.maxInstances ?? 64,
    maxNodesPerInstance: limits.maxNodesPerInstance ?? 256,
    maxMutationsPerCall: limits.maxMutationsPerCall ?? 512,
  };
  const views = new Map();
  const alive = new Set();
  let activeEntities = null;
  let nextEntity = 1;
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
    register(entity) {
      alive.add(entity);
    },
    destroy(entity) {
      alive.delete(entity);
    },
    isAlive(entity) {
      return alive.has(entity);
    },
    apply(entity, mutations) {
      if (!activeEntities?.has(entity)) {
        throw new Error("Component instance does not own the Selene Entity");
      }
      if (mutations.length > configured.maxMutationsPerCall) {
        throw new Error("mutation batch exceeds component limit");
      }
      if (!alive.has(entity)) throw new Error("unknown or dead Selene Entity");
      if (!views.has(entity) && views.size >= configured.maxInstances) {
        throw new Error("instance limit exceeded");
      }
      const current = views.get(entity) ?? new Map();
      const staged = new Map(
        [...current].map(([key, node]) => [key, { ...node, style: { ...node.style } }]),
      );
      for (const mutation of mutations) {
        const { tag, val } = mutation;
        if (tag === "mount") {
          if (staged.has(val.key) || (val.parent && !staged.has(val.parent))) {
            throw new Error(`invalid mount ${val.key}`);
          }
          staged.set(val.key, { ...val, entity: nextEntity++ });
          continue;
        }
        if (tag === "update") {
          const previous = staged.get(val.key);
          if (!previous || previous.parent !== val.parent) {
            throw new Error(`invalid update ${val.key}`);
          }
          staged.set(val.key, {
            ...val,
            entity: previous.entity,
            order: previous.order,
          });
          continue;
        }
        if (tag === "remove") {
          if (!staged.has(val)) continue;
          const removed = new Set([val]);
          for (let changed = true; changed;) {
            changed = false;
            for (const [key, node] of staged) {
              if (node.parent && removed.has(node.parent) && !removed.has(key)) {
                removed.add(key);
                changed = true;
              }
            }
          }
          for (const key of removed) staged.delete(key);
          continue;
        }
        const node = staged.get(val.key);
        if (!node) throw new Error(`mutation target does not exist: ${val.key}`);
        if (tag === "set-text") node.text = val.value;
        else if (tag === "set-source") node.source = val.value;
        else if (tag === "set-background") node.style.background = val.value;
        else if (tag === "set-active") node.active = val.value;
        else if (tag === "set-enabled") node.enabled = val.value;
        else if (tag === "set-top") node.style.top = val.value;
        else if (tag === "move") {
          if (!staged.has(val.parent)) throw new Error(`move parent does not exist: ${val.parent}`);
          node.parent = val.parent;
          node.order = val.index;
        } else throw new Error(`unknown mutation: ${tag}`);
      }
      if (staged.size > configured.maxNodesPerInstance) throw new Error("node limit exceeded");
      views.set(entity, staged);
    },
    release(entity) {
      views.delete(entity);
    },
    snapshot(entity) {
      return [...(views.get(entity) ?? new Map()).values()]
        .sort((left, right) => left.key.localeCompare(right.key))
        .map(({ key, parent, kind, text, source, enabled, focusable, entity, order, style }) => ({
          key,
          parent: parent ?? null,
          kind,
          text,
          source,
          enabled,
          focusable,
          entity,
          order,
          top: style.top,
          background: style.background,
          bold: style.bold,
          wrap: style.wrap,
        }));
    },
    viewIds() {
      return [...views.keys()];
    },
    viewCount() {
      return views.size;
    },
  };
}
