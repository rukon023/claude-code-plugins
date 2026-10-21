# Stops Claude when the 5h or weekly usage limit is at or above the threshold.
# Reads the usage numbers cached by the usage-statusline plugin's status line.
# Sending a prompt that starts with "ack" acknowledges the warning until that window resets.
# With -WaitForReset (run as an asyncRewake hook), it waits while the 5-hour limit is what
# stops Claude, and wakes the session when that window resets.
# Plugin options: threshold (percent, default 90) and autoResume (default true).
param([switch]$WaitForReset)
$threshold = 90
if ($env:CLAUDE_PLUGIN_OPTION_THRESHOLD -as [double]) { $threshold = [double]$env:CLAUDE_PLUGIN_OPTION_THRESHOLD }
if ($WaitForReset -and $env:CLAUDE_PLUGIN_OPTION_AUTORESUME -eq 'false') { exit 0 }
$dir = if ($env:USAGE_GUARD_DIR) { $env:USAGE_GUARD_DIR } else { "$env:USERPROFILE\.claude" }
$cache = "$dir\usage-cache.json"
$ackFile = "$dir\usage-ack.json"

try { $hook = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { $hook = $null }
if (-not (Test-Path $cache)) { exit 0 }
try { $rl = Get-Content -Raw $cache | ConvertFrom-Json } catch { exit 0 }

$acks = @{}
if (Test-Path $ackFile) {
  try { (Get-Content -Raw $ackFile | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $acks[$_.Name] = [double]$_.Value } } catch {}
}

$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$windows = @(
  @{ key = 'five_hour'; label = '5-hour'; span = 5 * 3600 },
  @{ key = 'seven_day'; label = 'weekly'; span = 7 * 86400 }
)
$hits = @()
foreach ($w in $windows) {
  $win = $rl.($w.key)
  if (-not $win -or $null -eq $win.used_percentage) { continue }
  # Skip windows that have already reset since the cache was written
  if ($win.resets_at -and [double]$win.resets_at -le $now) { continue }
  $pct = [double]$win.used_percentage
  if ($pct -lt $threshold) { continue }
  # Skip windows the user already acknowledged (ack lasts until that window resets)
  if ($acks.ContainsKey($w.key) -and $acks[$w.key] -gt $now) { continue }
  $msg = "{0} limit at {1:N0}%" -f $w.label, $pct
  if ($win.resets_at) {
    $msg += " (resets " + [DateTimeOffset]::FromUnixTimeSeconds([int64]$win.resets_at).ToLocalTime().ToString('ddd HH:mm') + ")"
  }
  $hits += @{ w = $w; win = $win; msg = $msg }
}
if ($hits.Count -eq 0) { exit 0 }

if ($WaitForReset) {
  # Only the 5-hour window: if the weekly limit is also stopping Claude, a reset would not help
  $five = $hits | Where-Object { $_.w.key -eq 'five_hour' } | Select-Object -First 1
  if (-not $five -or ($hits | Where-Object { $_.w.key -eq 'seven_day' }) -or -not $five.win.resets_at) { exit 0 }
  $resetAt = [int64]$five.win.resets_at

  # One waiter per session: later tool calls and prompts while stopped do nothing
  $session = if ($hook -and $hook.session_id) { $hook.session_id } else { 'default' }
  $lockFile = "$dir\usage-resume-$session.json"
  if (Test-Path $lockFile) {
    try { $lock = Get-Content -Raw $lockFile | ConvertFrom-Json } catch { $lock = $null }
    if ($lock -and $lock.resets_at -eq $resetAt -and (Get-Process -Id $lock.pid -ErrorAction SilentlyContinue)) { exit 0 }
  }
  @{ pid = $PID; resets_at = $resetAt } | ConvertTo-Json -Compress | Set-Content -Encoding utf8 $lockFile

  # Wait for the reset (plus a minute of slack); stop waiting if the user acked or another waiter took over
  while ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $resetAt + 60) {
    Start-Sleep -Seconds 10
    try { $owner = (Get-Content -Raw $lockFile | ConvertFrom-Json).pid } catch { $owner = $null }
    if ($owner -ne $PID) { exit 0 }
    if (Test-Path $ackFile) {
      try { $ack = (Get-Content -Raw $ackFile | ConvertFrom-Json).five_hour } catch { $ack = $null }
      if ($ack -and [double]$ack -ge $resetAt) { Remove-Item $lockFile -ErrorAction SilentlyContinue; exit 0 }
    }
  }
  Remove-Item $lockFile -ErrorAction SilentlyContinue
  [Console]::Error.WriteLine("The 5-hour usage limit has reset. Resume the task that was stopped by the usage warning, continuing from where you left off.")
  exit 2
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$summary = ($hits | ForEach-Object { $_.msg }) -join ', '

# Acknowledgement: a prompt starting with "ack" records the ack and lets the prompt through
if ($hook -and $hook.hook_event_name -eq 'UserPromptSubmit' -and $hook.prompt -match '^\s*ack\b') {
  foreach ($h in $hits) {
    $until = if ($h.win.resets_at) { [double]$h.win.resets_at } else { $now + $h.w.span }
    $acks[$h.w.key] = $until
  }
  try { $acks | ConvertTo-Json -Compress | Set-Content -Encoding utf8 $ackFile } catch {}
  @{
    systemMessage = "Usage warning acknowledged ($summary). Claude will continue until the window resets."
    hookSpecificOutput = @{
      hookEventName = 'UserPromptSubmit'
      additionalContext = "The user acknowledged a usage-limit warning ($summary) and chose to continue. If the prompt is only 'ack', resume the task that was interrupted."
    }
  } | ConvertTo-Json -Compress -Depth 4
  exit 0
}

$text = "USAGE WARNING: $summary. Claude has been stopped. Send 'ack' to acknowledge and continue (you can add instructions after it, e.g. 'ack finish the tests')."
@{ continue = $false; stopReason = $text; systemMessage = $text } | ConvertTo-Json -Compress
exit 0
