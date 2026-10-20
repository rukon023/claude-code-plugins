---
description: Make the usage status line your Claude Code status line, replacing any other one
allowed-tools: PowerShell, Bash
---

Run this command to install the usage status line and make it the active one, replacing any status line already configured:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/install.ps1" -Force
```

Then tell the user, in one or two sentences, what the command printed and that the new status line appears after their next message (or after restarting Claude Code).
