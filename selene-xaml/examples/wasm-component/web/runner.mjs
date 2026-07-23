import { createSeleneTreeHost } from "../../../runtime/src/component_host/js/selene-tree-host.js";
import { UiComponentLoader } from "../../../runtime/src/component_host/js/ui-component-loader.js";

const manifestUrl = new URL("../component/component-manifest.json", import.meta.url);
const moduleUrl = new URL("../component/dist/jco/survivors-ui.js", import.meta.url);
const hostRuntimeUrl = new URL("../component/dist/jco/host-runtime.js", import.meta.url);
const state = {
  score: 18420,
  remainingSeconds: 73,
  wave: 6,
  level: 12,
  experience: 78,
  experienceGoal: 100,
  levelUpVisible: true,
  gameOverVisible: false,
  victory: false,
  selections: [
    { key: "attack", label: "Attack +20%", icon: "", background: "#9c3d54" },
    { key: "range", label: "Range +25%", icon: "", background: "#356d8d" },
    { key: "speed", label: "Speed +15%", icon: "", background: "#497a4a" },
  ],
};

globalThis.__seleneWasmExample = {
  ...(globalThis.__seleneWasmExample || {}),
  name: "survivors",
  ready: false,
};
while (!globalThis.__seleneUiComponentHost || globalThis.__seleneWasmExample.entity === undefined) {
  await new Promise((resolve) => requestAnimationFrame(resolve));
}
const { registerHost } = await import(hostRuntimeUrl.href);
const manifest = await fetch(manifestUrl).then((response) => response.json());
const treeHost = createSeleneTreeHost();
const unregisterHost = registerHost(treeHost);
const loader = new UiComponentLoader(manifest.hostCapabilities, treeHost);
const component = await loader.load({
  moduleUrl: moduleUrl.href,
  exportName: "survivorsUiApi",
  manifest,
});
const entity = globalThis.__seleneWasmExample.entity;
component.mount(entity, state);
const updateComponent = () => {
  component.update();
  requestAnimationFrame(updateComponent);
};
requestAnimationFrame(updateComponent);
while (!globalThis.__selene_webgpu_runtime?.ready) {
  await new Promise((resolve) => requestAnimationFrame(resolve));
}
await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
Object.assign(globalThis.__seleneWasmExample, {
  ready: true,
  component,
  entity,
  loader,
  unregisterHost,
});
