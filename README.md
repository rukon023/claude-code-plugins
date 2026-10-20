# stop-notify

A Claude Code plugin for Windows that tells you when Claude has finished and is waiting for you.

When the main session finishes its work and waits for your next input, you get one tray notification with the start of Claude's final message:

- titled **"Claude finished (project)"**, or
- titled **"Claude needs your input (project)"** when that message ends with a question.

There is no notification for subagents, for turns that another Stop hook makes Claude continue, or while background work is still running and will wake the session again. Notifications never block the session.

## Install

At the prompt of a Claude Code terminal session:

```
/plugin install stop-notify --marketplace rukon023/claude-stop-notify
```

Answer `y` to add the marketplace, then pick a scope.

## Requirements

- Windows with Windows PowerShell 5.1 (built in). Nothing else to install.

## Notes

- "Ends with a question" means the last paragraph of Claude's message ends with a question mark.
- If you previously added the same hook to `~/.claude/settings.json`, remove it there to avoid getting two notifications.

## License

MIT
