#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/pretodev/ai-tools/main"

usage() {
  echo "Usage: skill.sh <skill-name> [--platforms <platform,...>] [--global]" >&2
  echo "" >&2
  echo "Platforms: claude (default), opencode, copilot" >&2
  echo "" >&2
  echo "  --global    Install globally (~/ paths). Default: install in current directory." >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/skill.sh) dart-flutter-workflow" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/skill.sh) dart-flutter-workflow --global" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/skill.sh) dart-flutter-workflow --platforms claude,opencode --global" >&2
  exit 1
}

# Returns the destination file path for a skill on a given platform.
# File naming conventions per platform:
#   claude   -> .claude/skills/<name>/SKILL.md   (directory + fixed filename)
#   opencode -> .opencode/commands/<name>.md     (flat file, .md extension)
#   copilot  -> .github/skills/<name>/SKILL.md   (directory + fixed filename)
skill_dest_for() {
  local skill_name="$1"
  local platform="$2"
  local global="$3"

  if [[ "$global" == "true" ]]; then
    case "$platform" in
      claude)   echo "${HOME}/.claude/skills/${skill_name}/SKILL.md" ;;
      opencode) echo "${HOME}/.config/opencode/commands/${skill_name}.md" ;;
      copilot)  echo "${HOME}/.copilot/skills/${skill_name}/SKILL.md" ;;
      *) echo "Error: unknown platform '$platform' (supported: claude, opencode, copilot)" >&2; exit 1 ;;
    esac
  else
    case "$platform" in
      claude)   echo "$(pwd)/.claude/skills/${skill_name}/SKILL.md" ;;
      opencode) echo "$(pwd)/.opencode/commands/${skill_name}.md" ;;
      copilot)  echo "$(pwd)/.github/skills/${skill_name}/SKILL.md" ;;
      *) echo "Error: unknown platform '$platform' (supported: claude, opencode, copilot)" >&2; exit 1 ;;
    esac
  fi
}

install_skill() {
  local skill_name="$1"
  local platform="$2"
  local global="$3"
  local source_url="${REPO_RAW}/skills/${skill_name}/SKILL.md"
  local dest_file
  dest_file="$(skill_dest_for "$skill_name" "$platform" "$global")"

  local action="Installed"
  [[ -f "$dest_file" ]] && action="Updated"

  mkdir -p "$(dirname "$dest_file")"

  if ! curl -fsSL "$source_url" -o "$dest_file"; then
    rm -f "$dest_file"
    echo "Error: skill '${skill_name}' not found at ${source_url}" >&2
    exit 1
  fi

  echo "${action} [${platform}]: ${dest_file}"
}

SKILL_NAME="${1:-}"
PLATFORMS="claude"
GLOBAL="false"

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platforms) PLATFORMS="${2:-}"; shift 2 ;;
    --global)    GLOBAL="true"; shift ;;
    *) echo "Error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

[[ -z "$SKILL_NAME" ]] && usage

if ! [[ "$SKILL_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: invalid skill name '$SKILL_NAME'" >&2
  exit 1
fi

IFS=',' read -ra PLATFORM_LIST <<< "$PLATFORMS"
for platform in "${PLATFORM_LIST[@]}"; do
  install_skill "$SKILL_NAME" "$platform" "$GLOBAL"
done
