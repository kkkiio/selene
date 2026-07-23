import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { listening, origin, server } from "./serve.mjs";

await listening;
const failures = [];
const screenshot = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../examples/wasm-component/screenshots/web.png",
);
await mkdir(dirname(screenshot), { recursive: true });
const browser = await chromium.launch({
  channel: "chrome",
  args: ["--enable-unsafe-webgpu", "--use-angle=metal"],
});
try {
  const page = await browser.newPage();
  page.on("console", (message) => {
    if (message.type() === "error") failures.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => failures.push(`page: ${error.message}`));
  await page.goto(`${origin}/examples/wasm-component/web/`);
  await page.waitForFunction(() => globalThis.__seleneWasmExample?.ready === true);
  const canvas = page.locator("canvas");
  if (await canvas.getAttribute("width") !== "960") throw new Error("canvas width must be 960");
  if (await canvas.getAttribute("height") !== "540") throw new Error("canvas height must be 540");
  const png = await canvas.screenshot({
    path: screenshot,
    animations: "disabled",
    scale: "css",
  });
  if (png.byteLength <= 10_000) throw new Error("rendered screenshot is unexpectedly small");
  if (failures.length !== 0) throw new Error(failures.join("\n"));
  console.log(`Survivors screenshot written to ${screenshot}`);
} finally {
  await browser.close();
  await new Promise((closed) => server.close(closed));
}
