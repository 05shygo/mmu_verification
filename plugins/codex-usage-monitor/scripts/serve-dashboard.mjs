#!/usr/bin/env node

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { DEFAULT_DASHBOARD_PORT, buildSnapshot } from "../src/usage-core.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(scriptDirectory, "..");
const uiRoot = path.join(pluginRoot, "ui");
const assetsRoot = path.join(pluginRoot, "assets");
const defaultHost = "127.0.0.1";

const args = process.argv.slice(2);
const portFlagIndex = args.indexOf("--port");
const hostFlagIndex = args.indexOf("--host");
const port = portFlagIndex >= 0 ? Number(args[portFlagIndex + 1]) : DEFAULT_DASHBOARD_PORT;
const host = hostFlagIndex >= 0 ? args[hostFlagIndex + 1] : defaultHost;

const mimeTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "application/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".svg", "image/svg+xml"],
]);

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  response.end(`${JSON.stringify(payload, null, 2)}\n`);
}

async function serveStaticFile(response, filePath) {
  const extension = path.extname(filePath);
  const contentType = mimeTypes.get(extension) ?? "application/octet-stream";
  const fileContents = await fs.promises.readFile(filePath);
  response.writeHead(200, {
    "Content-Type": contentType,
    "Cache-Control": extension === ".json" ? "no-store" : "public, max-age=60",
  });
  response.end(fileContents);
}

function resolveUiPath(requestPath) {
  if (requestPath === "/" || requestPath === "/index.html") {
    return path.join(uiRoot, "index.html");
  }

  if (requestPath.startsWith("/assets/")) {
    return path.join(assetsRoot, requestPath.replace("/assets/", ""));
  }

  return path.join(uiRoot, requestPath.slice(1));
}

const server = http.createServer(async (request, response) => {
  const requestPath = request.url?.split("?")[0] ?? "/";

  if (requestPath === "/usage-snapshot.json") {
    try {
      const snapshot = await buildSnapshot();
      sendJson(response, 200, snapshot);
    } catch (error) {
      sendJson(response, 500, {
        error: "snapshot_generation_failed",
        message: error instanceof Error ? error.message : String(error),
      });
    }
    return;
  }

  if (requestPath === "/health") {
    sendJson(response, 200, { ok: true });
    return;
  }

  const filePath = resolveUiPath(requestPath);
  try {
    await serveStaticFile(response, filePath);
  } catch {
    sendJson(response, 404, {
      error: "not_found",
      message: `No resource mapped for ${requestPath}`,
    });
  }
});

server.listen(port, host, () => {
  process.stdout.write(
    [
      "Codex Usage Monitor dashboard is running.",
      `URL: http://${host}:${port}/`,
      "Press Ctrl+C to stop the server.",
    ].join("\n") + "\n",
  );
});
