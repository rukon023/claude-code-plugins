# stop-notify

A Claude Code plugin for Windows that tells you when Claude has finished and is waiting for you.

- **Claude finished:** a tray notification titled "Claude finished (project)" with the start of Claude's last message.
- **Claude's last message ends with a question:** the same notification, titled "Claude needs your input (project)".
- **Permission prompts and Claude Code questions:** a tray notification with Claude Code's message.

The notifications never block the session; answer in the terminal as usual.

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
