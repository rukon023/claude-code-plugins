# Claude Code Stop hook.
# Shows a tray notification with the start of the main session's final message once
# Claude has finished and is waiting for the user, titled differently when that
# message ends with a question.
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

# Plain-text version of a markdown message, so toasts do not show **, backticks or links.
function Remove-Markdown([string]$text) {
    $t = $text -replace '(?s)```.*?```', ' [code] '          # fenced code blocks
    $t = $t -replace '!?\[([^\]]*)\]\([^)]*\)', '$1'          # [label](url) and ![alt](url)
    $t = $t -replace '(?m)^\s{0,3}#{1,6}\s*', ''              # headings
    $t = $t -replace '(?m)^\s*(?:[-*+]|\d+\.)\s+', ''         # list markers
    $t = $t -replace '\*\*|`', ''                             # bold and inline code
    return $t
}

function Get-Short([string]$text, [int]$max) {
    $flat = ((Remove-Markdown $text) -replace '\s+', ' ').Trim()
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

# Claude is blocked on a permission prompt (or a question from a tool): tell the user
# right away, because the Stop event does not fire until the whole turn is over.
if ($payload.hook_event_name -eq 'Notification') {
    # idle_prompt and the rest would only repeat the "finished" toast
    if ($payload.notification_type -notin 'permission_prompt', 'elicitation_dialog') { exit 0 }
    $message = [string]$payload.message
    if (-not $message) { $message = 'Claude is waiting for your approval.' }
    $title = if ($payload.notification_type -eq 'permission_prompt') { "Claude needs permission ($project)" } else { "Claude needs your input ($project)" }
    Start-DetachedBalloon $title (Get-Short $message 200)
    exit 0
}

# Only notify when the main session is really done and waiting for the user:
# not for subagents, not when another Stop hook made Claude continue, and not
# while background work is still running and will wake the session again.
if ($payload.hook_event_name -ne 'Stop') { exit 0 }
if ($payload.agent_id) { exit 0 }
if ($payload.stop_hook_active) { exit 0 }
if (@($payload.background_tasks).Where({ $_ }).Count -gt 0) { exit 0 }

# Find the last assistant message
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
$paragraphs = @($last.Trim() -split '(?:\r?\n){2,}' | Where-Object { $_.Trim() })
$lastParagraph = if ($paragraphs.Count) { $paragraphs[-1] } else { $last }
$isQuestion = $lastParagraph -match '\?\s*(\*|_|`)*\s*$' -or $lastParagraph -match '\?\s*\r?\n'

$title = if ($isQuestion) { "Claude needs your input ($project)" } else { "Claude finished ($project)" }
Start-DetachedBalloon $title (Get-Short $last 200)
exit 0
