# Setup guide

How to install the rukon-plugins marketplace, check that each plugin works, and fix the usual problems. The three plugins are independent except that **usage-guard needs usage-statusline**.

| Plugin | Install it if you want | Needs |
| --- | --- | --- |
| [usage-statusline](../plugins/usage-statusline) | Model, context, 5-hour and 7-day usage bars and the weekly timeline in the status line | A Claude subscription (Pro or Max) for the usage bars |
| [usage-guard](../plugins/usage-guard) | Claude stopped before it uses up the 5-hour or weekly limit, and resumed after the reset | usage-statusline, and a Claude subscription |
| [stop-notify](../plugins/stop-notify) | A Windows notification when Claude finishes, asks a question or waits for permission | Nothing else |

## Before you start

- Windows 10 or 11. The plugins use Windows PowerShell 5.1, which is built in, so there is nothing to install. (`pwsh` is not required.)
- A recent version of Claude Code. Run `claude --version` to check, and `claude update` if it is old.
- For usage-statusline and usage-guard: sign in with a Claude subscription. API-key sessions have no rate limit figures, so the usage bars never appear and the guard has nothing to read.

## 1. Add the marketplace

At the prompt of a Claude Code session:

```
/plugin marketplace add rukon023/claude-code-plugins
```

## 2. Install the plugins

Install usage-statusline before usage-guard:

```
/plugin install usage-statusline@rukon-plugins
/plugin install usage-guard@rukon-plugins
/plugin install stop-notify@rukon-plugins
```

You are asked for a scope each time:

- **User** (recommended): the plugin works in every project on this machine. This is what you want for usage-guard, because it only warns sessions where it is installed.
- **Project**: saved in the project's `.claude/settings.json`, so everyone who uses that repository gets it.
- **Local**: this project only, and not shared.

The same steps work from a normal terminal with `claude plugin marketplace add rukon023/claude-code-plugins` and `claude plugin install <name>@rukon-plugins`.

## 3. Restart Claude Code

Close Claude Code and start it again. The status line turns on at this start. usage-guard has a few options (see [usage-guard options](#usage-guard-options)); the defaults are fine to start with.

## 4. Check that each plugin works

### usage-statusline

You should see two lines under the prompt, for example:

```
Opus | ctx 42% | 5h ███░░░░░░░ 31% ↻ 2:00 PM | 7d █░░░░░░░░░ 12% ↻ Mon 9:00 AM | wk ├━━┼━━┼●─┼──┼──┼──┼──┤ 29%
C:\code\app | ⎇ main
```

- The 5h and 7d bars appear after your first message in a session. Until then only the model, context and folder show.
- Confirm the figures are being saved: `~/.claude/usage-cache.json` (that is `C:\Users\<you>\.claude\usage-cache.json`) should exist and change as you work. usage-guard reads this file.
- If you do not see the status line, you already had another one. Run `/usage-statusline:setup` to replace it.

### usage-guard

A quick test that does not wait for real usage:

1. Open the plugin's settings in the `/plugin` menu and set **Stop at (%)** to `1`.
2. Send any prompt. Claude should stop with `USAGE WARNING: 5-hour limit at NN% ...`.
3. Send `ack` (or `ack continue what you were doing`). Claude carries on, and the warning stays quiet until that window resets.
4. Set **Stop at (%)** back to `90`.

If nothing happens in step 2, see [Troubleshooting](#troubleshooting).

### stop-notify

1. Ask Claude something short and wait. A notification titled **Claude finished (project)** should appear. If Claude's last paragraph ends with a question, it is titled **Claude needs your input (project)**.
2. Ask for something that needs approval, such as running a command you have not allowed. A notification titled **Claude needs permission (project)** appears as soon as the prompt shows.

## usage-guard options

Open the plugin's settings in the `/plugin` menu, or run `claude plugin configure usage-guard` from a terminal to see which options are set.

| Option | Default | What it does |
| --- | --- | --- |
| Stop at (%) | 90 | Claude is stopped when the 5-hour or weekly usage reaches this |
| Resume after the 5-hour reset | on | Resumes a task the 5-hour limit stopped, about a minute after the window resets |
| Resume only if weekly is below (%) | 90 | After the reset, resume only when weekly usage is under this |
| Warn every open session | on | Shows the warning in every open session, not only the one that was working |

How it behaves day to day:

- **Keep going anyway:** start a prompt with `ack`. It applies to every session until that window resets.
- **Waiting for the reset:** leave the session open. Claude Code has to stay running for it to resume on its own.
- **Idle sessions:** each open session gets one short turn to show the warning, so it uses a small amount of usage in each.

## Use another status line

usage-statusline will not replace a status line you already have unless you ask. Run `/usage-statusline:setup` to replace yours. The plugin edits only the `statusLine` entry in `~/.claude/settings.json` and keeps the five most recent backups next to it as `settings.json.bak-<date>-<time>`.

## Update

Update the plugins from the `/plugin` menu, then restart Claude Code. The status line script is copied to the plugin's data folder at each start, so it picks up new versions on its own.

## Uninstall

1. Remove the plugins from the `/plugin` menu (or `claude plugin uninstall <name>`).
2. Remove the `statusLine` entry from `~/.claude/settings.json`, or run `/statusline` to set a different one. Uninstalling does not remove it.
3. Optional clean-up in `~/.claude`: `usage-cache.json`, `usage-ack.json`, `usage-watch-*.json`, `usage-notified-*.json`, `usage-stopped-*.json`, and the folder `plugins/data/usage-statusline-*`.

## Troubleshooting

| Problem | Cause and fix |
| --- | --- |
| The usage bars never show | You are not on a subscription, or the session has not got figures yet. Send a message and wait a moment. |
| usage-guard never stops Claude | It reads `~/.claude/usage-cache.json`. If that file is missing or not updating, the status line is not usage-statusline (run `/usage-statusline:setup`) or you are not on a subscription. |
| Two notifications every time | The same hook is also in `~/.claude/settings.json`. Remove it there. |
| No notification appears | Check that Windows notifications are on, and that Do not disturb or Focus assist is not hiding them. |
| `/usage-statusline:setup` says `settings.json` is not plain JSON | The file has comments or a syntax error. Fix it, or add the `statusLine` entry that the command prints by hand. |
| A PowerShell execution policy error | The hooks already run with `-ExecutionPolicy Bypass`. If your organization enforces a policy through Group Policy, it can still block them; ask your administrator. |
| usage-guard did not resume after the reset | Claude Code was closed, or weekly usage was at or above *Resume only if weekly is below*. |
| Your config is not in `~/.claude` | The plugins read and write `%USERPROFILE%\.claude`. A custom `CLAUDE_CONFIG_DIR` is not supported yet. |

Found a problem that is not here? Open an issue at <https://github.com/rukon023/claude-code-plugins/issues>.
