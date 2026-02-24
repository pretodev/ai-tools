[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ConfigName = "index",
    [string]$Platforms = "claude",
    [switch]$Global,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$REPO_RAW = "https://raw.githubusercontent.com/pretodev/ai-tools/main"

if ($Help) {
    Write-Host "Usage: mcp.ps1 [<config-name>] [-Platforms <platform,...>] [-Global]"
    Write-Host ""
    Write-Host "Platforms: claude (default), opencode, copilot"
    Write-Host ""
    Write-Host "  <config-name>  MCP config to use (default: index). Maps to mcp/<name>.json"
    Write-Host "  -Global        Configure globally (~/ paths). Default: configure in current directory."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1')))"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) -Global"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) fvm"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) fvm -Global"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) -Platforms claude,opencode,copilot -Global"
    exit 0
}

# Returns the destination config file path for a platform.
# Platform-specific config files:
#   claude   -> .mcp.json / ~/.claude.json
#   opencode -> opencode.json / ~/.config/opencode/opencode.json
#   copilot  -> .vscode/mcp.json / %APPDATA%\Code\User\mcp.json
function Get-McpFile {
    param([string]$Platform, [bool]$IsGlobal)

    if ($IsGlobal) {
        switch ($Platform) {
            "claude"   { return (Join-Path $HOME ".claude.json") }
            "opencode" { return (Join-Path $HOME ".config\opencode\opencode.json") }
            "copilot"  { return (Join-Path $env:APPDATA "Code\User\mcp.json") }
            default {
                Write-Host "Error: unknown platform '$Platform' (supported: claude, opencode, copilot)" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        $cwd = (Get-Location).Path
        switch ($Platform) {
            "claude"   { return (Join-Path $cwd ".mcp.json") }
            "opencode" { return (Join-Path $cwd "opencode.json") }
            "copilot"  { return (Join-Path $cwd ".vscode\mcp.json") }
            default {
                Write-Host "Error: unknown platform '$Platform' (supported: claude, opencode, copilot)" -ForegroundColor Red
                exit 1
            }
        }
    }
}

# Merges mcpServers from $SourceFile into the platform-specific key in $DestFile.
# Source files always use "mcpServers" as the key.
# Platform-specific destination keys:
#   claude   -> mcpServers
#   opencode -> mcp
#   copilot  -> servers
function Merge-McpJson {
    param([string]$SourceFile, [string]$DestFile, [string]$Platform)

    $platformKeys = @{
        "claude"   = "mcpServers"
        "opencode" = "mcp"
        "copilot"  = "servers"
    }
    $destKey = if ($platformKeys.ContainsKey($Platform)) { $platformKeys[$Platform] } else { "mcpServers" }

    $source = Get-Content $SourceFile -Raw | ConvertFrom-Json

    $dest = [PSCustomObject]@{}
    if (Test-Path $DestFile) {
        try {
            $dest = Get-Content $DestFile -Raw | ConvertFrom-Json
        } catch {
            $dest = [PSCustomObject]@{}
        }
    }

    # Ensure destination key exists
    if (-not ($dest.PSObject.Properties.Name -contains $destKey)) {
        $dest | Add-Member -MemberType NoteProperty -Name $destKey -Value ([PSCustomObject]@{})
    }

    # Merge source mcpServers into dest's platform key
    $sourceServers = $source.mcpServers
    if ($null -ne $sourceServers) {
        foreach ($prop in $sourceServers.PSObject.Properties) {
            $dest.$destKey | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $prop.Value -Force
        }
    }

    # Write back as UTF-8 without BOM
    $json = ($dest | ConvertTo-Json -Depth 20) + [System.Environment]::NewLine
    [System.IO.File]::WriteAllText($DestFile, $json, (New-Object System.Text.UTF8Encoding $false))
}

if ($ConfigName -notmatch '^[a-zA-Z0-9_-]+$') {
    Write-Host "Error: invalid config name '$ConfigName'" -ForegroundColor Red
    exit 1
}

foreach ($platform in ($Platforms -split ',')) {
    $p         = $platform.Trim()
    $destFile  = Get-McpFile -Platform $p -IsGlobal $Global.IsPresent
    $sourceUrl = "$REPO_RAW/mcp/$ConfigName.json"
    $action    = if (Test-Path $destFile) { "Updated" } else { "Configured" }

    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -Uri $sourceUrl -OutFile $tmpFile -UseBasicParsing
    } catch {
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
        Write-Host "Error: MCP config '$ConfigName' not found at $sourceUrl" -ForegroundColor Red
        exit 1
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destFile) | Out-Null
    Merge-McpJson -SourceFile $tmpFile -DestFile $destFile -Platform $p
    Remove-Item $tmpFile -ErrorAction SilentlyContinue

    Write-Host "$action [$p]: $destFile"
}
