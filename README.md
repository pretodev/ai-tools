# pretodev/ai-tools

Skills and MCP configurations for AI coding agents — compatible with **Claude Code**, **GitHub Copilot**, and **OpenCode**.

## Interactive setup (recommended)

Run the wizard and answer a few questions — no flags to memorize:

```bash
curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/ai-tools.sh | bash
```

> `bash <(curl -fsSL ...)` also works if you prefer process substitution.

The wizard will guide you through:

1. **Environment** — global (`~/`) or local (current directory)
2. **Platforms** — Claude Code, OpenCode, GitHub Copilot (one or more)
3. **Skills** — pick which skills to install
4. **MCP servers** — pick which MCP configs to add (collects any required API keys)
5. **Confirmation** — review the summary before applying

---

## Install a skill

**macOS / Linux**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.sh) <skill-name>
```

**Windows (PowerShell)**
```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.ps1'))) <skill-name>
```

| Option | Description |
|---|---|
| `--global` / `-Global` | Install globally (user home). Default: current directory. |
| `--platforms` / `-Platforms` | Comma-separated platforms. Default: `claude`. |

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

```powershell
# Claude Code (local)
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.ps1'))) dart-flutter-workflow

# Claude Code (global)
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.ps1'))) dart-flutter-workflow -Global

# All platforms, globally
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/pretodev/ai-tools/main/skill.ps1'))) dart-flutter-workflow -Platforms claude,opencode,copilot -Global
```

### Install paths per platform

| Platform | Local | Global |
|---|---|---|
| `claude` | `.claude/skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` |
| `opencode` | `.opencode/commands/<name>.md` | `~/.config/opencode/commands/<name>.md` |
| `copilot` | `.github/skills/<name>/SKILL.md` | `~/.copilot/skills/<name>/SKILL.md` |

## Configure MCP servers

**macOS / Linux**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.sh) [<config-name>]
```

**Windows (PowerShell)**
```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.ps1'))) [<config-name>]
```

| Option | Description |
|---|---|
| `<config-name>` | Config to apply (default: `index`). Maps to `mcp/<name>.json`. |
| `--global` / `-Global` | Configure globally. Default: current directory. |
| `--platforms` / `-Platforms` | Comma-separated platforms. Default: `claude`. |

### Examples

```bash
# Default config, Claude Code (local)
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.sh)

# FVM config, all platforms, globally
bash <(curl -fsSL https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.sh) fvm --platforms claude,opencode,copilot --global
```

```powershell
# Default config, Claude Code (local)
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.ps1')))

# FVM config, all platforms, globally
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/pretodev/ai-tools/main/mcp.ps1'))) fvm -Platforms claude,opencode,copilot -Global
```

### Config paths per platform

| Platform | Local | Global |
|---|---|---|
| `claude` | `.mcp.json` | `~/.claude.json` |
| `opencode` | `opencode.json` | `~/.config/opencode/opencode.json` |
| `copilot` | `.vscode/mcp.json` | `~/Library/Application Support/Code/User/mcp.json` (macOS) / `%APPDATA%\Code\User\mcp.json` (Windows) |

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
