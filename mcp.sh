#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/pretodev/ai-tools/main"

usage() {
  echo "Usage: mcp.sh [<config-name>] [--platforms <platform,...>] [--global] [--env KEY=VALUE ...]" >&2
  echo "" >&2
  echo "Platforms: claude (default), opencode, copilot" >&2
  echo "" >&2
  echo "  <config-name>  MCP config to use (default: index). Maps to mcp/<name>.json" >&2
  echo "  --global       Configure globally (~/ paths). Default: configure in current directory." >&2
  echo "  --env KEY=VALUE  Resolve \${env:KEY} placeholders with VALUE (can be repeated)." >&2
  echo "                   Falls back to terminal environment variables." >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh)" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) --global" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) fvm" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) fvm --global" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) --platforms claude,opencode,copilot --global" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/mcp.sh) azure_devops --env AZURE_DEVOPS_ORG=myorg --env AZURE_DEVOPS_PAT=mytoken" >&2
  exit 1
}

mcp_file_for() {
  local platform="$1"
  local global="$2"

  if [[ "$global" == "true" ]]; then
    case "$platform" in
      claude)   echo "${HOME}/.claude.json" ;;
      opencode) echo "${HOME}/.config/opencode/opencode.json" ;;
      copilot)
        case "$(uname -s)" in
          Darwin) echo "${HOME}/Library/Application Support/Code/User/mcp.json" ;;
          *)      echo "${HOME}/.config/Code/User/mcp.json" ;;
        esac
        ;;
      *) echo "Error: unknown platform '$platform' (supported: claude, opencode, copilot)" >&2; exit 1 ;;
    esac
  else
    case "$platform" in
      claude)   echo "$(pwd)/.mcp.json" ;;
      opencode) echo "$(pwd)/opencode.json" ;;
      copilot)  echo "$(pwd)/.vscode/mcp.json" ;;
      *) echo "Error: unknown platform '$platform' (supported: claude, opencode, copilot)" >&2; exit 1 ;;
    esac
  fi
}

configure_mcp() {
  local config_name="$1"
  local platform="$2"
  local global="$3"
  shift 3
  local env_args=("$@")  # KEY=VALUE pairs for placeholder resolution

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

  # Platform-specific destination key:
  #   claude   -> mcpServers  (.mcp.json / ~/.claude.json)
  #   opencode -> mcp         (opencode.json)
  #   copilot  -> servers     (.vscode/mcp.json)
  # Source files always use "mcpServers" as the key.
  # ${env:VAR_NAME} placeholders are resolved from --env args or terminal environment.
  # Resolved values are written as literals (not as variable references).
  python3 - "$tmp_source" "$dest_file" "$platform" "${env_args[@]}" <<'PYEOF'
import json
import sys
import os
import re

source_path = sys.argv[1]
dest_path   = sys.argv[2]
platform    = sys.argv[3]
env_pairs   = sys.argv[4:]

PLATFORM_KEYS = {
    "claude":   "mcpServers",
    "opencode": "mcp",
    "copilot":  "servers",
}
dest_key = PLATFORM_KEYS.get(platform, "mcpServers")

# Build env overrides from KEY=VALUE args (take precedence over terminal env)
env_overrides = {}
for pair in env_pairs:
    if '=' in pair:
        k, v = pair.split('=', 1)
        env_overrides[k] = v

def resolve_env(value):
    if not isinstance(value, str):
        return value
    def replacer(m):
        var_name = m.group(1)
        if var_name in env_overrides:
            return env_overrides[var_name]
        return os.environ.get(var_name, m.group(0))
    return re.sub(r'\$\{env:([^}]+)\}', replacer, value)

def resolve_all(obj):
    if isinstance(obj, dict):
        return {k: resolve_all(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [resolve_all(v) for v in obj]
    if isinstance(obj, str):
        return resolve_env(obj)
    return obj

with open(source_path) as f:
    source = json.load(f)

try:
    with open(dest_path) as f:
        dest = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    dest = {}

def to_opencode_entry(entry):
    if 'command' in entry:
        cmd = entry['command']
        args = entry.get('args', [])
        env = entry.get('env', {})
        result = {'type': 'local', 'command': [cmd] + args}
        if env:
            result['environment'] = env
        return result
    elif 'url' in entry:
        result = {'type': 'remote', 'url': entry['url']}
        if 'headers' in entry:
            result['headers'] = entry['headers']
        return result
    return entry

servers = resolve_all(source.get("mcpServers", {}))
if platform == "opencode":
    servers = {k: to_opencode_entry(v) for k, v in servers.items()}

dest.setdefault(dest_key, {})
dest[dest_key].update(servers)

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
ENV_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platforms) PLATFORMS="${2:-}"; shift 2 ;;
    --global)    GLOBAL="true"; shift ;;
    --env)       ENV_ARGS+=("${2:-}"); shift 2 ;;
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
  configure_mcp "$CONFIG_NAME" "$platform" "$GLOBAL" "${ENV_ARGS[@]}"
done
