# Stops Claude when the 5h or weekly usage limit is at or above the threshold.
# Reads the usage numbers cached by the usage-statusline plugin's status line.
# Sending a prompt that starts with "ack" acknowledges the warning until that window resets.
#
# Without switches (synchronous PreToolUse / UserPromptSubmit hook): stops this session.
# With -Watch (asyncRewake hook, one per session): watches the shared usage cache and
#   * wakes this session with the warning when usage crosses the threshold, so every open
#     session shows it, not only the one that was working (option notifyAllSessions);
#   * if this session was stopped mid-task, wakes it to resume once the 5-hour window has
#     reset and weekly usage is below resumeWeeklyBelow (option autoResume).
# Plugin options: threshold (default 90), autoResume (default true),
# resumeWeeklyBelow (default 90), notifyAllSessions (default true).
param([switch]$Watch)

function Option([string]$name, $default) {
  $value = [Environment]::GetEnvironmentVariable("CLAUDE_PLUGIN_OPTION_$($name.ToUpper())")
  if ($null -eq $value -or $value -eq '') { return $default }
  if ($default -is [bool]) { return $value -ne 'false' }
  if ($null -ne ($value -as [double])) { return [double]$value }
  return $default
}
$threshold = Option 'threshold' 90.0
$autoResume = Option 'autoResume' $true
$resumeWeeklyBelow = Option 'resumeWeeklyBelow' 90.0
$notifyAll = Option 'notifyAllSessions' $true
$poll = if ($env:USAGE_GUARD_POLL -as [int]) { [int]$env:USAGE_GUARD_POLL } else { 15 }
# Seconds to wait after the 5-hour reset before resuming, so the new window is in effect.
$resumeDelay = if ($null -ne ($env:USAGE_GUARD_RESUME_DELAY -as [int])) { [int]$env:USAGE_GUARD_RESUME_DELAY } else { 60 }

$dir = if ($env:USAGE_GUARD_DIR) { $env:USAGE_GUARD_DIR } else { "$env:USERPROFILE\.claude" }
$cache = "$dir\usage-cache.json"
$ackFile = "$dir\usage-ack.json"

try { $hook = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { $hook = $null }
$session = if ($hook -and $hook.session_id) { $hook.session_id } else { 'default' }
$notifiedFile = "$dir\usage-notified-$session.json"   # windows this session has already shown
$stoppedFile = "$dir\usage-stopped-$session.json"     # set when this session was stopped mid-task
$watchLock = "$dir\usage-watch-$session.json"

$windows = @(
  @{ key = 'five_hour'; label = '5-hour'; span = 5 * 3600 },
  @{ key = 'seven_day'; label = 'weekly'; span = 7 * 86400 }
)

function Now { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
function Read-Json([string]$path) {
  if (-not (Test-Path $path)) { return $null }
  try { return Get-Content -Raw $path | ConvertFrom-Json } catch { return $null }
}
function Write-Json([string]$path, $value) {
  try { $value | ConvertTo-Json -Compress | Set-Content -Encoding utf8 $path } catch {}
}
function Read-Acks {
  $acks = @{}
  $raw = Read-Json $ackFile
  if ($raw) { $raw.PSObject.Properties | ForEach-Object { $acks[$_.Name] = [double]$_.Value } }
  return $acks
}

# Windows at or above the threshold that have not reset and are not acknowledged.
function Get-Hits {
  $rl = Read-Json $cache
  if (-not $rl) { return @() }
  $acks = Read-Acks
  $now = Now
  $hits = @()
  foreach ($w in $windows) {
    $win = $rl.($w.key)
    if (-not $win -or $null -eq $win.used_percentage) { continue }
    if ($win.resets_at -and [double]$win.resets_at -le $now) { continue }
    $pct = [double]$win.used_percentage
    if ($pct -lt $threshold) { continue }
    if ($acks.ContainsKey($w.key) -and $acks[$w.key] -gt $now) { continue }
    $msg = "{0} limit at {1:N0}%" -f $w.label, $pct
    if ($win.resets_at) {
      $msg += " (resets " + [DateTimeOffset]::FromUnixTimeSeconds([int64]$win.resets_at).ToLocalTime().ToString('ddd HH:mm') + ")"
    }
    $hits += @{ w = $w; win = $win; msg = $msg; id = "$($w.key):$($win.resets_at)" }
  }
  return $hits
}

function Warning-Text($hits) {
  $summary = ($hits | ForEach-Object { $_.msg }) -join ', '
  return "USAGE WARNING: $summary. Claude has been stopped. Send 'ack' to acknowledge and continue (you can add instructions after it, e.g. 'ack finish the tests')."
}

# Remember which windows this session has shown, so it is warned once per window.
function Mark-Notified($hits) {
  $seen = @{}
  $raw = Read-Json $notifiedFile
  if ($raw) { $raw.PSObject.Properties | ForEach-Object { $seen[$_.Name] = $_.Value } }
  foreach ($h in $hits) { $seen[$h.id] = Now }
  Write-Json $notifiedFile $seen
}
function Is-Notified($hits) {
  $raw = Read-Json $notifiedFile
  if (-not $raw) { return $false }
  foreach ($h in $hits) { if (-not $raw.PSObject.Properties[$h.id]) { return $false } }
  return $true
}

function Rewake([string]$text) {
  [Console]::Error.WriteLine($text)
  exit 2
}

if ($Watch) {
  # One watcher per session; a newer start while one is alive does nothing.
  $lock = Read-Json $watchLock
  if ($lock -and $lock.pid -ne $PID -and (Get-Process -Id $lock.pid -ErrorAction SilentlyContinue)) { exit 0 }
  Write-Json $watchLock @{ pid = $PID; started = (Now) }

  while ($true) {
    try { $owner = (Read-Json $watchLock).pid } catch { $owner = $null }
    if ($owner -ne $PID) { exit 0 }

    $hits = @(Get-Hits)
    $stopped = Read-Json $stoppedFile

    if ($hits.Count -gt 0 -and $notifyAll -and -not (Is-Notified $hits)) {
      Mark-Notified $hits
      Remove-Item $watchLock -ErrorAction SilentlyContinue
      Rewake ("Usage guard: the usage threshold was reached. Reply to the user with exactly the next line and nothing else, " +
              "and do not call any tools.`nOperation stopped by hook: " + (Warning-Text $hits))
    }

    if ($stopped -and $autoResume) {
      $resetAt = [double]$stopped.resets_at
      $acks = Read-Acks
      if ($acks.ContainsKey('five_hour') -and $acks['five_hour'] -ge $resetAt) {
        Remove-Item $stoppedFile -ErrorAction SilentlyContinue   # the user acknowledged and carried on
      } elseif ((Now) -ge $resetAt + $resumeDelay) {
        $rl = Read-Json $cache
        $weekly = $rl.seven_day
        $weeklyPct = if ($weekly -and $null -ne $weekly.used_percentage -and -not ($weekly.resets_at -and [double]$weekly.resets_at -le (Now))) { [double]$weekly.used_percentage } else { 0 }
        Remove-Item $stoppedFile -ErrorAction SilentlyContinue
        if ($weeklyPct -lt $resumeWeeklyBelow) {
          Remove-Item $watchLock -ErrorAction SilentlyContinue
          Rewake ("The 5-hour usage limit has reset and weekly usage is at {0:N0}%. Resume the task that was stopped by the usage warning, continuing from where you left off." -f $weeklyPct)
        }
      }
    }
    Start-Sleep -Seconds $poll
  }
}

# Synchronous guard
$hits = @(Get-Hits)
if ($hits.Count -eq 0) { exit 0 }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$summary = ($hits | ForEach-Object { $_.msg }) -join ', '

# Acknowledgement: a prompt starting with "ack" records the ack and lets the prompt through
if ($hook -and $hook.hook_event_name -eq 'UserPromptSubmit' -and $hook.prompt -match '^\s*ack\b') {
  $acks = Read-Acks
  $now = Now
  foreach ($h in $hits) {
    $acks[$h.w.key] = if ($h.win.resets_at) { [double]$h.win.resets_at } else { $now + $h.w.span }
  }
  Write-Json $ackFile $acks
  Remove-Item $stoppedFile -ErrorAction SilentlyContinue
  @{
    systemMessage = "Usage warning acknowledged ($summary). Claude will continue until the window resets."
    hookSpecificOutput = @{
      hookEventName = 'UserPromptSubmit'
      additionalContext = "The user acknowledged a usage-limit warning ($summary) and chose to continue. If the prompt is only 'ack', resume the task that was interrupted."
    }
  } | ConvertTo-Json -Compress -Depth 4
  exit 0
}

# Stop this session. It already shows the warning, so its watcher will not repeat it, and
# when only the 5-hour window is the cause, the watcher can resume it after the reset.
Mark-Notified $hits
$five = $hits | Where-Object { $_.w.key -eq 'five_hour' } | Select-Object -First 1
if ($five -and $five.win.resets_at) { Write-Json $stoppedFile @{ resets_at = [double]$five.win.resets_at } }
$text = Warning-Text $hits
@{ continue = $false; stopReason = $text; systemMessage = $text } | ConvertTo-Json -Compress
exit 0
