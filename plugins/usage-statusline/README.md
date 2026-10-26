# usage-statusline

A Claude Code status line for Windows:

```
Opus | ctx 42% | 5h ███░░░░░░░ 31% ↻ 2:00 PM | 7d █░░░░░░░░░ 12% ↻ Mon 9:00 AM | wk ├━━┼━━┼●─┼──┼──┼──┼──┤ 29%
C:\code\app | ⎇ main
```

- the model
- how much of the context window is used
- 5-hour and 7-day rate limit usage as bars (green, yellow from 50%, red from 80%) with the local time each one resets
- a weekly timeline (`wk`) showing how far you are through the 7-day window: each `┼` is a day boundary counted from the window start (the reset time minus 7 days), `━` is elapsed time and `●` is now
- the current folder and git branch, on a second line

Rate limit bars appear only on a Claude subscription, once Claude Code has rate limit figures for the session.

## Install

At the prompt of a Claude Code terminal session:

```
/plugin install usage-statusline --marketplace rukon023/claude-code-plugins
```

Answer `y` to add the marketplace, then pick a scope. The status line turns on at the next start of Claude Code if you have no other status line configured.

If you already have a status line, replace it with this one by running:

```
/usage-statusline:setup
```

## How it works

At each start, the plugin copies its script to its data folder (`~/.claude/plugins/data/usage-statusline-<marketplace>/`), a path that stays the same across plugin updates, and `statusLine` in `~/.claude/settings.json` points there. Before changing `settings.json` it saves a copy as `settings.json.bak`.

The script also saves the latest rate limit figures to `~/.claude/usage-cache.json`, so other hooks can read them.

## Uninstall

Uninstalling the plugin does not remove the `statusLine` entry from `~/.claude/settings.json`; delete it there (or run `/statusline` to set a different one).

## License

MIT
