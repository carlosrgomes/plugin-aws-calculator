#!/usr/bin/env bash
set -euo pipefail

# Self-bootstrapping launcher for aws-calculator-mcp.
# Ensures sample-aws-pricing-calculator-mcp, playwright, and Chromium are installed
# in a co-located cache directory so require("playwright") always succeeds.
# IMPORTANT: All bootstrap output goes to stderr to preserve MCP stdio JSON-RPC on stdout.

RUNTIME_DIR="${AWS_CALCULATOR_MCP_HOME:-$HOME/.cache/aws-calculator-mcp}"
MCP_ENTRY="$RUNTIME_DIR/node_modules/sample-aws-pricing-calculator-mcp/dist/mcp-server.js"
PW_BIN="$RUNTIME_DIR/node_modules/.bin/playwright"
STAMP_FILE="$RUNTIME_DIR/.chromium-ready"

# Ensure Homebrew / nvm / standard Node paths are available when launched from GUI apps
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

if ! command -v node >/dev/null 2>&1; then
  echo "[aws-calculator-mcp] ERROR: Node.js (>= 20) not found in PATH." >&2
  exit 1
fi

if [ ! -f "$MCP_ENTRY" ] || [ ! -d "$RUNTIME_DIR/node_modules/playwright" ]; then
  echo "[aws-calculator-mcp] First-time setup: installing sample-aws-pricing-calculator-mcp + playwright into $RUNTIME_DIR..." >&2
  mkdir -p "$RUNTIME_DIR"
  npm install --no-audit --no-fund --prefix "$RUNTIME_DIR" \
    sample-aws-pricing-calculator-mcp@latest playwright >&2
fi

if [ ! -f "$STAMP_FILE" ]; then
  echo "[aws-calculator-mcp] Installing Playwright Chromium browser (~190 MB)..." >&2
  "$PW_BIN" install chromium >&2
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$STAMP_FILE"
fi

exec node "$MCP_ENTRY" "$@"
