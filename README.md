# rukon-plugins

Claude Code plugins for Windows. Each one needs only the built-in Windows PowerShell 5.1.

| Plugin | What it does |
| --- | --- |
| [toast-notify](plugins/toast-notify) | Windows notifications when Claude finishes, asks a question or waits for permission (formerly stop-notify) |
| [usage-statusline](plugins/usage-statusline) | A status line with the model, context usage, 5-hour and 7-day rate limit bars with reset times, the folder and the git branch |
| [usage-guard](plugins/usage-guard) | Stops Claude when the 5-hour or weekly usage reaches a threshold (90% by default), warns every open session, and resumes stopped work when the 5-hour window resets and weekly usage allows. Needs usage-statusline |

## Install

At the prompt of a Claude Code terminal session, add the marketplace once, then install whichever you want:

```
/plugin marketplace add rukon023/claude-code-plugins
/plugin install usage-statusline@rukon-plugins
/plugin install usage-guard@rukon-plugins
/plugin install toast-notify@rukon-plugins
```

Pick a scope when prompted (user scope applies to every project), then restart Claude Code. Install usage-statusline before usage-guard, because the guard reads the figures the status line saves. From a regular terminal, the same works with `claude plugin marketplace add` and `claude plugin install`.

The **[setup guide](docs/setup-guide.md)** walks through installing, checking that each plugin works, the usage-guard options, updating, uninstalling and troubleshooting.

## Update

Refresh the marketplace, update the plugins, then restart Claude Code (an update only applies after a restart):

```
claude plugin marketplace update rukon-plugins
claude plugin update usage-statusline@rukon-plugins
claude plugin update usage-guard@rukon-plugins
claude plugin update toast-notify@rukon-plugins
```

The same can be done from the `/plugin` menu. Run `claude plugin list` afterwards to check the versions. See [Update](docs/setup-guide.md#update) in the setup guide for what to check after specific versions.

**Coming from stop-notify?** It was renamed to toast-notify. After refreshing the marketplace, run `claude plugin install toast-notify@rukon-plugins` once, restart, and make sure `claude plugin list` no longer shows stop-notify. See [Renamed: stop-notify is now toast-notify](docs/setup-guide.md#renamed-stop-notify-is-now-toast-notify).

## License

MIT
