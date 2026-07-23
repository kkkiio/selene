import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { registerHost } from "../dist/jco/host-runtime.js";
import { createMockTreeHost } from "../../../../runtime/src/component_host/js/testing/mock-tree-host.js";
import { UiComponentLoader } from "../../../../runtime/src/component_host/js/ui-component-loader.js";

const manifest = JSON.parse(await readFile(
  new URL("../component-manifest.json", import.meta.url),
  "utf8",
));
const host = createMockTreeHost(manifest.limits);
const unregisterHost = registerHost(host);
const loader = new UiComponentLoader(manifest.hostCapabilities, host);
const moduleUrl = new URL("../dist/jco/survivors-ui.js", import.meta.url).href;
const component = await loader.load({ moduleUrl, exportName: "survivorsUiApi", manifest });
const directApi = (await import(moduleUrl)).survivorsUiApi;

const selection = (key, label, icon, background = "rgba(13, 167, 170, 1)") => ({
  key,
  label,
  icon,
  background,
});
const initial = {
  score: 0,
  remainingSeconds: 600,
  wave: 1,
  level: 1,
  experience: 0,
  experienceGoal: 16,
  levelUpVisible: false,
  gameOverVisible: false,
  victory: false,
  selections: [],
};

const entity = 41;
host.register(entity);
host.register(40);
assert.throws(
  () => directApi.mount(40, initial),
  /Component instance does not own the Selene Entity/,
);
component.mount(entity, initial);
assert.equal(loader.loadedModuleCount, 1);
assert.equal(host.viewCount(), 1);
let tree = host.snapshot(entity);
assert.equal(tree.length, 6);
assert.equal(tree.find((node) => node.key === "timer").text, "Time: 10:00");

const levelUpState = {
  ...initial,
  score: 250,
  remainingSeconds: 65,
  level: 2,
  experience: 4,
  levelUpVisible: true,
  selections: [
    selection("attack", "Attack +10%", "assets/survivors/icon/powerup_attack.png"),
    selection("range", "Range +15%", "assets/survivors/icon/powerup_range.png"),
    selection("minigun", "Minigun", "assets/survivors/icon/weapon_minigun.png", "orange"),
  ],
};
component.replace(entity, levelUpState);
tree = host.snapshot(entity);
assert.equal(tree.length, 18);
assert.equal(tree.find((node) => node.key === "score").text, "Score: 250");
assert.equal(tree.find((node) => node.key === "timer").text, "Time: 1:05");
assert.equal(tree.find((node) => node.key === "selection:range").focusable, true);
assert.equal(tree.find((node) => node.key === "selection:range:label").bold, false);
assert.equal(tree.find((node) => node.key === "selection:range:label").wrap, false);
assert.deepEqual(component.handleEvent(entity, { tag: "click", val: "selection:range" }), {
  tag: "select-powerup",
  val: "range",
});
const rangeEntity = tree.find((node) => node.key === "selection:range").entity;
component.replace(entity, levelUpState);
assert.equal(host.snapshot(entity).find((node) => node.key === "selection:range").entity, rangeEntity);

const beforeInvalidPatch = host.snapshot(entity);
assert.throws(() => component.apply(entity, [{
  tag: "selections-replace",
  val: [selection("duplicate", "One", "one.png"), selection("duplicate", "Two", "two.png")],
}]));
assert.deepEqual(host.snapshot(entity), beforeInvalidPatch);

component.apply(entity, [
  {
    tag: "selection-upsert",
    val: selection("range", "Range +25%", "assets/survivors/icon/powerup_bandana.png"),
  },
  { tag: "selection-remove", val: "attack" },
  { tag: "selection-move", val: ["minigun", 0] },
]);
tree = host.snapshot(entity);
assert.equal(tree.length, 15);
assert.equal(tree.find((node) => node.key === "selection:range").entity, rangeEntity);
assert.equal(tree.find((node) => node.key === "selection:range:label").text, "Range +25%");
assert.equal(tree.find((node) => node.key === "selection:minigun").order, 0);

const gameOverState = { ...initial, score: 9001, gameOverVisible: true, victory: true };
component.replace(entity, gameOverState);
tree = host.snapshot(entity);
assert.equal(tree.find((node) => node.key === "game-over-title").text, "VICTORY!");
assert.deepEqual(component.handleEvent(entity, { tag: "click", val: "restart" }), { tag: "restart" });

const failedStage = await loader.load({
  moduleUrl: `${moduleUrl}?failed-stage`,
  exportName: "survivorsUiApi",
  manifest,
});
host.register(42);
assert.throws(() => failedStage.mount(42, {
  ...initial,
  selections: [selection("duplicate", "One", "one.png"), selection("duplicate", "Two", "two.png")],
}));
failedStage.unload();
assert.equal(host.viewCount(), 1);

const staged = await loader.load({
  moduleUrl: `${moduleUrl}?valid-stage`,
  exportName: "survivorsUiApi",
  manifest,
});
const stagedEntity = 43;
host.register(stagedEntity);
staged.mount(stagedEntity, gameOverState);
assert.equal(host.viewCount(), 2);
assert.throws(() => staged.unload(), /unmount all UI views/);
host.destroy(entity);
component.update();
component.unload();
assert.deepEqual(staged.handleEvent(stagedEntity, { tag: "click", val: "restart" }), { tag: "restart" });

console.log(JSON.stringify({
  artifact: "survivors-ui.component.wasm",
  hostRegisteredExplicitly: true,
  loaderModulesAfterSwap: loader.loadedModuleCount,
  actions: ["select-powerup(range)", "restart"],
  retainedSelectionEntity: rangeEntity,
  invalidPatchWasAtomic: true,
  failedStageKeptLiveTree: true,
}, null, 2));

staged.unmount(stagedEntity);
staged.unload();
assert.equal(loader.loadedModuleCount, 0);
assert.equal(host.viewCount(), 0);
unregisterHost();
