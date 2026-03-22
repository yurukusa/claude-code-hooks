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

## Block Push When Errors Exist

**Problem:** Claude skips pipeline checks and pushes broken code ([#36970](https://github.com/anthropics/claude-code/issues/36970))

```bash
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

if echo "$COMMAND" | grep -qE '^\s*git\s+push'; then
    ERROR_LOG="${CC_ERROR_LOG:-$HOME/.claude/error-tracker.log}"
    if [ -f "$ERROR_LOG" ] && tail -5 "$ERROR_LOG" | grep -q "FAIL\|ERROR"; then
        echo "BLOCKED: Unresolved errors. Fix before pushing." >&2
        exit 2
    fi
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: Bash
> CLAUDE.md rules can be ignored. This hook **cannot**.

---

## Verify Memory Path (Auto Memory Debug)

**Problem:** MEMORY.md written to project tree but auto-loaded from `~/.claude/projects/` ([#36973](https://github.com/anthropics/claude-code/issues/36973))

```bash
# Find where your MEMORY.md actually lives
find ~/.claude/projects -name 'MEMORY.md' -type f 2>/dev/null
```

Not a hook — but a diagnostic that saves hours of confusion about why memories aren't persisting.

---

## Block PowerShell Destructive Commands (Windows/WSL2)

**Problem:** Claude runs `Remove-Item -Recurse -Force *` and destroys all files ([#37331](https://github.com/anthropics/claude-code/issues/37331))

```bash
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Skip string output commands (echo, printf, cat) to avoid false positives
if echo "$COMMAND" | grep -qE '^\s*(git\s+commit|echo\s|printf\s|cat\s)'; then
    exit 0
fi

# Block PowerShell recursive force-delete and Windows equivalents
if echo "$COMMAND" | grep -qiE 'Remove-Item.*-Recurse.*-Force|Remove-Item.*-Force.*-Recurse|del\s+/s\s+/q|rd\s+/s\s+/q'; then
    echo "BLOCKED: Destructive PowerShell command" >&2
    exit 2
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: Bash

## Block Database Destruction (Laravel/Django/Rails)

**Problem:** Claude runs `migrate:fresh`, `prisma migrate reset`, or `DROP DATABASE` and wipes production data ([#37405](https://github.com/anthropics/claude-code/issues/37405), [#37439](https://github.com/anthropics/claude-code/issues/37439), [#34729](https://github.com/anthropics/claude-code/issues/34729))

```bash
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Laravel
if echo "$COMMAND" | grep -qiE 'artisan\s+(migrate:fresh|migrate:reset|db:wipe)'; then
    echo "BLOCKED: destructive database command" >&2
    exit 2
fi

# Django
if echo "$COMMAND" | grep -qiE 'manage\.py\s+(flush|sqlflush)'; then
    echo "BLOCKED: destructive database command" >&2
    exit 2
fi

# Prisma
if echo "$COMMAND" | grep -qiE 'prisma\s+migrate\s+reset|prisma\s+db\s+push\s+--force-reset'; then
    echo "BLOCKED: destructive Prisma command" >&2
    exit 2
fi

# Raw SQL
if echo "$COMMAND" | grep -qiE 'DROP\s+(DATABASE|TABLE)|TRUNCATE'; then
    echo "BLOCKED: destructive SQL" >&2
    exit 2
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: Bash

---

## How to Write Your Own Hook

Every hook follows the same pattern:

```bash
#!/bin/bash
# 1. Read input from stdin
INPUT=$(cat)

# 2. Extract what you need (silence jq errors for malformed input)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
# or: FILE_PATH, .tool_name, .prompt

# 3. Check if empty (exit early)
[[ -z "$COMMAND" ]] && exit 0

# 4. Your logic here
if echo "$COMMAND" | grep -qE 'your_pattern'; then
    # Option A: Block (exit 2)
    echo "BLOCKED: reason" >&2
    exit 2

    # Option B: Auto-approve
    jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0

    # Option C: Warn (exit 0, but stderr goes to Claude's context)
    echo "WARNING: something" >&2
fi

# 5. Default: pass through
exit 0
```

**Exit codes:** `0` = allow, `2` = hard block, anything on stderr = shown to Claude.

Save to `~/.claude/hooks/your-hook.sh`, `chmod +x`, and add to settings.json.

## Edit/Write Guard (Defense-in-Depth)

**Problem:** PreToolUse hook `permissionDecision: "deny"` is ignored for Edit/Write tools — the file gets modified anyway ([#37210](https://github.com/anthropics/claude-code/issues/37210))

```bash
#!/bin/bash
# edit-guard.sh — Block Edit/Write to protected files
# Uses chmod as backup enforcement when deny is ignored

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0

# Protected patterns — customize for your project
PROTECTED=(".env" "credentials" "secrets" ".pem" ".key")
for pattern in "${PROTECTED[@]}"; do
    if [[ "$FILE" == *"$pattern"* ]]; then
        chmod 444 "$FILE" 2>/dev/null  # defense-in-depth
        echo "BLOCKED: Edit/Write denied for protected file: $FILE" >&2
        exit 2
    fi
done
exit 0
```

**Settings:** `"matcher": ""` (all tools)

---

*Each recipe was tested in a real GitHub Issue response. PRs welcome for new recipes.*

## Auto-Backup Config Files Before Edit
**Problem:** Claude rewrites config files (.mcp.json, settings.json) and strips important sections ([#36999](https://github.com/anthropics/claude-code/issues/36999))
```bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0
CONFIGS=(".mcp.json" "settings.json" "config.yaml" "config.json")
for cfg in "${CONFIGS[@]}"; do
    if [[ "$FILE" == *"$cfg" ]]; then
        cp "$FILE" "${FILE}.bak-$(date +%s)" 2>/dev/null
        echo "Backed up $FILE" >&2
    fi
done
exit 0
```
**Settings:** `"matcher": ""` (all tools)

---

## Protect Home Directory Dotfiles

**Problem:** Claude overwrites `.bashrc`, deletes `~/.aws/`, runs `chezmoi apply` without diffing first ([#37478](https://github.com/anthropics/claude-code/issues/37478))

```bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Block Edit/Write to critical dotfiles
if [[ "$TOOL" == "Edit" || "$TOOL" == "Write" ]]; then
    case "$FILE" in
        "$HOME/.bashrc"|"$HOME/.zshrc"|"$HOME/.profile"|"$HOME/.gitconfig")
            echo "BLOCKED: Cannot modify $FILE" >&2; exit 2 ;;
        "$HOME/.ssh/"*|"$HOME/.aws/"*)
            echo "BLOCKED: Cannot modify files in ${FILE%/*}/" >&2; exit 2 ;;
    esac
fi

# Block chezmoi/stow apply without --dry-run
if [[ "$TOOL" == "Bash" ]] && echo "$CMD" | grep -qE 'chezmoi\s+(init|apply)'; then
    echo "$CMD" | grep -qE '(--dry-run|diff)' || { echo "BLOCKED: Run chezmoi diff first" >&2; exit 2; }
fi
exit 0
```
**Settings:** `"matcher": ""` (all tools)
