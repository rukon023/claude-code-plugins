# stop-notify

A Claude Code plugin for Windows that tells you when Claude has finished and is waiting for you.

- **Claude finished, no question:** a tray notification with the start of Claude's last message.
- **Claude's last message ends with a question:** an always-on-top modal showing the full message with a reply box. Press **Enter** to send your answer straight back to Claude, which continues as if you had typed it in the terminal. Yes/No questions ("Should I...", "Do you want...", "proceed?") also get **Yes** and **No** buttons. **Esc** dismisses the modal so you can answer in the terminal instead; it also closes itself after 10 minutes.
- **Permission prompts and Claude Code questions:** a tray notification (answer those in the terminal).

## Install

At the prompt of a Claude Code terminal session:

```
/plugin install stop-notify --marketplace rukon023/claude-stop-notify
```

Answer `y` to add the marketplace, then pick a scope.

## Requirements

- Windows with Windows PowerShell 5.1 (built in). Nothing else to install.

## Notes

- "Ends with a question" means the last paragraph of Claude's message ends with a question mark. Questions phrased without one get a plain notification.
- While the modal is open the session counts as busy, so dismiss it before typing in the terminal.
- If you previously added the same hook to `~/.claude/settings.json`, remove it there to avoid getting two notifications.

## License

MIT
