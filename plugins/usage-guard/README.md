# usage-guard

Stops Claude before it uses up your Claude subscription's usage limits, and picks the work back up when the 5-hour window resets.

- When the 5-hour or weekly usage reaches the threshold (90% by default), Claude is stopped before its next tool call or prompt, with a message such as `USAGE WARNING: 5-hour limit at 92% (resets Tue 14:00)`.
- **Keep going anyway:** send a prompt that starts with `ack` (for example `ack finish the tests`). The warning stays quiet until that window resets.
- **Wait for the reset:** if the 5-hour limit stopped Claude, leave the session open. About a minute after the window resets, Claude resumes the task on its own. It does not resume when the weekly limit is also over the threshold.

## Install

At the prompt of a Claude Code terminal session:

```
/plugin install usage-guard --marketplace rukon023/claude-code-plugins
```

Answer `y` to add the marketplace, then pick a scope.

## Requirements

- Windows with Windows PowerShell 5.1 (built in).
- The [usage-statusline](../usage-statusline) plugin as your status line. The guard reads the usage figures it saves to `~/.claude/usage-cache.json`, and does nothing without them.

## Options

Set these in the plugin's settings in the `/plugin` menu:

| Option | Default | What it does |
| --- | --- | --- |
| Stop at (%) | 90 | The usage percentage at which Claude is stopped |
| Resume after the 5-hour reset | on | Resume the task automatically once the 5-hour window resets |

## Notes

- Claude Code has to stay open while it waits for the reset. If you close it, nothing resumes.
- If Claude hits the real usage limit rather than this threshold, Claude Code's built-in `autoContinueAtUsageLimit` setting handles resuming.
- Acknowledgements are kept in `~/.claude/usage-ack.json`.

## License

MIT
