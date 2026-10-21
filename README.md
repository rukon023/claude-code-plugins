# rukon-plugins

Claude Code plugins for Windows. Each one needs only the built-in Windows PowerShell 5.1.

| Plugin | What it does |
| --- | --- |
| [stop-notify](plugins/stop-notify) | A Windows notification with Claude's final message when the main session finishes and waits for you |
| [usage-statusline](plugins/usage-statusline) | A status line with the model, context usage, 5-hour and 7-day rate limit bars with reset times, the folder and the git branch |
| [usage-guard](plugins/usage-guard) | Stops Claude when the 5-hour or weekly usage reaches a threshold (90% by default), warns every open session, and resumes stopped work when the 5-hour window resets and weekly usage allows. Needs usage-statusline |

## Install

At the prompt of a Claude Code terminal session, install whichever you want:

```
/plugin install stop-notify --marketplace rukon023/claude-code-plugins
/plugin install usage-statusline --marketplace rukon023/claude-code-plugins
/plugin install usage-guard --marketplace rukon023/claude-code-plugins
```

Answer `y` to add the marketplace the first time, then pick a scope.

## License

MIT
