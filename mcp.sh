#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/pretodev/ai-tools/main"

usage() {
  echo "Usage: mcp.sh [<config-name>] [--platforms <platform,...>] [--global]" >&2
  echo "" >&2
  echo "Platforms: claude (default), opencode, copilot" >&2
  echo "" >&2
  echo "  <config-name>  MCP config to use (default: index). Maps to mcp/<name>.json" >&2
  echo "  --global       Configure globally (~/ paths). Default: configure in current directory." >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh)" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) --global" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) fvm" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) fvm --global" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) --platforms claude,opencode,copilot --global" >&2
  exit 1
}

mcp_file_for() {
  local platform="$1"
  local global="$2"

  if [[ "$global" == "true" ]]; then
    case "$platform" in
      claude)   echo "${HOME}/.claude.json" ;;
      opencode) echo "${HOME}/.config/opencode/config.json" ;;
      copilot)  echo "${HOME}/.config/github-copilot/mcp.json" ;;
      *) echo "Error: unknown platform '$platform' (supported: claude, opencode, copilot)" >&2; exit 1 ;;
    esac
  else
    case "$platform" in
      claude)   echo "$(pwd)/.mcp.json" ;;
      opencode) echo "$(pwd)/.opencode/config.json" ;;
      copilot)  echo "$(pwd)/.vscode/mcp.json" ;;
      *) echo "Error: unknown platform '$platform' (supported: claude, opencode, copilot)" >&2; exit 1 ;;
    esac
  fi
}

configure_mcp() {
  local config_name="$1"
  local platform="$2"
  local global="$3"
  local source_url="${REPO_RAW}/mcp/${config_name}.json"
  local dest_file
  dest_file="$(mcp_file_for "$platform" "$global")"

  local action="Configured"
  [[ -f "$dest_file" ]] && action="Updated"

  local tmp_source
  tmp_source="$(mktemp)"
  trap 'rm -f "$tmp_source"' EXIT

  if ! curl -fsSL "$source_url" -o "$tmp_source"; then
    echo "Error: MCP config '${config_name}' not found at ${source_url}" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dest_file")"

  python3 - "$tmp_source" "$dest_file" <<'PYEOF'
import json
import sys

source_path = sys.argv[1]
dest_path   = sys.argv[2]

with open(source_path) as f:
    source = json.load(f)

try:
    with open(dest_path) as f:
        dest = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    dest = {}

dest.setdefault("mcpServers", {})
dest["mcpServers"].update(source.get("mcpServers", {}))

with open(dest_path, "w") as f:
    json.dump(dest, f, indent=2)
    f.write("\n")
PYEOF

  echo "${action} [${platform}]: ${dest_file}"
}

CONFIG_NAME="index"
PLATFORMS="claude"
GLOBAL="false"
CONFIG_NAME_SET="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platforms) PLATFORMS="${2:-}"; shift 2 ;;
    --global)    GLOBAL="true"; shift ;;
    --help)      usage ;;
    --*)         echo "Error: unknown option '$1'" >&2; exit 1 ;;
    *)
      if [[ "$CONFIG_NAME_SET" == "false" ]]; then
        CONFIG_NAME="$1"
        CONFIG_NAME_SET="true"
        shift
      else
        echo "Error: unexpected argument '$1'" >&2
        exit 1
      fi
      ;;
  esac
done

if ! [[ "$CONFIG_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: invalid config name '${CONFIG_NAME}'" >&2
  exit 1
fi

IFS=',' read -ra PLATFORM_LIST <<< "$PLATFORMS"
for platform in "${PLATFORM_LIST[@]}"; do
  configure_mcp "$CONFIG_NAME" "$platform" "$GLOBAL"
done
