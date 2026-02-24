[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ConfigName = "index",
    [string]$Platforms = "claude",
    [string[]]$Env = @(),
    [switch]$Global,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$REPO_RAW = "https://raw.githubusercontent.com/pretodev/ai-tools/main"

if ($Help) {
    Write-Host "Usage: mcp.ps1 [<config-name>] [-Platforms <platform,...>] [-Env KEY=VALUE ...] [-Global]"
    Write-Host ""
    Write-Host "Platforms: claude (default), opencode, copilot"
    Write-Host ""
    Write-Host "  <config-name>  MCP config to use (default: index). Maps to mcp/<name>.json"
    Write-Host "  -Global        Configure globally (~/ paths). Default: configure in current directory."
    Write-Host "  -Env KEY=VALUE Resolve `${env:KEY} placeholders with VALUE (can be repeated)."
    Write-Host "                 Falls back to terminal environment variables."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1')))"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) -Global"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) fvm"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) fvm -Global"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) -Platforms claude,opencode,copilot -Global"
    Write-Host "  & ([scriptblock]::Create((irm '$REPO_RAW/mcp.ps1'))) azure_devops -Env AZURE_DEVOPS_ORG=myorg -Env AZURE_DEVOPS_PAT=mytoken"
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

# Recursively resolves ${env:VAR_NAME} placeholders in all string values.
# -EnvOverrides takes precedence over terminal environment variables.
# Resolved values are written as literals (not as variable references).
function Resolve-EnvPlaceholders {
    param([object]$Obj, [hashtable]$EnvOverrides)

    if ($null -eq $Obj) { return $Obj }

    if ($Obj -is [string]) {
        return [regex]::Replace($Obj, '\$\{env:([^}]+)\}', {
            param([System.Text.RegularExpressions.Match]$match)
            $varName = $match.Groups[1].Value
            if ($EnvOverrides.ContainsKey($varName)) { return $EnvOverrides[$varName] }
            $envVal = [System.Environment]::GetEnvironmentVariable($varName)
            if ($null -ne $envVal) { return $envVal }
            return $match.Value
        })
    }

    if ($Obj -is [PSCustomObject]) {
        $result = [PSCustomObject]@{}
        foreach ($prop in $Obj.PSObject.Properties) {
            $resolved = Resolve-EnvPlaceholders -Obj $prop.Value -EnvOverrides $EnvOverrides
            $result | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $resolved
        }
        return $result
    }

    if ($Obj -is [System.Collections.IEnumerable]) {
        return @($Obj | ForEach-Object { Resolve-EnvPlaceholders -Obj $_ -EnvOverrides $EnvOverrides })
    }

    return $Obj
}

# Merges mcpServers from $SourceFile into the platform-specific key in $DestFile.
# Source files always use "mcpServers" as the key.
# Platform-specific destination keys:
#   claude   -> mcpServers
#   opencode -> mcp
#   copilot  -> servers
function Merge-McpJson {
    param([string]$SourceFile, [string]$DestFile, [string]$Platform, [hashtable]$EnvOverrides = @{})

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

    # Resolve ${env:VAR_NAME} placeholders, then merge into dest's platform key
    $sourceServers = Resolve-EnvPlaceholders -Obj $source.mcpServers -EnvOverrides $EnvOverrides
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

# Parse -Env KEY=VALUE pairs into a hashtable
$envOverrides = @{}
foreach ($envPair in $Env) {
    if ($envPair -match '^([^=]+)=(.*)$') {
        $envOverrides[$Matches[1]] = $Matches[2]
    }
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
    Merge-McpJson -SourceFile $tmpFile -DestFile $destFile -Platform $p -EnvOverrides $envOverrides
    Remove-Item $tmpFile -ErrorAction SilentlyContinue

    Write-Host "$action [$p]: $destFile"
}
