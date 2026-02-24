#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/pretodev/ai-tools/main"
SKILLS_DIR="${HOME}/.claude/skills"

usage() {
  echo "Usage: skill.sh <skill-name>" >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  bash <(curl -fsSL ${REPO_RAW}/skill.sh) dart-flutter-workflow" >&2
  exit 1
}

SKILL_NAME="${1:-}"

[[ -z "$SKILL_NAME" ]] && usage

# Prevent directory traversal
if ! [[ "$SKILL_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Error: invalid skill name '$SKILL_NAME'" >&2
  exit 1
fi

SOURCE_URL="${REPO_RAW}/skills/${SKILL_NAME}/SKILL.md"
DEST_DIR="${SKILLS_DIR}/${SKILL_NAME}"
DEST_FILE="${DEST_DIR}/SKILL.md"

ACTION="Installed"
[[ -f "$DEST_FILE" ]] && ACTION="Updated"

mkdir -p "$DEST_DIR"

if ! curl -fsSL "$SOURCE_URL" -o "$DEST_FILE"; then
  rm -f "$DEST_FILE"
  echo "Error: skill '${SKILL_NAME}' not found at ${SOURCE_URL}" >&2
  exit 1
fi

echo "${ACTION}: ${DEST_FILE}"
