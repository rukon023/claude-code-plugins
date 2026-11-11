# Copies statusline.ps1 to the plugin's data folder (a path that stays the same across
# plugin updates) and points ~/.claude/settings.json "statusLine" at it.
# Without -Force, an existing status line that is not this plugin's is left alone.
param([switch]$Force)

$dataDir = $env:CLAUDE_PLUGIN_DATA
if (-not $dataDir) {
    # Run outside a hook: the plugin lives at cache/<marketplace>/<plugin>/<version>/scripts
    $pluginDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $marketplace = Split-Path (Split-Path $pluginDir -Parent) -Leaf
    $dataDir = Join-Path $HOME ".claude\plugins\data\usage-statusline-$marketplace"
}
New-Item -ItemType Directory -Force $dataDir | Out-Null
$target = Join-Path $dataDir 'statusline.ps1'
Copy-Item (Join-Path $PSScriptRoot 'statusline.ps1') $target -Force

$command = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + ($target -replace '\\', '/') + '"'
$settingsPath = Join-Path $HOME '.claude\settings.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$text = if (Test-Path $settingsPath) { [IO.File]::ReadAllText($settingsPath) } else { '' }
$settings = $null
if ($text.Trim()) {
    try { $settings = $text | ConvertFrom-Json } catch {
        Write-Output "settings.json is not plain JSON (comments or a syntax error?), so it was left alone. Add this to it by hand: `"statusLine`": { `"type`": `"command`", `"command`": $($command | ConvertTo-Json) }"
        exit 0
    }
}

$current = if ($settings) { $settings.statusLine } else { $null }
if ($current -and $current.command -eq $command) { exit 0 }
if ($current -and -not $Force -and $current.command -notlike '*usage-statusline*') {
    if ($env:CLAUDE_PLUGIN_DATA) { exit 0 }
    Write-Output "Another status line is configured: $($current.command). Run again with -Force to replace it."
    exit 0
}

# Change only the statusLine entry as text, so the rest of settings.json keeps its
# formatting, order and characters exactly as they are.
$nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
$entry = '{ "type": "command", "command": ' + ($command | ConvertTo-Json) + ' }'
if (-not $text.Trim() -or ($settings -and @($settings.PSObject.Properties).Count -eq 0)) {
    $new = "{$nl  `"statusLine`": $entry$nl}$nl"
} elseif ($current) {
    $pattern = '("statusLine"\s*:\s*)\{(?:[^{}"]|"(?:[^"\\]|\\.)*")*\}'
    $new = [regex]::Replace($text, $pattern, { param($m) $m.Groups[1].Value + $entry }, 'None')
} else {
    $comma = if (@($settings.PSObject.Properties).Count -gt 0) { ',' } else { '' }
    $new = [regex]::Replace($text, '^\s*\{', { param($m) "{$nl  `"statusLine`": $entry$comma" }, 'None')
}

# Check the edit before writing it: valid JSON, new status line in place, everything else unchanged.
function Other-Settings($obj) { ($obj | Select-Object -Property * -ExcludeProperty statusLine | ConvertTo-Json -Depth 100 -Compress) }
try {
    $check = $new | ConvertFrom-Json
    $ok = ($check.statusLine.command -eq $command) -and ((Other-Settings $check) -eq (Other-Settings $(if ($settings) { $settings } else { New-Object PSObject })))
} catch { $ok = $false }
if (-not $ok) {
    Write-Output "Could not update settings.json safely, so it was left alone. Set `"statusLine`" by hand to: $entry"
    exit 0
}

if ($text) {
    $backup = "$settingsPath.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $settingsPath $backup -Force
    # keep the five most recent backups
    Get-ChildItem "$settingsPath.bak-*" | Sort-Object Name -Descending | Select-Object -Skip 5 | Remove-Item -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force (Split-Path $settingsPath -Parent) | Out-Null
[IO.File]::WriteAllText($settingsPath, $new, $utf8)
$saved = if ($text) { " (previous settings saved to $(Split-Path $backup -Leaf))" } else { '' }
Write-Output "Status line set to: $command$saved"
