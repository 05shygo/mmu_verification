#!/usr/bin/env node
// Unified entry point for the Codex CLI.

import { spawn } from "node:child_process";
import { existsSync } from "fs";
import { createRequire } from "node:module";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

// __dirname equivalent in ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const require = createRequire(import.meta.url);

const PLATFORM_PACKAGE_BY_TARGET = {
  "x86_64-unknown-linux-musl": "@openai/codex-linux-x64",
  "aarch64-unknown-linux-musl": "@openai/codex-linux-arm64",
  "x86_64-apple-darwin": "@openai/codex-darwin-x64",
  "aarch64-apple-darwin": "@openai/codex-darwin-arm64",
  "x86_64-pc-windows-msvc": "@openai/codex-win32-x64",
  "aarch64-pc-windows-msvc": "@openai/codex-win32-arm64",
};

const { platform, arch } = process;

let targetTriple = null;
switch (platform) {
  case "linux":
  case "android":
    switch (arch) {
      case "x64":
        targetTriple = "x86_64-unknown-linux-musl";
        break;
      case "arm64":
        targetTriple = "aarch64-unknown-linux-musl";
        break;
      default:
        break;
    }
    break;
  case "darwin":
    switch (arch) {
      case "x64":
        targetTriple = "x86_64-apple-darwin";
        break;
      case "arm64":
        targetTriple = "aarch64-apple-darwin";
        break;
      default:
        break;
    }
    break;
  case "win32":
    switch (arch) {
      case "x64":
        targetTriple = "x86_64-pc-windows-msvc";
        break;
      case "arm64":
        targetTriple = "aarch64-pc-windows-msvc";
        break;
      default:
        break;
    }
    break;
  default:
    break;
}

if (!targetTriple) {
  throw new Error(`Unsupported platform: ${platform} (${arch})`);
}

const platformPackage = PLATFORM_PACKAGE_BY_TARGET[targetTriple];
if (!platformPackage) {
  throw new Error(`Unsupported target triple: ${targetTriple}`);
}

const codexBinaryName = process.platform === "win32" ? "codex.exe" : "codex";
const localVendorRoot = path.join(__dirname, "..", "vendor");
const localBinaryPath = path.join(
  localVendorRoot,
  targetTriple,
  "codex",
  codexBinaryName,
);

let vendorRoot;
try {
  const packageJsonPath = require.resolve(`${platformPackage}/package.json`);
  vendorRoot = path.join(path.dirname(packageJsonPath), "vendor");
} catch {
  if (existsSync(localBinaryPath)) {
    vendorRoot = localVendorRoot;
  } else {
    const packageManager = detectPackageManager();
    const updateCommand =
      packageManager === "bun"
        ? "bun install -g @openai/codex@latest"
        : "npm install -g @openai/codex@latest";
    throw new Error(
      `Missing optional dependency ${platformPackage}. Reinstall Codex: ${updateCommand}`,
    );
  }
}

if (!vendorRoot) {
  const packageManager = detectPackageManager();
  const updateCommand =
    packageManager === "bun"
      ? "bun install -g @openai/codex@latest"
      : "npm install -g @openai/codex@latest";
  throw new Error(
    `Missing optional dependency ${platformPackage}. Reinstall Codex: ${updateCommand}`,
  );
}

const archRoot = path.join(vendorRoot, targetTriple);
const binaryPath = path.join(archRoot, "codex", codexBinaryName);

// Use an asynchronous spawn instead of spawnSync so that Node is able to
// respond to signals (e.g. Ctrl-C / SIGINT) while the native binary is
// executing. This allows us to forward those signals to the child process
// and guarantees that when either the child terminates or the parent
// receives a fatal signal, both processes exit in a predictable manner.

function getUpdatedPath(newDirs) {
  const pathSep = process.platform === "win32" ? ";" : ":";
  const existingPath = process.env.PATH || "";
  const updatedPath = [
    ...newDirs,
    ...existingPath.split(pathSep).filter(Boolean),
  ].join(pathSep);
  return updatedPath;
}

/**
 * Use heuristics to detect the package manager that was used to install Codex
 * in order to give the user a hint about how to update it.
 */
function detectPackageManager() {
  const userAgent = process.env.npm_config_user_agent || "";
  if (/\bbun\//.test(userAgent)) {
    return "bun";
  }

  const execPath = process.env.npm_execpath || "";
  if (execPath.includes("bun")) {
    return "bun";
  }

  if (
    __dirname.includes(".bun/install/global") ||
    __dirname.includes(".bun\\install\\global")
  ) {
    return "bun";
  }

  return userAgent ? "npm" : null;
}

const additionalDirs = [];
const pathDir = path.join(archRoot, "path");
if (existsSync(pathDir)) {
  additionalDirs.push(pathDir);
}

const USAGE_MONITOR_PORT = 48763;
const USAGE_MONITOR_HOST = "127.0.0.1";
const usageMonitorPollingMs = 5000;
const usageMonitorScriptPath = path.join(
  process.env.USERPROFILE || os.homedir(),
  "plugins",
  "codex-usage-monitor",
  "scripts",
  "build-usage-snapshot.mjs",
);

function shouldAutoShowUsageMonitor() {
  const args = process.argv.slice(2);
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    return false;
  }
  if (process.env.CODEX_USAGE_MONITOR_DISABLE === "1") {
    return false;
  }
  if (
    args.includes("--help") ||
    args.includes("-h") ||
    args.includes("--version") ||
    args.includes("-V") ||
    args.includes("-v")
  ) {
    return false;
  }
  const firstArg = args[0] || "";
  if (["app-server", "proto", "mcp"].includes(firstArg)) {
    return false;
  }
  return true;
}

function formatCompactNumber(value) {
  return new Intl.NumberFormat("en-US", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(value ?? 0);
}

function formatUsd(value) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value ?? 0);
}

function writeTerminalTitle(title) {
  try {
    process.stdout.write(`\u001b]0;${title}\u0007`);
    process.stdout.write(`\u001b]2;${title}\u0007`);
  } catch {
    // Ignore terminal title update failures.
  }
}

async function readUsageMonitorSnapshot() {
  return await new Promise((resolve, reject) => {
    const child = spawn(
      process.execPath,
      [usageMonitorScriptPath, "--stdout"],
      {
        stdio: ["ignore", "pipe", "pipe"],
        windowsHide: true,
        env: { ...process.env },
      },
    );

    let stdout = "";
    let stderr = "";
    child.stdout?.setEncoding("utf8");
    child.stderr?.setEncoding("utf8");
    child.stdout?.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr?.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || `usage monitor exited with code ${code}`));
        return;
      }
      try {
        resolve(JSON.parse(stdout));
      } catch (error) {
        reject(error);
      }
    });
  });
}

function formatUsageMonitorTitle(snapshot) {
  const apiStatus = snapshot?.status?.api?.status ?? "unknown";
  const apiLabel =
    apiStatus === "busy" ? "API busy" : apiStatus === "idle" ? "API idle" : "API unknown";
  const totalTokens = formatCompactNumber(snapshot?.totals?.totalTokens);
  const todayTokens = formatCompactNumber(snapshot?.today?.totalTokens);
  const totalUsd = formatUsd(snapshot?.totals?.estimatedUsd);
  const todayUsd = formatUsd(snapshot?.today?.estimatedUsd);
  return `Codex | ${apiLabel} | total ${totalTokens} ${totalUsd} | today ${todayTokens} ${todayUsd}`;
}

function createTerminalUsageMonitor() {
  let intervalId = null;
  let disposed = false;
  let inFlight = false;

  const tick = async () => {
    if (disposed || inFlight || !existsSync(usageMonitorScriptPath)) {
      return;
    }
    inFlight = true;
    try {
      const snapshot = await readUsageMonitorSnapshot();
      writeTerminalTitle(formatUsageMonitorTitle(snapshot));
    } catch {
      writeTerminalTitle("Codex | usage unavailable");
    } finally {
      inFlight = false;
    }
  };

  return {
    start() {
      tick();
      intervalId = setInterval(tick, usageMonitorPollingMs);
    },
    dispose() {
      disposed = true;
      if (intervalId !== null) {
        clearInterval(intervalId);
      }
      writeTerminalTitle("Codex");
    },
  };
}

function maybeStartTerminalUsageMonitor() {
  if (!shouldAutoShowUsageMonitor()) {
    return null;
  }
  if (!existsSync(usageMonitorScriptPath)) {
    return null;
  }
  const monitor = createTerminalUsageMonitor();
  monitor.start();
  return monitor;
}

const terminalUsageMonitor = maybeStartTerminalUsageMonitor();

const updatedPath = getUpdatedPath(additionalDirs);

const env = { ...process.env, PATH: updatedPath };
const packageManagerEnvVar =
  detectPackageManager() === "bun"
    ? "CODEX_MANAGED_BY_BUN"
    : "CODEX_MANAGED_BY_NPM";
env[packageManagerEnvVar] = "1";

const child = spawn(binaryPath, process.argv.slice(2), {
  stdio: "inherit",
  env,
});

child.on("error", (err) => {
  terminalUsageMonitor?.dispose();
  // Typically triggered when the binary is missing or not executable.
  // Re-throwing here will terminate the parent with a non-zero exit code
  // while still printing a helpful stack trace.
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});

// Forward common termination signals to the child so that it shuts down
// gracefully. In the handler we temporarily disable the default behavior of
// exiting immediately; once the child has been signaled we simply wait for
// its exit event which will in turn terminate the parent (see below).
const forwardSignal = (signal) => {
  if (child.killed) {
    return;
  }
  try {
    child.kill(signal);
  } catch {
    /* ignore */
  }
};

["SIGINT", "SIGTERM", "SIGHUP"].forEach((sig) => {
  process.on(sig, () => forwardSignal(sig));
});

// When the child exits, mirror its termination reason in the parent so that
// shell scripts and other tooling observe the correct exit status.
// Wrap the lifetime of the child process in a Promise so that we can await
// its termination in a structured way. The Promise resolves with an object
// describing how the child exited: either via exit code or due to a signal.
const childResult = await new Promise((resolve) => {
  child.on("exit", (code, signal) => {
    resolve(
      signal
        ? { type: "signal", signal }
        : { type: "code", exitCode: code ?? 1 },
    );
  });
});

terminalUsageMonitor?.dispose();

if (childResult.type === "signal") {
  // Re-emit the same signal so that the parent terminates with the expected
  // semantics (this also sets the correct exit code of 128 + n).
  process.kill(process.pid, childResult.signal);
} else {
  process.exit(childResult.exitCode);
}
