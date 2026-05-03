const OVERLAY_ID = "codex-usage-monitor-overlay";
const STYLE_ID = "codex-usage-monitor-style";
const POLL_INTERVAL_MS = 5000;
const REQUEST_TIMEOUT_MS = 8000;
const ENDPOINT_URL = "vscode://codex/usage-monitor-snapshot";
const HOST_ID = "local";

if (!window.__codexUsageMonitorOverlayInstalled) {
  window.__codexUsageMonitorOverlayInstalled = true;

  const vscode = acquireVsCodeApi();
  const pendingResponses = new Map();
  let lastSnapshot = null;
  let currentAnchor = null;

  function ensureStyles() {
    if (document.getElementById(STYLE_ID)) {
      return;
    }

    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
      .codex-usage-overlay {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
        margin-top: 10px;
        padding: 10px 12px;
        border: 1px solid color-mix(in srgb, var(--vscode-panel-border, rgba(255,255,255,.12)) 85%, transparent);
        border-radius: 14px;
        background:
          radial-gradient(circle at 0% 0%, rgba(86, 214, 193, 0.16), transparent 36%),
          linear-gradient(135deg, rgba(16, 28, 34, 0.92), rgba(11, 18, 25, 0.88));
        box-shadow: 0 14px 30px rgba(0, 0, 0, 0.2);
        backdrop-filter: blur(12px);
        color: var(--vscode-foreground, #d6d6d6);
        position: relative;
        overflow: hidden;
      }

      .codex-usage-overlay::after {
        content: "";
        position: absolute;
        inset: auto -40% -65% auto;
        width: 180px;
        height: 180px;
        border-radius: 999px;
        background: rgba(255, 189, 89, 0.14);
        filter: blur(24px);
        pointer-events: none;
      }

      .codex-usage-overlay__status {
        display: flex;
        align-items: center;
        gap: 10px;
        min-width: 120px;
      }

      .codex-usage-overlay__dot {
        width: 10px;
        height: 10px;
        border-radius: 999px;
        background: #7f8f8d;
        box-shadow: 0 0 0 0 rgba(116, 203, 255, 0.36);
        flex: 0 0 auto;
      }

      .codex-usage-overlay[data-api-status="busy"] .codex-usage-overlay__dot {
        background: #ffbd59;
        box-shadow: 0 0 0 0 rgba(255, 189, 89, 0.36);
        animation: codex-usage-pulse 1.8s infinite;
      }

      .codex-usage-overlay[data-api-status="idle"] .codex-usage-overlay__dot {
        background: #56d6c1;
        box-shadow: 0 0 0 0 rgba(86, 214, 193, 0.32);
        animation: codex-usage-pulse 2.6s infinite;
      }

      .codex-usage-overlay[data-api-status="unknown"] .codex-usage-overlay__dot {
        background: #f27d72;
      }

      .codex-usage-overlay__status-text {
        display: flex;
        flex-direction: column;
        gap: 2px;
      }

      .codex-usage-overlay__eyebrow {
        font-size: 10px;
        letter-spacing: 0.16em;
        text-transform: uppercase;
        color: color-mix(in srgb, var(--vscode-descriptionForeground, #9aa6b2) 88%, transparent);
      }

      .codex-usage-overlay__status-value {
        font-size: 12px;
        font-weight: 600;
        color: var(--vscode-foreground, #d6d6d6);
      }

      .codex-usage-overlay__metrics {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 10px;
        flex: 1 1 auto;
        min-width: 0;
      }

      .codex-usage-overlay__metric {
        min-width: 0;
        display: flex;
        flex-direction: column;
        gap: 3px;
      }

      .codex-usage-overlay__metric-label {
        font-size: 10px;
        letter-spacing: 0.12em;
        text-transform: uppercase;
        color: color-mix(in srgb, var(--vscode-descriptionForeground, #9aa6b2) 84%, transparent);
        white-space: nowrap;
      }

      .codex-usage-overlay__metric-value {
        font-family: var(--vscode-editor-font-family, ui-monospace, Consolas, monospace);
        font-size: 12px;
        font-weight: 600;
        color: var(--vscode-foreground, #d6d6d6);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      .codex-usage-overlay__footnote {
        margin-left: auto;
        font-size: 11px;
        color: color-mix(in srgb, var(--vscode-descriptionForeground, #9aa6b2) 82%, transparent);
        white-space: nowrap;
      }

      @keyframes codex-usage-pulse {
        0% { box-shadow: 0 0 0 0 rgba(86, 214, 193, 0.32); }
        70% { box-shadow: 0 0 0 12px rgba(86, 214, 193, 0); }
        100% { box-shadow: 0 0 0 0 rgba(86, 214, 193, 0); }
      }

      @media (max-width: 920px) {
        .codex-usage-overlay {
          flex-direction: column;
          align-items: flex-start;
        }

        .codex-usage-overlay__metrics {
          width: 100%;
          grid-template-columns: repeat(2, minmax(0, 1fr));
        }

        .codex-usage-overlay__footnote {
          margin-left: 0;
        }
      }
    `;

    document.head.appendChild(style);
  }

  function formatCompactNumber(value) {
    return new Intl.NumberFormat("en-US", {
      notation: "compact",
      maximumFractionDigits: 1,
    }).format(value ?? 0);
  }

  function formatMoney(value) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 4,
    }).format(value ?? 0);
  }

  function formatStatus(snapshot) {
    if (!snapshot) {
      return "Loading";
    }

    const status = snapshot.status?.api?.status ?? "unknown";
    return status === "busy" ? "Busy" : status === "idle" ? "Idle" : "Unknown";
  }

  function buildRequestId() {
    return `usage-overlay-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  function requestSnapshot() {
    const requestId = buildRequestId();
    return new Promise((resolve, reject) => {
      const timeout = window.setTimeout(() => {
        pendingResponses.delete(requestId);
        reject(new Error("Timed out waiting for usage snapshot"));
      }, REQUEST_TIMEOUT_MS);

      pendingResponses.set(requestId, { resolve, reject, timeout });
      vscode.postMessage({
        type: "fetch",
        hostId: HOST_ID,
        requestId,
        method: "GET",
        url: ENDPOINT_URL,
      });
    });
  }

  function handleFetchResponse(message) {
    const pending = pendingResponses.get(message.requestId);
    if (!pending) {
      return;
    }

    pendingResponses.delete(message.requestId);
    window.clearTimeout(pending.timeout);

    if (message.responseType !== "success") {
      pending.reject(new Error(message.error || `Request failed with status ${message.status}`));
      return;
    }

    try {
      pending.resolve(JSON.parse(message.bodyJsonString));
    } catch (error) {
      pending.reject(error instanceof Error ? error : new Error(String(error)));
    }
  }

  function findAnchor() {
    const footer = Array.from(document.querySelectorAll(".composer-footer"))
      .find((element) => element instanceof HTMLElement && element.offsetParent !== null);
    if (footer) {
      return footer;
    }

    const input = Array.from(document.querySelectorAll(".request-input-panel__inline-freeform"))
      .find((element) => element instanceof HTMLElement && element.offsetParent !== null);
    if (input) {
      return input.closest("form, section, div");
    }

    return null;
  }

  function ensureOverlay(anchor) {
    ensureStyles();

    let overlay = document.getElementById(OVERLAY_ID);
    if (!overlay) {
      overlay = document.createElement("div");
      overlay.id = OVERLAY_ID;
      overlay.className = "codex-usage-overlay";
      overlay.innerHTML = `
        <div class="codex-usage-overlay__status">
          <span class="codex-usage-overlay__dot"></span>
          <div class="codex-usage-overlay__status-text">
            <span class="codex-usage-overlay__eyebrow">Usage Monitor</span>
            <span class="codex-usage-overlay__status-value">Loading…</span>
          </div>
        </div>
        <div class="codex-usage-overlay__metrics">
          <div class="codex-usage-overlay__metric">
            <span class="codex-usage-overlay__metric-label">Total Tokens</span>
            <span class="codex-usage-overlay__metric-value" data-field="totalTokens">--</span>
          </div>
          <div class="codex-usage-overlay__metric">
            <span class="codex-usage-overlay__metric-label">Total USD</span>
            <span class="codex-usage-overlay__metric-value" data-field="totalUsd">--</span>
          </div>
          <div class="codex-usage-overlay__metric">
            <span class="codex-usage-overlay__metric-label">Today Tokens</span>
            <span class="codex-usage-overlay__metric-value" data-field="todayTokens">--</span>
          </div>
          <div class="codex-usage-overlay__metric">
            <span class="codex-usage-overlay__metric-label">Today USD</span>
            <span class="codex-usage-overlay__metric-value" data-field="todayUsd">--</span>
          </div>
        </div>
        <div class="codex-usage-overlay__footnote" data-field="meta">--</div>
      `;
    }

    if (anchor && anchor.parentElement) {
      if (overlay.parentElement !== anchor.parentElement || currentAnchor !== anchor) {
        currentAnchor = anchor;
        anchor.insertAdjacentElement("afterend", overlay);
      }
    }

    return overlay;
  }

  function renderSnapshot(snapshot) {
    const anchor = findAnchor();
    if (!anchor) {
      return;
    }

    const overlay = ensureOverlay(anchor);
    overlay.dataset.apiStatus = snapshot?.status?.api?.status ?? "unknown";
    overlay.querySelector(".codex-usage-overlay__status-value").textContent =
      `${formatStatus(snapshot)} • ${snapshot?.status?.api?.activeRequests ?? 0} active`;

    overlay.querySelector('[data-field="totalTokens"]').textContent =
      snapshot ? formatCompactNumber(snapshot.totals?.totalTokens) : "--";
    overlay.querySelector('[data-field="totalUsd"]').textContent =
      snapshot ? formatMoney(snapshot.totals?.estimatedUsd) : "--";
    overlay.querySelector('[data-field="todayTokens"]').textContent =
      snapshot ? formatCompactNumber(snapshot.today?.totalTokens) : "--";
    overlay.querySelector('[data-field="todayUsd"]').textContent =
      snapshot ? formatMoney(snapshot.today?.estimatedUsd) : "--";

    const meta =
      snapshot == null
        ? "Usage monitor unavailable"
        : `Updated ${new Date(snapshot.generatedAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })}`;
    overlay.querySelector('[data-field="meta"]').textContent = meta;
  }

  async function refresh() {
    try {
      const snapshot = await requestSnapshot();
      lastSnapshot = snapshot;
      renderSnapshot(snapshot);
    } catch {
      renderSnapshot(lastSnapshot);
    }
  }

  window.addEventListener("message", (event) => {
    const data = event?.data;
    if (!data || typeof data !== "object") {
      return;
    }

    if (data.type === "fetch-response") {
      handleFetchResponse(data);
      return;
    }

    if (data.type === "navigate-to-route" || data.type === "thread-stream-state-changed") {
      window.setTimeout(() => renderSnapshot(lastSnapshot), 0);
    }
  });

  const observer = new MutationObserver(() => {
    renderSnapshot(lastSnapshot);
  });

  function boot() {
    renderSnapshot(lastSnapshot);
    refresh();
    window.setInterval(refresh, POLL_INTERVAL_MS);
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot, { once: true });
  } else {
    boot();
  }
}
