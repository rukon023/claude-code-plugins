# Claude Code Stop / Notification hook.
# - Stop: shows a tray notification with the start of the last assistant message,
#   titled differently when that message ends with a question.
# - Notification: shows a tray notification with Claude Code's message.
param(
    [string]$ToastTitle,
    [string]$ToastText
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-Balloon([string]$title, [string]$text) {
    $icon = New-Object System.Windows.Forms.NotifyIcon
    $icon.Icon = [System.Drawing.SystemIcons]::Information
    $icon.BalloonTipTitle = $title
    $icon.BalloonTipText = $text
    $icon.Visible = $true
    $icon.ShowBalloonTip(8000)
    Start-Sleep -Seconds 9
    $icon.Dispose()
}

function Start-DetachedBalloon([string]$title, [string]$text) {
    $t = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($title))
    $b = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text))
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"",
        '-ToastTitle', $t, '-ToastText', $b
    ) | Out-Null
}

function Get-Short([string]$text, [int]$max) {
    $flat = ($text -replace '\s+', ' ').Trim()
    if ($flat.Length -le $max) { return $flat }
    return $flat.Substring(0, $max - 3) + '...'
}

# Detached balloon mode (spawned by this script so the hook returns immediately)
if ($ToastTitle) {
    $title = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ToastTitle))
    $text = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ToastText))
    Show-Balloon $title $text
    exit 0
}

[Console]::InputEncoding = [Text.Encoding]::UTF8
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$raw = [Console]::In.ReadToEnd()
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

$project = if ($payload.cwd) { Split-Path $payload.cwd -Leaf } else { 'Claude Code' }

if ($payload.hook_event_name -eq 'Notification') {
    Start-DetachedBalloon "Claude Code ($project)" (Get-Short ([string]$payload.message) 200)
    exit 0
}

# Stop event: find the last assistant message
$last = [string]$payload.last_assistant_message
if (-not $last -and $payload.transcript_path -and (Test-Path $payload.transcript_path)) {
    $lines = Get-Content $payload.transcript_path -Encoding UTF8 -Tail 200
    for ($i = $lines.Count - 1; $i -ge 0 -and -not $last; $i--) {
        try { $entry = $lines[$i] | ConvertFrom-Json } catch { continue }
        if ($entry.type -ne 'assistant') { continue }
        $texts = @($entry.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text })
        if ($texts.Count -gt 0) { $last = ($texts -join "`n").Trim() }
    }
}
if (-not $last) { $last = 'Claude has finished and is waiting for your input.' }

# Flag the notification when the final paragraph of the message asks a question
$paragraphs = @($last.Trim() -split '(\r?\n){2,}' | Where-Object { $_.Trim() })
$lastParagraph = if ($paragraphs.Count) { $paragraphs[-1] } else { $last }
$isQuestion = $lastParagraph -match '\?\s*(\*|_|`)*\s*$' -or $lastParagraph -match '\?\s*\r?\n'

$title = if ($isQuestion) { "Claude needs your input ($project)" } else { "Claude finished ($project)" }
Start-DetachedBalloon $title (Get-Short $last 200)
exit 0
