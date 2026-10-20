# Claude Code Stop / Notification hook.
# - Stop: shows the last assistant message. If it ends with a question, opens a modal
#   where you can answer directly (the answer is fed back to Claude). Otherwise a
#   non-blocking tray notification is shown.
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

# A "simple input" is needed when the final paragraph of the message asks a question
$paragraphs = @($last.Trim() -split '(\r?\n){2,}' | Where-Object { $_.Trim() })
$tail = if ($paragraphs.Count) { $paragraphs[-1] } else { $last }
$isQuestion = $tail -match '\?\s*(\*|_|`)*\s*$' -or $tail -match '\?\s*\r?\n'
$isYesNo = $isQuestion -and $tail -match '(?i)\b(should i|shall i|do you want|would you like|want me to|ok to|okay to|proceed|go ahead|confirm|is that ok|sound good)\b'

if (-not $isQuestion) {
    Start-DetachedBalloon "Claude finished ($project)" (Get-Short $last 200)
    exit 0
}

# Modal with quick reply
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude needs your input ($project)"
$form.Size = New-Object System.Drawing.Size(620, 440)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.MinimizeBox = $false
$form.FormBorderStyle = 'Sizable'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

$msgBox = New-Object System.Windows.Forms.TextBox
$msgBox.Multiline = $true
$msgBox.ReadOnly = $true
$msgBox.ScrollBars = 'Vertical'
$msgBox.Text = ($last -replace '\r?\n', "`r`n")
$msgBox.Location = New-Object System.Drawing.Point(12, 12)
$msgBox.Size = New-Object System.Drawing.Size(580, 250)
$msgBox.Anchor = 'Top,Left,Right,Bottom'
$form.Controls.Add($msgBox)

$label = New-Object System.Windows.Forms.Label
$label.Text = 'Your reply (Enter to send, Esc to reply in the terminal instead):'
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(12, 270)
$label.Anchor = 'Left,Bottom'
$form.Controls.Add($label)

$replyBox = New-Object System.Windows.Forms.TextBox
$replyBox.Location = New-Object System.Drawing.Point(12, 292)
$replyBox.Size = New-Object System.Drawing.Size(580, 26)
$replyBox.Anchor = 'Left,Right,Bottom'
$form.Controls.Add($replyBox)

$script:reply = $null
function Add-Button([string]$text, [int]$x, [scriptblock]$onClick) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, 335)
    $btn.Size = New-Object System.Drawing.Size(110, 32)
    $btn.Anchor = 'Right,Bottom'
    $btn.Add_Click($onClick)
    $form.Controls.Add($btn)
    return $btn
}

$x = 482
$send = Add-Button 'Send' $x { if ($replyBox.Text.Trim()) { $script:reply = $replyBox.Text.Trim(); $form.Close() } }
$x -= 120
$dismiss = Add-Button 'Dismiss' $x { $form.Close() }
if ($isYesNo) {
    $x -= 120
    Add-Button 'No' $x { $script:reply = 'No'; $form.Close() } | Out-Null
    $x -= 120
    Add-Button 'Yes' $x { $script:reply = 'Yes'; $form.Close() } | Out-Null
}
$form.AcceptButton = $send
$form.CancelButton = $dismiss

# Auto-dismiss after 10 minutes so the session is never stuck behind the modal
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 600000
$timer.Add_Tick({ $timer.Stop(); $form.Close() })
$timer.Start()

$form.Add_Shown({ $form.Activate(); $replyBox.Focus() })
[System.Media.SystemSounds]::Asterisk.Play()
[void]$form.ShowDialog()
$timer.Dispose()

if ($script:reply) {
    $out = @{ decision = 'block'; reason = "The user replied via the desktop notification: $($script:reply)" } | ConvertTo-Json -Compress
    [Console]::Out.Write($out)
}
exit 0
