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
$settings = if (Test-Path $settingsPath) { Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { New-Object PSObject }

$current = $settings.statusLine
if ($current -and $current.command -eq $command) { exit 0 }
if ($current -and -not $Force -and $current.command -notlike '*usage-statusline*') {
    if ($env:CLAUDE_PLUGIN_DATA) { exit 0 }
    Write-Output "Another status line is configured: $($current.command). Run again with -Force to replace it."
    exit 0
}

Copy-Item $settingsPath "$settingsPath.bak" -Force -ErrorAction SilentlyContinue
$value = [PSCustomObject]@{ type = 'command'; command = $command }
$settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $value -Force
$json = $settings | ConvertTo-Json -Depth 100
[IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Status line set to: $command (previous settings saved to settings.json.bak)"
