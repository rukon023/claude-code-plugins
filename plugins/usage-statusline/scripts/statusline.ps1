$raw = [Console]::In.ReadToEnd()
$j = $raw | ConvertFrom-Json
$esc = [char]27
$reset = "$esc[0m"

function Bar($pct) {
  $p = [math]::Max(0, [math]::Min(100, [double]$pct))
  $w = 10
  $filled = [int][math]::Round($p / 100 * $w)
  if ($p -ge 80) { $c = "$esc[31m" } elseif ($p -ge 50) { $c = "$esc[33m" } else { $c = "$esc[32m" }
  $bar = ([string][char]0x2588) * $filled + ([string][char]0x2591) * ($w - $filled)
  return ("{0}{1}{2} {3:N0}%" -f $c, $bar, $reset, $p)
}

$parts = @()
$parts += "$esc[36m$($j.model.display_name)$reset"

$ctx = $j.context_window.used_percentage
if ($null -ne $ctx) { $parts += ("ctx {0:N0}%" -f [double]$ctx) } else { $parts += "ctx 0%" }

$rl = $j.rate_limits
if ($rl) {
  try { $rl | ConvertTo-Json -Depth 5 -Compress | Set-Content -Encoding utf8 "$env:USERPROFILE\.claude\usage-cache.json" } catch {}
}
function ResetAt($win, $fmt) {
  if (-not $win.resets_at) { return "" }
  $t = [DateTimeOffset]::FromUnixTimeSeconds([int64]$win.resets_at).ToLocalTime()
  return " $esc[90m" + [char]0x21BB + " " + $t.ToString($fmt) + $reset
}
if ($rl -and $rl.five_hour) { $parts += "5h " + (Bar $rl.five_hour.used_percentage) + (ResetAt $rl.five_hour 'HH:mm') }
if ($rl -and $rl.seven_day) { $parts += "7d " + (Bar $rl.seven_day.used_percentage) + (ResetAt $rl.seven_day 'ddd HH:mm') }

$dir = $j.workspace.current_dir
if (-not $dir) { $dir = $j.cwd }
if ($dir) {
  $parts += "$esc[34m$dir$reset"
  $branch = & git --no-optional-locks -C $dir symbolic-ref --short HEAD 2>$null
  if (-not $branch) { $branch = & git --no-optional-locks -C $dir rev-parse --short HEAD 2>$null }
  if ($branch) { $parts += "$esc[35m$([char]0x2387) $branch$reset" }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Output ($parts -join " | ")
