# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of installable **skills** and **MCP server configurations** for AI coding agents (Claude Code, GitHub Copilot, OpenCode). The tooling installs content by downloading it from GitHub and writing it to platform-specific config paths — there is no build system, package manager, or test suite.

## Key scripts

| Script | Purpose |
|---|---|
| `ai-tools.sh` | Interactive wizard — installs skills + MCP configs in one flow |
| `skill.sh` | Install a single skill for one or more platforms |
| `mcp.sh` | Merge an MCP server config into the target platform's config file |
| `skill.ps1` / `mcp.ps1` | PowerShell equivalents for Windows |

All scripts are designed to be piped from `curl` and use `set -euo pipefail`. They have no dependencies beyond `bash`, `curl`, `python3`, and (for Windows) PowerShell 5+.

## Architecture

### Skills (`skills/<name>/SKILL.md`)

Each skill is a single Markdown file with YAML front matter (`name`, `description`). Skills are installed by copying `SKILL.md` to a platform-specific path:

- **Claude Code**: `.claude/skills/<name>/SKILL.md` (local) or `~/.claude/skills/<name>/SKILL.md` (global)
- **OpenCode**: `.opencode/commands/<name>.md` / `~/.config/opencode/commands/<name>.md`
- **Copilot**: `.github/skills/<name>/SKILL.md` / `~/.copilot/skills/<name>/SKILL.md`

### MCP configs (`mcp/<name>.json`)

Each config is a JSON file with a `mcpServers` key following the Claude MCP format. `${env:VAR_NAME}` placeholders are resolved at install time — either from `--env KEY=VALUE` CLI args or from the current shell environment. The Python snippet in `mcp.sh` / `ai-tools.sh` handles merging into existing platform config files and translates the `mcpServers` key to the platform-specific key:

| Platform | Key |
|---|---|
| `claude` | `mcpServers` |
| `opencode` | `mcp` |
| `copilot` | `servers` |

### `ai-tools.sh` wizard

Inlines the logic from `skill.sh` and `mcp.sh` directly. The wizard state (`SEL_PLATFORMS`, `SEL_SKILLS`, `SEL_MCPS`, `SEL_MCP_ENVS`) is collected interactively and then applied via `do_apply()`. Env var values for MCP configs are joined with `|` as a delimiter inside `SEL_MCP_ENVS` and split back apart before being passed to `configure_mcp`.

## Adding a new skill

1. Create `skills/<name>/SKILL.md` with YAML front matter (`name`, `description`).
2. Add the name and description to the `SKILL_NAMES` / `SKILL_DESCS` arrays in `ai-tools.sh`.

## Adding a new MCP config

1. Create `mcp/<name>.json` with a `mcpServers` key. Use `${env:VAR_NAME}` for secrets.
2. Add the name, description, and required env vars to `MCP_NAMES` / `MCP_DESCS` / `MCP_ENVVARS` in `ai-tools.sh`.

## Manual testing

```bash
# Syntax-check a script without running it
bash -n ai-tools.sh
bash -n skill.sh
bash -n mcp.sh

# Dry-run skill install (inspect the destination path)
bash skill.sh dart-flutter-workflow --global

# Dry-run MCP merge (uses current env for placeholder resolution)
bash mcp.sh fvm --global
```
