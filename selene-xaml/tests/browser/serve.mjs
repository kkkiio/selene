import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const port = Number(process.env.SELENE_EXAMPLE_PORT ?? "4174");
const root = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const mimeTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".wasm", "application/wasm"],
  [".png", "image/png"],
]);

export const origin = `http://127.0.0.1:${port}`;
export const server = createServer((request, response) => {
  const requestUrl = new URL(request.url ?? "/", origin);
  const decodedPath = decodeURIComponent(requestUrl.pathname);
  const candidate = resolve(root, `.${decodedPath}`);
  if (candidate !== root && !candidate.startsWith(root + sep)) {
    response.writeHead(403).end("forbidden");
    return;
  }
  let file = candidate;
  try {
    if (statSync(file).isDirectory()) file = resolve(file, "index.html");
    const size = statSync(file).size;
    response.writeHead(200, {
      "content-type": mimeTypes.get(extname(file)) ?? "application/octet-stream",
      "content-length": size,
      "cache-control": "no-store",
    });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404).end("not found");
  }
});

export const listening = new Promise((ready, reject) => {
  server.once("error", reject);
  server.listen(port, "127.0.0.1", () => {
    console.log(`Selene XAML examples available at ${origin}/examples/`);
    ready();
  });
});
