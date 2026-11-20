#!/usr/bin/env bash
set -euo pipefail

# One-command installer for aws-calculator-mcp plugin:
# 1. Installs sample-aws-pricing-calculator-mcp + playwright + Chromium into ~/.cache/aws-calculator-mcp
# 2. Installs/registers the plugin in Antigravity (agy) and/or Claude Code (claude) if present

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="${AWS_CALCULATOR_MCP_HOME:-$HOME/.cache/aws-calculator-mcp}"
PW_BIN="$RUNTIME_DIR/node_modules/.bin/playwright"
STAMP_FILE="$RUNTIME_DIR/.chromium-ready"

echo "==> [1/3] Checking Node.js..."
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js 20+ is required. Install from https://nodejs.org or via nvm/brew." >&2
  exit 1
fi
echo "    Node: $(node -v) | npm: $(npm -v)"

echo "==> [2/3] Installing sample-aws-pricing-calculator-mcp + playwright + Chromium in $RUNTIME_DIR..."
mkdir -p "$RUNTIME_DIR"
npm install --no-audit --no-fund --prefix "$RUNTIME_DIR" \
  sample-aws-pricing-calculator-mcp@latest playwright
"$PW_BIN" install chromium
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$STAMP_FILE"
echo "    MCP + Playwright + Chromium ready."

echo "==> [3/3] Registering plugin / MCP server in detected CLIs..."

if command -v agy >/dev/null 2>&1; then
  AGY_PLUGIN_DIR="$HOME/.gemini/config/plugins/aws-calculator-mcp"
  mkdir -p "$HOME/.gemini/config/plugins"
  if [ -L "$AGY_PLUGIN_DIR" ] || [ -d "$AGY_PLUGIN_DIR" ]; then
    rm -rf "$AGY_PLUGIN_DIR"
  fi
  ln -s "$REPO_DIR" "$AGY_PLUGIN_DIR"
  echo "    [Antigravity] Plugin linked at $AGY_PLUGIN_DIR (includes MCP + skill + rules)."
  echo "    [Antigravity] Note: if you had a standalone 'aws-calculator-mcp' entry in 'agy mcp list', you can remove it with: agy mcp remove aws-calculator-mcp"
else
  echo "    [Antigravity] 'agy' CLI not found — skipped."
fi

if command -v claude >/dev/null 2>&1; then
  claude mcp remove aws-calculator-mcp -s user >/dev/null 2>&1 || true
  claude mcp add aws-calculator-mcp -s user -- bash "$REPO_DIR/scripts/run-mcp.sh"
  echo "    [Claude Code] Registered MCP 'aws-calculator-mcp' (-s user) using $REPO_DIR/scripts/run-mcp.sh"
else
  echo "    [Claude Code] 'claude' CLI not found — skipped."
fi

echo ""
echo "Done! You can also configure Claude Desktop or Devin with:"
cat <<EOF
{
  "mcpServers": {
    "aws-calculator-mcp": {
      "command": "bash",
      "args": ["$REPO_DIR/scripts/run-mcp.sh"]
    }
  }
}
EOF
