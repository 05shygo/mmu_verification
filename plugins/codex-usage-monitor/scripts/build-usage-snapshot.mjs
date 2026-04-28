#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildSnapshot } from "../src/usage-core.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const pluginRoot = path.resolve(scriptDirectory, "..");
const outputPath = path.join(pluginRoot, "ui", "usage-snapshot.json");
const flags = new Set(process.argv.slice(2));

async function main() {
  const snapshot = await buildSnapshot();
  await fs.promises.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.promises.writeFile(outputPath, `${JSON.stringify(snapshot, null, 2)}\n`, "utf8");

  if (flags.has("--stdout")) {
    process.stdout.write(`${JSON.stringify(snapshot, null, 2)}\n`);
    return;
  }

  if (flags.has("--silent")) {
    return;
  }

  process.stdout.write(
    [
      `Updated ${outputPath}`,
      `Total: ${snapshot.totals.totalTokens.toLocaleString()} tokens / $${snapshot.totals.estimatedUsd.toFixed(4)}`,
      `Today: ${snapshot.today.totalTokens.toLocaleString()} tokens / $${snapshot.today.estimatedUsd.toFixed(4)}`,
      `API: ${snapshot.status.api.status} (${snapshot.status.api.activeRequests} active)`,
    ].join("\n") + "\n",
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack : String(error));
  process.exitCode = 1;
});
