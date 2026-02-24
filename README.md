# pretodev/ai-tools

Skills and MCP configurations for AI coding agents — compatible with **Claude Code**, **GitHub Copilot**, and **OpenCode**.

## Install a skill

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.sh) <skill-name>
```

| Option | Description |
|---|---|
| `--global` | Install globally (user home). Default: current directory. |
| `--platforms <list>` | Comma-separated platforms. Default: `claude`. |

**Platforms:** `claude`, `opencode`, `copilot`

### Examples

```bash
# Claude Code (local)
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.sh) dart-flutter-workflow

# Claude Code (global)
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.sh) dart-flutter-workflow --global

# All platforms, globally
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.sh) dart-flutter-workflow --platforms claude,opencode,copilot --global
```

### Install paths per platform

| Platform | Local | Global |
|---|---|---|
| `claude` | `.claude/skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` |
| `opencode` | `.opencode/commands/<name>.md` | `~/.config/opencode/commands/<name>.md` |
| `copilot` | `.github/skills/<name>/SKILL.md` | `~/.copilot/skills/<name>/SKILL.md` |

## Configure MCP servers

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.sh) [<config-name>]
```

| Option | Description |
|---|---|
| `<config-name>` | Config to apply (default: `index`). Maps to `mcp/<name>.json`. |
| `--global` | Configure globally. Default: current directory. |
| `--platforms <list>` | Comma-separated platforms. Default: `claude`. |

### Examples

```bash
# Default config, Claude Code (local)
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.sh)

# FVM config, all platforms, globally
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.sh) fvm --platforms claude,opencode,copilot --global
```

### Config paths per platform

| Platform | Local | Global |
|---|---|---|
| `claude` | `.mcp.json` | `~/.claude.json` |
| `opencode` | `opencode.json` | `~/.config/opencode/opencode.json` |
| `copilot` | `.vscode/mcp.json` | `~/Library/Application Support/Code/User/mcp.json` (macOS) |

> MCP configs are merged into existing files — existing entries are preserved.

## Available skills

| Skill | Description |
|---|---|
| [`dart-flutter-workflow`](skills/dart-flutter-workflow/SKILL.md) | Operational workflow for Dart/Flutter projects: FVM, analyzer, formatter, tests |
| [`flutter-select-element`](skills/flutter-select-element/SKILL.md) | Context-aware actions on any Dart/Flutter element at the cursor position |

## Available MCP configs

| Config | Servers included |
|---|---|
| [`index`](mcp/index.json) | `dart-mcp-server`, `context7`, `azure-devops` |
| [`fvm`](mcp/fvm.json) | `dart-mcp-server` (via FVM) |
