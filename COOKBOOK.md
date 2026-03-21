# Claude Code Hooks Cookbook

Real-world hook recipes from [GitHub Issue responses](https://github.com/anthropics/claude-code/issues). Each recipe solves a problem that the permission system can't handle.

## Auto-Approve Read-Only Git (Even with -C flag)

**Problem:** `Bash(git status:*)` doesn't match `git -C /path status` ([#36900](https://github.com/anthropics/claude-code/issues/36900))

```bash
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

if echo "$COMMAND" | grep -qE '^\s*git\s+(-C\s+\S+\s+)?(status|log|diff|branch|show|rev-parse)(\s|$)'; then
    jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"git read-only auto-approved"}}'
    exit 0
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: Bash

---

## Auto-Approve SSH Commands (Trailing Wildcard Fix)

**Problem:** `Bash(ssh * uptime *)` doesn't match `ssh host uptime` (no args) ([#36873](https://github.com/anthropics/claude-code/issues/36873))

```bash
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

SAFE="uptime|w|whoami|hostname|uname|date|df|free"
if echo "$COMMAND" | grep -qE "^\s*ssh\s+\S+\s+($SAFE)(\s|$)"; then
    jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"safe SSH auto-approved"}}'
    exit 0
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: Bash

---

## Desktop Notification When Claude Waits

**Problem:** Multiple sessions running, no way to know which one needs input ([#36885](https://github.com/anthropics/claude-code/issues/36885))

```bash
#!/bin/bash
# Linux (native, not WSL2)
[ -z "$WSL_DISTRO_NAME" ] && notify-send "Claude Code" "Waiting for your input" 2>/dev/null && exit 0
# macOS
osascript -e 'display notification "Waiting for input" with title "Claude Code"' 2>/dev/null && exit 0
# WSL2 (PowerShell toast)
powershell.exe -Command "Write-Host 'Claude Code: Waiting for input'" 2>/dev/null
exit 0
```
**Trigger:** Notification, Matcher: (empty)
> **WSL2 note:** `notify-send` exists but D-Bus is usually not running. The script detects WSL2 via `$WSL_DISTRO_NAME` and uses PowerShell instead.

---

## Enforce "Every Change Needs Tests"

**Problem:** CLAUDE.md rules get ignored during implementation ([#36920](https://github.com/anthropics/claude-code/issues/36920))

```bash
#!/bin/bash
FILE_PATH=$(cat | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

if [[ "$FILE_PATH" == *.py ]] && [[ "$FILE_PATH" != *test* ]]; then
    BASENAME=$(basename "$FILE_PATH" .py)
    if [ ! -f "tests/test_${BASENAME}.py" ] && [ ! -f "test_${BASENAME}.py" ]; then
        echo "WARNING: Edited $FILE_PATH but no test file found." >&2
    fi
fi
exit 0
```
**Trigger:** PostToolUse, Matcher: Edit|Write

---

## Auto-Approve Edit/Write on Windows

**Problem:** `Edit(.claude/**)` rules ignored in VS Code on Windows ([#36884](https://github.com/anthropics/claude-code/issues/36884))

```bash
#!/bin/bash
TOOL=$(cat | jq -r '.tool_name // empty' 2>/dev/null)
if [[ "$TOOL" == "Edit" || "$TOOL" == "Write" ]]; then
    jq -n '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","permissionDecision":"allow"}}'
fi
exit 0
```
**Trigger:** PermissionRequest, Matcher: (empty)

---

## Feedback Archive

**Problem:** /feedback text is sent but not saved locally ([#36912](https://github.com/anthropics/claude-code/issues/36912))

```bash
#!/bin/bash
PROMPT=$(cat | jq -r '.prompt // empty' 2>/dev/null)
if echo "$PROMPT" | grep -qE '^\s*/feedback'; then
    echo "## $(date -Iseconds)" >> ~/.claude/feedback-archive.md
    echo "$PROMPT" >> ~/.claude/feedback-archive.md
    echo "" >> ~/.claude/feedback-archive.md
fi
exit 0
```
**Trigger:** UserPromptSubmit, Matcher: (empty)

---

*Each recipe was tested in a real GitHub Issue response. PRs welcome for new recipes.*
