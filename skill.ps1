[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$SkillName,
    [string]$Platforms = "claude",
    [switch]$Global
)

$ErrorActionPreference = "Stop"
$REPO_RAW = "https://raw.githubusercontent.com/pretodev/ai-tools/main"

# Returns the destination file path for a skill on a given platform.
# File naming conventions per platform:
#   claude   -> .claude/skills/<name>/SKILL.md   (directory + fixed filename)
#   opencode -> .opencode/commands/<name>.md     (flat file, .md extension)
#   copilot  -> .github/skills/<name>/SKILL.md   (directory + fixed filename)
function Get-SkillDest {
    param([string]$Name, [string]$Platform, [bool]$IsGlobal)

    if ($IsGlobal) {
        switch ($Platform) {
            "claude"   { return (Join-Path $HOME ".claude\skills\$Name\SKILL.md") }
            "opencode" { return (Join-Path $HOME ".config\opencode\commands\$Name.md") }
            "copilot"  { return (Join-Path $HOME ".copilot\skills\$Name\SKILL.md") }
            default {
                Write-Host "Error: unknown platform '$Platform' (supported: claude, opencode, copilot)" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        $cwd = (Get-Location).Path
        switch ($Platform) {
            "claude"   { return (Join-Path $cwd ".claude\skills\$Name\SKILL.md") }
            "opencode" { return (Join-Path $cwd ".opencode\commands\$Name.md") }
            "copilot"  { return (Join-Path $cwd ".github\skills\$Name\SKILL.md") }
            default {
                Write-Host "Error: unknown platform '$Platform' (supported: claude, opencode, copilot)" -ForegroundColor Red
                exit 1
            }
        }
    }
}

if ($SkillName -notmatch '^[a-zA-Z0-9_-]+$') {
    Write-Host "Error: invalid skill name '$SkillName'" -ForegroundColor Red
    exit 1
}

foreach ($platform in ($Platforms -split ',')) {
    $p        = $platform.Trim()
    $destFile = Get-SkillDest -Name $SkillName -Platform $p -IsGlobal $Global.IsPresent
    $sourceUrl = "$REPO_RAW/skills/$SkillName/SKILL.md"
    $action    = if (Test-Path $destFile) { "Updated" } else { "Installed" }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destFile) | Out-Null

    try {
        Invoke-WebRequest -Uri $sourceUrl -OutFile $destFile -UseBasicParsing
    } catch {
        Remove-Item $destFile -ErrorAction SilentlyContinue
        Write-Host "Error: skill '$SkillName' not found at $sourceUrl" -ForegroundColor Red
        exit 1
    }

    Write-Host "$action [$p]: $destFile"
}
