# toast-notify

A Claude Code plugin for Windows that tells you when Claude has finished and is waiting for you.

> **Formerly stop-notify.** If you installed it under the old name, install `toast-notify@rukon-plugins` once and remove stop-notify; see [Renamed: stop-notify is now toast-notify](../../docs/setup-guide.md#renamed-stop-notify-is-now-toast-notify).

When the main session finishes its work and waits for your next input, you get one tray notification with the start of Claude's final message:

- titled **"Claude finished (project)"**, or
- titled **"Claude needs your input (project)"** when that message ends with a question.

You also get a notification titled **"Claude needs permission (project)"** the moment Claude is blocked on a permission prompt, so you do not have to watch the terminal for approvals. Markdown in the message (bold, backticks, links, headings) is removed so the toast reads as plain text.

There is no notification for subagents, for turns that another Stop hook makes Claude continue, or while background work is still running and will wake the session again. Notifications never block the session.

## Install

At the prompt of a Claude Code terminal session:

```
/plugin marketplace add rukon023/claude-code-plugins
/plugin install toast-notify@rukon-plugins
```

Pick a scope when prompted.

## Requirements

- Windows with Windows PowerShell 5.1 (built in). Nothing else to install.

## Notes

- "Ends with a question" means the last paragraph of Claude's message ends with a question mark.
- If you previously added the same hook to `~/.claude/settings.json`, remove it there to avoid getting two notifications.

## License

MIT
