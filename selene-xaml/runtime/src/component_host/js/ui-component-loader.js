export class UiComponentLoader {
  #capabilities;
  #host;
  #modules = new Set();

  constructor(capabilities, host) {
    this.#capabilities = new Set(capabilities);
    this.#host = host;
  }

  async load({ moduleUrl, exportName, manifest }) {
    if (manifest.formatVersion !== 1) {
      throw new Error(`unsupported component manifest ${manifest.formatVersion}`);
    }
    for (const capability of manifest.hostCapabilities) {
      if (!this.#capabilities.has(capability)) {
        throw new Error(`host capability is unavailable: ${capability}`);
      }
    }
    const namespace = await import(moduleUrl);
    const api = namespace[exportName];
    if (!api) throw new Error(`component export is unavailable: ${exportName}`);
    const loaded = new LoadedUiComponent(this, api, manifest, this.#host);
    this.#modules.add(loaded);
    return loaded;
  }

  retire(component) {
    this.#modules.delete(component);
  }

  get loadedModuleCount() {
    return this.#modules.size;
  }
}

export class LoadedUiComponent {
  #loader;
  #api;
  #manifest;
  #host;
  #entities = new Set();
  #unloaded = false;

  constructor(loader, api, manifest, host) {
    this.#loader = loader;
    this.#api = api;
    this.#manifest = manifest;
    this.#host = host;
  }

  mount(entity, state) {
    if (this.#unloaded) throw new Error("UI component module is unloaded");
    if (this.#entities.has(entity)) throw new Error("Selene Entity is already mounted");
    try {
      this.#host.invoke([...this.#entities, entity], () => this.#api.mount(entity, state));
    } catch (error) {
      this.#host.release(entity);
      throw error;
    }
    this.#entities.add(entity);
  }

  replace(entity, state) {
    this.#requireEntity(entity);
    this.#host.invoke(this.#entities, () => this.#api.replace(entity, state));
  }

  apply(entity, patches) {
    this.#requireEntity(entity);
    this.#host.invoke(this.#entities, () => this.#api.apply(entity, patches));
  }

  handleEvent(entity, event) {
    this.#requireEntity(entity);
    return this.#host.invoke(
      this.#entities,
      () => this.#api.handleEvent(entity, event),
    );
  }

  update() {
    for (const entity of this.#entities) {
      if (!this.#host.isAlive(entity)) this.unmount(entity);
    }
    this.#host.invoke(this.#entities, () => this.#api.update());
  }

  unmount(entity) {
    this.#requireEntity(entity);
    this.#host.invoke(this.#entities, () => this.#api.unmount(entity));
    this.#host.release(entity);
    this.#entities.delete(entity);
  }

  unload() {
    if (this.#entities.size !== 0) {
      throw new Error("unmount all UI views before unloading their component module");
    }
    if (!this.#unloaded) {
      this.#unloaded = true;
      this.#loader.retire(this);
    }
  }

  #requireEntity(entity) {
    if (this.#unloaded || !this.#entities.has(entity)) {
      throw new Error("UI view does not belong to this loaded component module");
    }
  }

  get manifest() {
    return this.#manifest;
  }
}
