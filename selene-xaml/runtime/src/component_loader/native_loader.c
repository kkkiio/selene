#include "moonbit.h"
#include <stdint.h>
#include <string.h>

typedef int32_t (*selene_apply_callback_t)(uint32_t, moonbit_bytes_t);

static selene_apply_callback_t apply_callback = NULL;

extern uint64_t selene_wasmtime_load(int32_t kind, const uint8_t *path, size_t length);
extern int32_t selene_wasmtime_mount(uint64_t component, uint32_t entity, const uint8_t *json, size_t length);
extern int32_t selene_wasmtime_replace(uint64_t component, uint32_t entity, const uint8_t *json, size_t length);
extern int32_t selene_wasmtime_apply(uint64_t component, uint32_t entity, const uint8_t *json, size_t length);
extern int32_t selene_wasmtime_handle_event(uint64_t component, uint32_t entity, const uint8_t *json, size_t length);
extern int32_t selene_wasmtime_update(uint64_t component);
extern int32_t selene_wasmtime_unmount(uint64_t component, uint32_t entity);
extern int32_t selene_wasmtime_unload(uint64_t component);
extern size_t selene_wasmtime_last_error(uint8_t *output, size_t capacity);
extern size_t selene_wasmtime_last_result(uint8_t *output, size_t capacity);

void selene_component_loader_register_host(selene_apply_callback_t apply) {
  apply_callback = apply;
}

int32_t selene_loader_host_apply(uint32_t entity, const uint8_t *json, size_t length) {
  if (apply_callback == NULL) return 1;
  moonbit_bytes_t payload = moonbit_make_bytes_raw((int32_t)length);
  if (length != 0) memcpy(payload, json, length);
  return apply_callback(entity, payload);
}

uint64_t selene_component_loader_load(int32_t kind, moonbit_bytes_t path) {
  return selene_wasmtime_load(kind, path, (size_t)Moonbit_array_length(path));
}

int32_t selene_component_loader_mount(uint64_t component, uint32_t entity, moonbit_bytes_t json) {
  return selene_wasmtime_mount(component, entity, json, (size_t)Moonbit_array_length(json));
}

int32_t selene_component_loader_replace(uint64_t component, uint32_t entity, moonbit_bytes_t json) {
  return selene_wasmtime_replace(component, entity, json, (size_t)Moonbit_array_length(json));
}

int32_t selene_component_loader_apply(uint64_t component, uint32_t entity, moonbit_bytes_t json) {
  return selene_wasmtime_apply(component, entity, json, (size_t)Moonbit_array_length(json));
}

int32_t selene_component_loader_handle_event(uint64_t component, uint32_t entity, moonbit_bytes_t json) {
  return selene_wasmtime_handle_event(component, entity, json, (size_t)Moonbit_array_length(json));
}

int32_t selene_component_loader_update(uint64_t component) {
  return selene_wasmtime_update(component);
}

int32_t selene_component_loader_unmount(uint64_t component, uint32_t entity) {
  return selene_wasmtime_unmount(component, entity);
}

int32_t selene_component_loader_unload(uint64_t component) {
  return selene_wasmtime_unload(component);
}

moonbit_bytes_t selene_component_loader_last_error(void) {
  size_t length = selene_wasmtime_last_error(NULL, 0);
  moonbit_bytes_t result = moonbit_make_bytes_raw((int32_t)length);
  if (length != 0) selene_wasmtime_last_error(result, length);
  return result;
}

moonbit_bytes_t selene_component_loader_last_result(void) {
  size_t length = selene_wasmtime_last_result(NULL, 0);
  moonbit_bytes_t result = moonbit_make_bytes_raw((int32_t)length);
  if (length != 0) selene_wasmtime_last_result(result, length);
  return result;
}
