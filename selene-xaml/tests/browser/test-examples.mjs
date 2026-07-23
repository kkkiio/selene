import { chromium } from "playwright";
import { listening, origin, server } from "./serve.mjs";

await listening;
const browser = await chromium.launch({
  channel: "chrome",
  args: ["--enable-unsafe-webgpu", "--use-angle=metal"],
});
try {
  const cases = [
    {
      name: "inventory-wide",
      path: "/examples/inventory/web/?width=960",
      width: 960,
      height: 540,
      marker: "__seleneInventoryExample",
      state: "mounted",
    },
    {
      name: "inventory-narrow",
      path: "/examples/inventory/web/?width=720",
      width: 720,
      height: 540,
      marker: "__seleneInventoryExample",
      state: "mounted",
    },
    {
      name: "survivors",
      path: "/examples/survivors/web/",
      width: 960,
      height: 640,
      marker: "__seleneSurvivorsExample",
      state: "mounted",
    },
    {
      name: "wasm-component",
      path: "/examples/wasm-component/web/",
      width: 960,
      height: 540,
      marker: "__seleneWasmExample",
      state: "ready",
    },
  ];
  for (const testCase of cases) {
    const failures = [];
    const page = await browser.newPage();
    page.on("console", (message) => {
      if (message.type() === "error") failures.push(`console: ${message.text()}`);
    });
    page.on("pageerror", (error) => failures.push(`page: ${error.message}`));
    page.on("response", (response) => {
      if (response.status() >= 400) failures.push(`${response.status()}: ${response.url()}`);
    });
    await page.goto(`${origin}${testCase.path}`);
    await page.waitForFunction(
      ({ marker, state }) =>
        globalThis[marker]?.[state] === true &&
        globalThis.__selene_webgpu_runtime?.ready === true,
      { marker: testCase.marker, state: testCase.state },
    );
    await page.waitForLoadState("networkidle");
    const canvas = page.locator("canvas");
    if ((await canvas.getAttribute("width")) !== String(testCase.width)) {
      failures.push(`canvas width must be ${testCase.width}`);
    }
    if ((await canvas.getAttribute("height")) !== String(testCase.height)) {
      failures.push(`canvas height must be ${testCase.height}`);
    }
    if (failures.length !== 0) {
      throw new Error(`${testCase.name}\n${failures.join("\n")}`);
    }
    await page.close();
    console.log(`${testCase.name}: ready`);
  }
} finally {
  await browser.close();
  await new Promise((closed) => server.close(closed));
}
