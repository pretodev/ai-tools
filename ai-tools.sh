#!/usr/bin/env bash
# ai-tools.sh — Interactive setup wizard for pretodev/ai-tools
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/ai-tools.sh | bash
#   bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/ai-tools.sh)
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/pretodev/ai-tools/main"
TTY=/dev/tty

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 2 ]]; then
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
  W='\033[1m'; D='\033[2m'; N='\033[0m'
else
  R=''; G=''; Y=''; C=''; W=''; D=''; N=''
fi

# ── Catalog ───────────────────────────────────────────────────────────────────
SKILL_NAMES=("dart-flutter-workflow" "flutter-select-element")
SKILL_DESCS=("Dart/Flutter workflow: FVM, analyzer, formatter, tests"
             "Context-aware actions on Dart/Flutter elements")

MCP_NAMES=("index" "fvm" "azure_devops")
MCP_DESCS=("dart-mcp-server + context7"
           "dart-mcp-server via FVM"
           "Azure DevOps MCP server")
# Space-separated env var names required by each MCP (empty = none)
MCP_ENVVARS=("CONTEXT7_API_KEY"
             ""
             "AZURE_DEVOPS_ORG AZURE_DEVOPS_PAT")

PLATFORM_NAMES=("claude" "opencode" "copilot")
PLATFORM_DESCS=("Claude Code" "OpenCode" "GitHub Copilot")

# ── State ─────────────────────────────────────────────────────────────────────
GLOBAL="false"
SCOPE_LABEL=""
SEL_PLATFORMS=()
SEL_SKILLS=()
SEL_MCPS=()
SEL_MCP_ENVS=()   # parallel to SEL_MCPS — each element: "K1=V1|K2=V2" or ""

# ── Helpers ───────────────────────────────────────────────────────────────────
hr() {
  printf "${D}  ──────────────────────────────────────────────${N}\n" >&2
}

step_header() {
  printf "\n${W}  Step %d of 4 — %s${N}\n" "$1" "$2" >&2
  hr
}

read_line() {
  printf "  ${C}▶ %s${N} " "$1" >&2
  local r; IFS= read -r r < "$TTY"; echo "$r"
}

read_secret() {
  printf "  ${C}▶ %s${N} " "$1" >&2
  local r; IFS= read -rs r < "$TTY"
  printf "\n" >&2
  echo "$r"
}

# Parse "1 2 3" or "a" into 0-based indices stored in SEL_IDX
SEL_IDX=()
parse_selection() {
  local input="$1" max="$2"
  SEL_IDX=()
  if [[ "$input" == "a" ]]; then
    local i; for ((i=0; i<max; i++)); do SEL_IDX+=("$i"); done
    return
  fi
  local tok
  for tok in $input; do
    if [[ "$tok" =~ ^[0-9]+$ ]] && ((tok >= 1 && tok <= max)); then
      SEL_IDX+=("$((tok-1))")
    fi
  done
}

# ── Wizard steps ──────────────────────────────────────────────────────────────

wizard_scope() {
  step_header 1 "Environment"
  printf "  Where should the configuration be installed?\n\n" >&2
  printf "    ${W}1.${N} Global  ${D}(~/ — applies to all projects)${N}\n" >&2
  printf "    ${W}2.${N} Local   ${D}(%s)${N}\n\n" "$(pwd)" >&2

  while true; do
    local c; c=$(read_line "Choose [1/2], default 2:")
    [[ -z "$c" ]] && c="2"
    case "$c" in
      1) GLOBAL="true";  SCOPE_LABEL="Global (~/)";    return ;;
      2) GLOBAL="false"; SCOPE_LABEL="Local ($(pwd))"; return ;;
      *) printf "  Please enter 1 or 2.\n" >&2 ;;
    esac
  done
}

wizard_platforms() {
  step_header 2 "Platforms"
  printf "  Which AI platforms to configure?\n\n" >&2

  local i
  for ((i=0; i<${#PLATFORM_NAMES[@]}; i++)); do
    printf "    ${W}%d.${N} %-10s ${D}%s${N}\n" \
      "$((i+1))" "${PLATFORM_NAMES[$i]}" "${PLATFORM_DESCS[$i]}" >&2
  done
  printf "\n  ${D}Numbers separated by spaces, 'a' for all. Default: 1${N}\n\n" >&2

  while true; do
    local input; input=$(read_line "Platforms [1]:")
    [[ -z "$input" ]] && input="1"
    parse_selection "$input" "${#PLATFORM_NAMES[@]}"
    if [[ ${#SEL_IDX[@]} -gt 0 ]]; then
      SEL_PLATFORMS=()
      local idx
      for idx in "${SEL_IDX[@]}"; do
        SEL_PLATFORMS+=("${PLATFORM_NAMES[$idx]}")
      done
      return
    fi
    printf "  Please select at least one platform.\n" >&2
  done
}

wizard_skills() {
  step_header 3 "Skills"
  printf "  Which skills to install? (optional)\n\n" >&2

  local i
  for ((i=0; i<${#SKILL_NAMES[@]}; i++)); do
    printf "    ${W}%d.${N} %-32s ${D}%s${N}\n" \
      "$((i+1))" "${SKILL_NAMES[$i]}" "${SKILL_DESCS[$i]}" >&2
  done
  printf "\n  ${D}Numbers, 'a' for all, or Enter to skip.${N}\n\n" >&2

  local input; input=$(read_line "Skills [none]:")
  SEL_SKILLS=()
  [[ -z "$input" ]] && return

  parse_selection "$input" "${#SKILL_NAMES[@]}"
  local idx
  for idx in "${SEL_IDX[@]}"; do
    SEL_SKILLS+=("${SKILL_NAMES[$idx]}")
  done
}

wizard_mcps() {
  step_header 4 "MCP Servers"
  printf "  Which MCP server configs to add? (optional)\n\n" >&2

  local i
  for ((i=0; i<${#MCP_NAMES[@]}; i++)); do
    printf "    ${W}%d.${N} %-14s ${D}%s${N}\n" \
      "$((i+1))" "${MCP_NAMES[$i]}" "${MCP_DESCS[$i]}" >&2
  done
  printf "\n  ${D}Numbers, 'a' for all, or Enter to skip.${N}\n\n" >&2

  local input; input=$(read_line "MCPs [none]:")
  SEL_MCPS=()
  SEL_MCP_ENVS=()
  [[ -z "$input" ]] && return

  parse_selection "$input" "${#MCP_NAMES[@]}"

  local idx
  for idx in "${SEL_IDX[@]}"; do
    local mcp="${MCP_NAMES[$idx]}"
    local envvars="${MCP_ENVVARS[$idx]}"
    SEL_MCPS+=("$mcp")

    if [[ -z "$envvars" ]]; then
      SEL_MCP_ENVS+=("")
      continue
    fi

    printf "\n  ${Y}%s${N} requires environment variables:\n" "$mcp" >&2

    local pairs=()
    local var
    for var in $envvars; do
      local current="${!var:-}"
      local val

      if [[ -n "$current" ]]; then
        printf "    %s ${D}(already set in environment)${N}\n" "$var" >&2
        val=$(read_line "${var} [Enter to keep current]:")
        [[ -z "$val" ]] && val="$current"
      elif [[ "$var" == *PAT* || "$var" == *TOKEN* || "$var" == *SECRET* || "$var" == *KEY* ]]; then
        val=$(read_secret "${var} (hidden):")
      else
        val=$(read_line "${var}:")
      fi

      [[ -n "$val" ]] && pairs+=("${var}=${val}")
    done

    # Join pairs with | delimiter
    local joined="" p
    for p in "${pairs[@]+"${pairs[@]}"}"; do
      [[ -n "$joined" ]] && joined="${joined}|${p}" || joined="$p"
    done
    SEL_MCP_ENVS+=("$joined")
  done
}

wizard_confirm() {
  printf "\n" >&2; hr
  printf "\n${W}  Summary${N}\n\n" >&2

  printf "  %-12s %s\n" "Scope:"     "$SCOPE_LABEL" >&2

  local p_csv
  if [[ ${#SEL_PLATFORMS[@]} -gt 0 ]]; then
    p_csv=$(IFS=', '; echo "${SEL_PLATFORMS[*]}")
  else
    p_csv="—"
  fi
  printf "  %-12s %s\n" "Platforms:" "$p_csv" >&2

  if [[ ${#SEL_SKILLS[@]} -gt 0 ]]; then
    printf "  %-12s\n" "Skills:" >&2
    local s; for s in "${SEL_SKILLS[@]}"; do printf "    ${G}✓${N} %s\n" "$s" >&2; done
  else
    printf "  %-12s %s\n" "Skills:" "(none)" >&2
  fi

  if [[ ${#SEL_MCPS[@]} -gt 0 ]]; then
    printf "  %-12s\n" "MCPs:" >&2
    local s; for s in "${SEL_MCPS[@]}"; do printf "    ${G}✓${N} %s\n" "$s" >&2; done
  else
    printf "  %-12s %s\n" "MCPs:" "(none)" >&2
  fi

  printf "\n" >&2; hr; printf "\n" >&2

  while true; do
    local c; c=$(read_line "Proceed? [y/N]:")
    case "$c" in
      y|Y|yes|YES) return ;;
      *) printf "\n  ${Y}Cancelled.${N}\n\n" >&2; exit 0 ;;
    esac
  done
}

# ── Install logic (inlined from skill.sh + mcp.sh) ───────────────────────────

mcp_file_for() {
  local platform="$1" global="$2"
  if [[ "$global" == "true" ]]; then
    case "$platform" in
      claude)   echo "${HOME}/.claude.json" ;;
      opencode) echo "${HOME}/.config/opencode/opencode.json" ;;
      copilot)
        case "$(uname -s)" in
          Darwin) echo "${HOME}/Library/Application Support/Code/User/mcp.json" ;;
          *)      echo "${HOME}/.config/Code/User/mcp.json" ;;
        esac ;;
      *) printf "Error: unknown platform '%s'\n" "$platform" >&2; exit 1 ;;
    esac
  else
    case "$platform" in
      claude)   echo "$(pwd)/.mcp.json" ;;
      opencode) echo "$(pwd)/opencode.json" ;;
      copilot)  echo "$(pwd)/.vscode/mcp.json" ;;
      *) printf "Error: unknown platform '%s'\n" "$platform" >&2; exit 1 ;;
    esac
  fi
}

configure_mcp() {
  local config_name="$1" platform="$2" global="$3"
  shift 3
  local env_args=("$@")

  local source_url="${REPO_RAW}/mcp/${config_name}.json"
  local dest_file; dest_file="$(mcp_file_for "$platform" "$global")"
  local action="Configured"; [[ -f "$dest_file" ]] && action="Updated"

  local tmp; tmp="$(mktemp)"
  if ! curl -fsSL "$source_url" -o "$tmp"; then
    rm -f "$tmp"
    printf "    ${R}✗ Error:${N} MCP config '%s' not found at %s\n" "$config_name" "$source_url" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dest_file")"

  python3 - "$tmp" "$dest_file" "$platform" "${env_args[@]+"${env_args[@]}"}" <<'PYEOF'
import json, sys, os, re

src, dst, plat = sys.argv[1], sys.argv[2], sys.argv[3]
pairs = sys.argv[4:]
KEYS = {"claude": "mcpServers", "opencode": "mcp", "copilot": "servers"}
dk = KEYS.get(plat, "mcpServers")
overrides = dict(p.split('=', 1) for p in pairs if '=' in p)

def resolve(v):
    if not isinstance(v, str): return v
    return re.sub(r'\$\{env:([^}]+)\}',
        lambda m: overrides.get(m.group(1), os.environ.get(m.group(1), m.group(0))), v)

def deep(o):
    if isinstance(o, dict): return {k: deep(v) for k, v in o.items()}
    if isinstance(o, list): return [deep(v) for v in o]
    return resolve(o)

with open(src) as f: source = json.load(f)
try:
    with open(dst) as f: dest = json.load(f)
except (FileNotFoundError, json.JSONDecodeError): dest = {}

dest.setdefault(dk, {})
dest[dk].update(deep(source.get("mcpServers", {})))

with open(dst, "w") as f:
    json.dump(dest, f, indent=2)
    f.write("\n")
PYEOF

  rm -f "$tmp"
  printf "    ${G}✓${N} %s [%s] → %s\n" "$action" "$platform" "$dest_file" >&2
}

skill_dest_for() {
  local name="$1" platform="$2" global="$3"
  if [[ "$global" == "true" ]]; then
    case "$platform" in
      claude)   echo "${HOME}/.claude/skills/${name}/SKILL.md" ;;
      opencode) echo "${HOME}/.config/opencode/commands/${name}.md" ;;
      copilot)  echo "${HOME}/.copilot/skills/${name}/SKILL.md" ;;
      *) printf "Error: unknown platform '%s'\n" "$platform" >&2; exit 1 ;;
    esac
  else
    case "$platform" in
      claude)   echo "$(pwd)/.claude/skills/${name}/SKILL.md" ;;
      opencode) echo "$(pwd)/.opencode/commands/${name}.md" ;;
      copilot)  echo "$(pwd)/.github/skills/${name}/SKILL.md" ;;
      *) printf "Error: unknown platform '%s'\n" "$platform" >&2; exit 1 ;;
    esac
  fi
}

install_skill() {
  local name="$1" platform="$2" global="$3"
  local url="${REPO_RAW}/skills/${name}/SKILL.md"
  local dest; dest="$(skill_dest_for "$name" "$platform" "$global")"
  local action="Installed"; [[ -f "$dest" ]] && action="Updated"

  mkdir -p "$(dirname "$dest")"
  if ! curl -fsSL "$url" -o "$dest"; then
    rm -f "$dest"
    printf "    ${R}✗ Error:${N} skill '%s' not found at %s\n" "$name" "$url" >&2
    exit 1
  fi
  printf "    ${G}✓${N} %s [%s] → %s\n" "$action" "$platform" "$dest" >&2
}

# ── Apply ─────────────────────────────────────────────────────────────────────

do_apply() {
  printf "\n${W}  Applying...${N}\n\n" >&2

  if [[ ${#SEL_SKILLS[@]} -gt 0 ]]; then
    local skill
    for skill in "${SEL_SKILLS[@]}"; do
      printf "  ${C}● Skill:${N} %s\n" "$skill" >&2
      local p
      for p in "${SEL_PLATFORMS[@]}"; do
        install_skill "$skill" "$p" "$GLOBAL"
      done
    done
  fi

  if [[ ${#SEL_MCPS[@]} -gt 0 ]]; then
    local i
    for ((i=0; i<${#SEL_MCPS[@]}; i++)); do
      local mcp="${SEL_MCPS[$i]}"
      local env_str="${SEL_MCP_ENVS[$i]}"
      printf "  ${C}● MCP:${N} %s\n" "$mcp" >&2

      local env_flags=()
      if [[ -n "$env_str" ]]; then
        local pairs pair
        IFS='|' read -ra pairs <<< "$env_str"
        for pair in "${pairs[@]+"${pairs[@]}"}"; do
          env_flags+=("--env" "$pair")
        done
      fi

      local p
      for p in "${SEL_PLATFORMS[@]}"; do
        configure_mcp "$mcp" "$p" "$GLOBAL" "${env_flags[@]+"${env_flags[@]}"}"
      done
    done
  fi

  printf "\n  ${G}✓ All done!${N}\n\n" >&2
}

# ── Main ──────────────────────────────────────────────────────────────────────

printf "\n${W}${C}" >&2
printf "  ┌──────────────────────────────────────────────┐\n" >&2
printf "  │   pretodev / ai-tools  —  setup wizard       │\n" >&2
printf "  └──────────────────────────────────────────────┘${N}\n" >&2

wizard_scope
wizard_platforms
wizard_skills
wizard_mcps
wizard_confirm
do_apply
