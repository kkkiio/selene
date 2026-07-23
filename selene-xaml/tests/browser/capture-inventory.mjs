import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { listening, origin, server } from "./serve.mjs";

await listening;
const outputDirectory = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../examples/inventory/screenshots",
);
await mkdir(outputDirectory, { recursive: true });
const browser = await chromium.launch({
  channel: "chrome",
  args: ["--enable-unsafe-webgpu", "--use-angle=metal"],
});
try {
  for (const capture of [
    { name: "web.png", width: 960 },
    { name: "web-narrow.png", width: 720 },
  ]) {
    const failures = [];
    const page = await browser.newPage();
    page.on("console", (message) => {
      if (message.type() === "error") failures.push(`console: ${message.text()}`);
    });
    page.on("pageerror", (error) => failures.push(`page: ${error.message}`));
    page.on("response", (response) => {
      if (response.status() >= 400) failures.push(`${response.status()}: ${response.url()}`);
    });
    await page.goto(`${origin}/examples/inventory/web/?width=${capture.width}`);
    await page.waitForFunction(
      () =>
        globalThis.__seleneInventoryExample?.mounted === true &&
        globalThis.__selene_webgpu_runtime?.ready === true,
    );
    await page.waitForLoadState("networkidle");
    await page.evaluate(
      () => new Promise((ready) => requestAnimationFrame(() => requestAnimationFrame(ready))),
    );
    const canvas = page.locator("canvas");
    if ((await canvas.getAttribute("width")) !== String(capture.width)) {
      throw new Error(`canvas width must be ${capture.width}`);
    }
    const png = await canvas.screenshot({
      path: resolve(outputDirectory, capture.name),
      animations: "disabled",
      scale: "css",
    });
    if (png.byteLength <= 10_000) throw new Error("rendered screenshot is unexpectedly small");
    if (failures.length !== 0) throw new Error(failures.join("\n"));
    await page.close();
    console.log(`Inventory screenshot written to ${resolve(outputDirectory, capture.name)}`);
  }
} finally {
  await browser.close();
  await new Promise((closed) => server.close(closed));
}
