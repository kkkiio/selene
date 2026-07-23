use anyhow::{Context, Result, anyhow, bail};
use serde::Serialize;
use serde_json::{Map, Value, json};
use std::collections::{HashMap, HashSet};
use std::slice;
use std::str;
use std::sync::{LazyLock, Mutex};
use wasmtime::component::{Component, HasSelf, Linker};
use wasmtime::{Config, Engine, Store};

mod survivors {
    wasmtime::component::bindgen!({
        world: "survivors-ui",
        path: "../../examples/wasm-component/component/wit",
        additional_derives: [serde::Deserialize, serde::Serialize],
    });
}

unsafe extern "C" {
    fn selene_loader_host_apply(entity: u32, json: *const u8, length: usize) -> i32;
}

struct HostState {
    entities: HashSet<u32>,
}

struct SurvivorsComponent {
    store: Store<HostState>,
    bindings: survivors::SurvivorsUi,
    entities: HashSet<u32>,
}

enum LoadedComponent {
    Survivors(SurvivorsComponent),
}

struct LoaderRegistry {
    components: HashMap<u64, LoadedComponent>,
    next_component: u64,
}

static REGISTRY: LazyLock<Mutex<LoaderRegistry>> = LazyLock::new(|| {
    Mutex::new(LoaderRegistry {
        components: HashMap::new(),
        next_component: 1,
    })
});
static LAST_ERROR: LazyLock<Mutex<String>> = LazyLock::new(|| Mutex::new(String::new()));
static LAST_RESULT: LazyLock<Mutex<Vec<u8>>> = LazyLock::new(|| Mutex::new(Vec::new()));

fn normalize_layout_value(style: &mut Map<String, Value>, field: &str) -> Result<()> {
    let value = style
        .remove(field)
        .with_context(|| format!("mount style is missing {field}"))?;
    let (kind, number) = match value {
        Value::String(tag) if tag == "Auto" => ("auto", 0.0),
        Value::Object(object) if object.len() == 1 => {
            let (tag, payload) = object.into_iter().next().unwrap();
            let number = payload
                .as_f64()
                .with_context(|| format!("mount style {field} payload must be numeric"))?;
            match tag.as_str() {
                "Px" => ("px", number),
                "Percent" => ("percent", number),
                other => bail!("unknown mount style {field} variant: {other}"),
            }
        }
        other => bail!("mount style {field} has invalid layout value: {other}"),
    };
    style.insert(format!("{field}_kind"), Value::String(kind.into()));
    style.insert(format!("{field}_value"), json!(number));
    Ok(())
}

fn normalized_visual_state_value(value: Value) -> Result<Value> {
    let mut output = Map::from_iter([
        ("tag".into(), Value::String(String::new())),
        ("string_value".into(), Value::String(String::new())),
        ("bool_value".into(), Value::Bool(false)),
        ("number_value".into(), json!(0.0)),
        ("layout_kind".into(), Value::String("auto".into())),
        ("layout_value".into(), json!(0.0)),
    ]);
    let object = value
        .as_object()
        .context("visual-state value must serialize as an object")?;
    let (tag, payload) = object
        .iter()
        .next()
        .context("visual-state value variant is empty")?;
    match tag.as_str() {
        "StringValue" => {
            output.insert("tag".into(), Value::String("string".into()));
            output.insert("string_value".into(), payload.clone());
        }
        "BoolValue" => {
            output.insert("tag".into(), Value::String("bool".into()));
            output.insert("bool_value".into(), payload.clone());
        }
        "DoubleValue" | "IntValue" => {
            output.insert(
                "tag".into(),
                Value::String(
                    if tag == "DoubleValue" {
                        "double"
                    } else {
                        "int"
                    }
                    .into(),
                ),
            );
            output.insert("number_value".into(), payload.clone());
        }
        "LayoutValueValue" => {
            output.insert("tag".into(), Value::String("layout".into()));
            match payload {
                Value::String(layout) if layout == "Auto" => {}
                Value::Object(layout) if layout.len() == 1 => {
                    let (kind, number) = layout.iter().next().unwrap();
                    output.insert("layout_kind".into(), Value::String(kind.to_lowercase()));
                    output.insert("layout_value".into(), number.clone());
                }
                _ => bail!("invalid visual-state layout value"),
            }
        }
        other => bail!("unknown visual-state value variant: {other}"),
    }
    Ok(Value::Object(output))
}

fn normalize_visual_state_groups(spec: &mut Map<String, Value>) -> Result<()> {
    let groups = spec
        .get_mut("visual_state_groups")
        .and_then(Value::as_array_mut)
        .context("node spec is missing visual_state_groups")?;
    for group in groups {
        let group = group
            .as_object_mut()
            .context("visual-state group must be an object")?;
        let states = group
            .get_mut("states")
            .and_then(Value::as_array_mut)
            .context("visual-state group is missing states")?;
        for state in states {
            let setters = state
                .as_object_mut()
                .and_then(|state| state.get_mut("setters"))
                .and_then(Value::as_array_mut)
                .context("visual state is missing setters")?;
            for setter in setters {
                let setter = setter
                    .as_object_mut()
                    .context("visual-state setter must be an object")?;
                let value = setter
                    .remove("value")
                    .context("visual-state setter is missing value")?;
                setter.insert("value".into(), normalized_visual_state_value(value)?);
            }
        }
        let transitions = group
            .get_mut("transitions")
            .and_then(Value::as_array_mut)
            .context("visual-state group is missing transitions")?;
        for transition in transitions {
            let transition = transition
                .as_object_mut()
                .context("visual transition must be an object")?;
            for endpoint in ["from", "to"] {
                if transition.get(endpoint).is_some_and(Value::is_null) {
                    transition.insert(endpoint.into(), Value::String(String::new()));
                }
            }
        }
    }
    Ok(())
}

fn normalized_tree_mutations<T: Serialize>(mutations: &[T]) -> Result<Vec<u8>> {
    let mut normalized = Vec::with_capacity(mutations.len());
    for mutation in mutations {
        let serialized = serde_json::to_value(mutation)?;
        let object = serialized
            .as_object()
            .ok_or_else(|| anyhow!("tree mutation did not serialize as an object"))?;
        let (variant, payload) = object
            .iter()
            .next()
            .ok_or_else(|| anyhow!("tree mutation variant is empty"))?;
        let tag = match variant.as_str() {
            "Mount" => "mount",
            "Update" => "update",
            "SetText" => "set-text",
            "SetSource" => "set-source",
            "SetBackground" => "set-background",
            "SetActive" => "set-active",
            "SetEnabled" => "set-enabled",
            "SetTop" => "set-top",
            "Move" => "move",
            "Remove" => "remove",
            other => bail!("unknown tree mutation variant: {other}"),
        };
        let mut output = Map::from_iter([
            ("tag".into(), Value::String(tag.into())),
            ("key".into(), Value::String(String::new())),
            ("text_value".into(), Value::String(String::new())),
            ("bool_value".into(), Value::Bool(false)),
            ("number_value".into(), json!(0.0)),
            ("parent".into(), Value::String(String::new())),
            ("index".into(), json!(0)),
            ("spec".into(), Value::Null),
        ]);
        match tag {
            "mount" | "update" => {
                let mut spec = payload
                    .as_object()
                    .context("node spec payload must be an object")?
                    .clone();
                let parent = spec.remove("parent").unwrap_or(Value::Null);
                spec.insert(
                    "parent".into(),
                    if parent.is_null() {
                        Value::String(String::new())
                    } else {
                        parent
                    },
                );
                if let Some(Value::String(kind)) = spec.get_mut("kind") {
                    *kind = kind
                        .chars()
                        .enumerate()
                        .flat_map(|(index, ch)| {
                            if ch.is_ascii_uppercase() && index > 0 {
                                vec!['-', ch.to_ascii_lowercase()]
                            } else {
                                vec![ch.to_ascii_lowercase()]
                            }
                        })
                        .collect();
                }
                let style = spec
                    .get_mut("style")
                    .and_then(Value::as_object_mut)
                    .context("mount style must be an object")?;
                for field in ["align", "fit", "direction"] {
                    if let Some(Value::String(value)) = style.get_mut(field) {
                        *value = value
                            .chars()
                            .enumerate()
                            .flat_map(|(index, ch)| {
                                if ch.is_ascii_uppercase() && index > 0 {
                                    vec!['-', ch.to_ascii_lowercase()]
                                } else {
                                    vec![ch.to_ascii_lowercase()]
                                }
                            })
                            .collect();
                    }
                }
                for field in ["width", "height", "flex_basis"] {
                    normalize_layout_value(style, field)?;
                }
                normalize_visual_state_groups(&mut spec)?;
                output.insert("spec".into(), Value::Object(spec));
            }
            "remove" => {
                output.insert("key".into(), payload.clone());
            }
            "move" => {
                let value = payload
                    .as_object()
                    .context("move payload must be an object")?;
                for field in ["key", "parent", "index"] {
                    output.insert(
                        field.into(),
                        value.get(field).cloned().context("move field is missing")?,
                    );
                }
            }
            "set-text" | "set-source" | "set-background" => {
                let value = payload
                    .as_object()
                    .context("text mutation payload must be an object")?;
                output.insert("key".into(), value["key"].clone());
                output.insert("text_value".into(), value["value"].clone());
            }
            "set-active" | "set-enabled" => {
                let value = payload
                    .as_object()
                    .context("bool mutation payload must be an object")?;
                output.insert("key".into(), value["key"].clone());
                output.insert("bool_value".into(), value["value"].clone());
            }
            "set-top" => {
                let value = payload
                    .as_object()
                    .context("number mutation payload must be an object")?;
                output.insert("key".into(), value["key"].clone());
                output.insert("number_value".into(), value["value"].clone());
            }
            _ => unreachable!(),
        }
        normalized.push(Value::Object(output));
    }
    Ok(serde_json::to_vec(&normalized)?)
}

macro_rules! implement_tree_host {
    ($module:ident) => {
        impl $module::selene::ui_host::tree::Host for HostState {
            fn apply(
                &mut self,
                entity: u32,
                mutations: Vec<$module::selene::ui_host::tree::TreeMutation>,
            ) -> Result<(), $module::selene::ui_host::tree::HostError> {
                if !self.entities.contains(&entity) {
                    return Err($module::selene::ui_host::tree::HostError {
                        code: "SH4004".into(),
                        message: "Component instance does not own the Selene Entity".into(),
                    });
                }
                let json = normalized_tree_mutations(&mutations).map_err(|error| {
                    $module::selene::ui_host::tree::HostError {
                        code: "SH4002".into(),
                        message: error.to_string(),
                    }
                })?;
                let status = unsafe { selene_loader_host_apply(entity, json.as_ptr(), json.len()) };
                if status == 0 {
                    Ok(())
                } else {
                    Err($module::selene::ui_host::tree::HostError {
                        code: "SH4003".into(),
                        message: format!(
                            "Selene Host rejected mutation batch with status {status}"
                        ),
                    })
                }
            }
        }
    };
}

implement_tree_host!(survivors);

fn input_bytes<'a>(pointer: *const u8, length: usize) -> Result<&'a [u8]> {
    if pointer.is_null() && length != 0 {
        bail!("native loader received a null input pointer");
    }
    Ok(unsafe { slice::from_raw_parts(pointer, length) })
}

fn load_component(kind: i32, path: &str) -> Result<u64> {
    let mut config = Config::new();
    config.wasm_component_model(true).consume_fuel(true);
    let engine = Engine::new(&config)?;
    let component = Component::from_file(&engine, path)
        .map_err(|error| anyhow!("failed to compile WebAssembly Component {path}: {error:?}"))?;
    let state = HostState {
        entities: HashSet::new(),
    };
    let loaded = match kind {
        1 => {
            let mut linker = Linker::new(&engine);
            survivors::SurvivorsUi::add_to_linker::<_, HasSelf<HostState>>(&mut linker, |state| {
                state
            })?;
            let mut store = Store::new(&engine, state);
            store.set_fuel(10_000_000)?;
            let bindings = survivors::SurvivorsUi::instantiate(&mut store, &component, &linker)?;
            LoadedComponent::Survivors(SurvivorsComponent {
                store,
                bindings,
                entities: HashSet::new(),
            })
        }
        _ => bail!("unknown native UI component kind {kind}"),
    };
    let mut registry = REGISTRY.lock().unwrap();
    let handle = registry.next_component;
    registry.next_component += 1;
    registry.components.insert(handle, loaded);
    Ok(handle)
}

fn mount_view(component: u64, entity: u32, json: &[u8]) -> Result<()> {
    let mut registry = REGISTRY.lock().unwrap();
    match registry
        .components
        .get_mut(&component)
        .context("native UI component is not loaded")?
    {
        LoadedComponent::Survivors(loaded) => {
            if loaded.entities.contains(&entity) {
                bail!("native Survivors Entity is already mounted");
            }
            let state = serde_json::from_slice(json)?;
            loaded.store.data_mut().entities.insert(entity);
            let mounted = loaded
                .bindings
                .selene_survivors_ui_survivors_ui_api()
                .call_mount(&mut loaded.store, entity, &state);
            if mounted.is_err() {
                loaded.store.data_mut().entities.remove(&entity);
            }
            mounted?;
            loaded.entities.insert(entity);
        }
    }
    Ok(())
}

fn replace_view(component: u64, entity: u32, json: &[u8]) -> Result<()> {
    let mut registry = REGISTRY.lock().unwrap();
    match registry
        .components
        .get_mut(&component)
        .context("native UI component is not loaded")?
    {
        LoadedComponent::Survivors(loaded) => {
            let state = serde_json::from_slice(json)?;
            if !loaded.entities.contains(&entity) {
                bail!("native Survivors Entity is not mounted");
            }
            loaded
                .bindings
                .selene_survivors_ui_survivors_ui_api()
                .call_replace(&mut loaded.store, entity, &state)?;
        }
    }
    Ok(())
}

fn apply_patches(component: u64, entity: u32, json: &[u8]) -> Result<()> {
    let mut registry = REGISTRY.lock().unwrap();
    match registry
        .components
        .get_mut(&component)
        .context("native UI component is not loaded")?
    {
        LoadedComponent::Survivors(loaded) => {
            let patches = serde_json::from_slice::<
                Vec<survivors::exports::selene::survivors_ui::survivors_ui_api::SurvivorsUiPatch>,
            >(json)?;
            if !loaded.entities.contains(&entity) {
                bail!("native Survivors Entity is not mounted");
            }
            loaded
                .bindings
                .selene_survivors_ui_survivors_ui_api()
                .call_apply(&mut loaded.store, entity, &patches)?;
        }
    }
    Ok(())
}

fn handle_event(component: u64, entity: u32, json: &[u8]) -> Result<()> {
    let mut registry = REGISTRY.lock().unwrap();
    let result = match registry
        .components
        .get_mut(&component)
        .context("native UI component is not loaded")?
    {
        LoadedComponent::Survivors(loaded) => {
            let event = serde_json::from_slice(json)?;
            if !loaded.entities.contains(&entity) {
                bail!("native Survivors Entity is not mounted");
            }
            let action = loaded
                .bindings
                .selene_survivors_ui_survivors_ui_api()
                .call_handle_event(&mut loaded.store, entity, &event)?;
            serde_json::to_vec(&action)?
        }
    };
    *LAST_RESULT.lock().unwrap() = result;
    Ok(())
}

fn unmount_view(component: u64, entity: u32) -> Result<()> {
    let mut registry = REGISTRY.lock().unwrap();
    match registry
        .components
        .get_mut(&component)
        .context("native UI component is not loaded")?
    {
        LoadedComponent::Survivors(loaded) => {
            if !loaded.entities.contains(&entity) {
                bail!("native Survivors Entity is not mounted");
            }
            loaded
                .bindings
                .selene_survivors_ui_survivors_ui_api()
                .call_unmount(&mut loaded.store, entity)?;
            loaded.entities.remove(&entity);
            loaded.store.data_mut().entities.remove(&entity);
        }
    }
    Ok(())
}

fn update_component(component: u64) -> Result<()> {
    let mut registry = REGISTRY.lock().unwrap();
    match registry
        .components
        .get_mut(&component)
        .context("native UI component is not loaded")?
    {
        LoadedComponent::Survivors(loaded) => loaded
            .bindings
            .selene_survivors_ui_survivors_ui_api()
            .call_update(&mut loaded.store)?,
    }
    Ok(())
}

fn unload_component(component: u64) -> Result<()> {
    let mut registry = REGISTRY.lock().unwrap();
    let loaded = registry
        .components
        .get(&component)
        .context("native UI component is not loaded")?;
    let live_views = match loaded {
        LoadedComponent::Survivors(value) => value.entities.len(),
    };
    if live_views != 0 {
        bail!("unmount all UI views before unloading their component module");
    }
    registry.components.remove(&component);
    Ok(())
}

fn finish<T>(operation: Result<T>, success: impl FnOnce(T) -> u64) -> u64 {
    match operation {
        Ok(value) => {
            LAST_ERROR.lock().unwrap().clear();
            success(value)
        }
        Err(error) => {
            *LAST_ERROR.lock().unwrap() = format!("{error:#}");
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn selene_wasmtime_load(kind: i32, path: *const u8, length: usize) -> u64 {
    finish(
        input_bytes(path, length)
            .and_then(|bytes| str::from_utf8(bytes).map_err(Into::into))
            .and_then(|path| load_component(kind, path)),
        |handle| handle,
    )
}

#[unsafe(no_mangle)]
pub extern "C" fn selene_wasmtime_mount(
    component: u64,
    entity: u32,
    json: *const u8,
    length: usize,
) -> i32 {
    finish(
        input_bytes(json, length).and_then(|bytes| mount_view(component, entity, bytes)),
        |_| 1,
    ) as i32
}

macro_rules! export_json_operation {
    ($name:ident, $operation:ident) => {
        #[unsafe(no_mangle)]
        pub extern "C" fn $name(
            component: u64,
            entity: u32,
            json: *const u8,
            length: usize,
        ) -> i32 {
            finish(
                input_bytes(json, length).and_then(|bytes| $operation(component, entity, bytes)),
                |_| 1,
            ) as i32
        }
    };
}

export_json_operation!(selene_wasmtime_replace, replace_view);
export_json_operation!(selene_wasmtime_apply, apply_patches);
export_json_operation!(selene_wasmtime_handle_event, handle_event);

#[unsafe(no_mangle)]
pub extern "C" fn selene_wasmtime_update(component: u64) -> i32 {
    finish(update_component(component), |_| 1) as i32
}

#[unsafe(no_mangle)]
pub extern "C" fn selene_wasmtime_unmount(component: u64, entity: u32) -> i32 {
    finish(unmount_view(component, entity), |_| 1) as i32
}

#[unsafe(no_mangle)]
pub extern "C" fn selene_wasmtime_unload(component: u64) -> i32 {
    finish(unload_component(component), |_| 1) as i32
}

fn copy_output(value: &Mutex<Vec<u8>>, output: *mut u8, capacity: usize) -> usize {
    let bytes = value.lock().unwrap();
    if !output.is_null() && capacity >= bytes.len() {
        unsafe { std::ptr::copy_nonoverlapping(bytes.as_ptr(), output, bytes.len()) };
    }
    bytes.len()
}

#[unsafe(no_mangle)]
pub extern "C" fn selene_wasmtime_last_error(output: *mut u8, capacity: usize) -> usize {
    let text = LAST_ERROR.lock().unwrap().as_bytes().to_vec();
    copy_output(&Mutex::new(text), output, capacity)
}

#[unsafe(no_mangle)]
pub extern "C" fn selene_wasmtime_last_result(output: *mut u8, capacity: usize) -> usize {
    copy_output(&LAST_RESULT, output, capacity)
}
