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

## Block Database Destruction (Laravel/Django/Rails/Doctrine/Prisma)

**Problem:** Claude runs `migrate:fresh`, `doctrine:fixtures:load`, `prisma migrate reset`, or `DROP DATABASE` and wipes data ([#37405](https://github.com/anthropics/claude-code/issues/37405), [#37439](https://github.com/anthropics/claude-code/issues/37439), [#34729](https://github.com/anthropics/claude-code/issues/34729), [#37574](https://github.com/anthropics/claude-code/issues/37574))

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

# Doctrine/Symfony
if echo "$COMMAND" | grep -qiE 'doctrine:(fixtures:load|schema:drop|database:drop)' && ! echo "$COMMAND" | grep -qE '\-\-append'; then
    echo "BLOCKED: destructive Doctrine command" >&2
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

---

## Auto-Checkpoint After Edits

**Problem:** Context compaction silently reverts uncommitted changes to their git HEAD state ([#34674](https://github.com/anthropics/claude-code/issues/34674))

```bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0
git rev-parse --git-dir &>/dev/null || exit 0
DIRTY=$(git status --porcelain 2>/dev/null | head -1)
[[ -z "$DIRTY" ]] && exit 0
git add -A 2>/dev/null
git commit -m "checkpoint: auto-save $(date +%H:%M:%S)" --no-verify 2>/dev/null
exit 0
```
**Trigger:** PostToolUse, Matcher: `Edit|Write`

---

## Block git config --global

**Problem:** Claude modifies global git config (user.email, user.name) without user consent ([#37201](https://github.com/anthropics/claude-code/issues/37201))

```bash
CMD=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0
if echo "$CMD" | grep -qE '\bgit\s+config\s+--global\b'; then
    echo "BLOCKED: git config --global not allowed" >&2
    echo "Use --local for project-specific config" >&2
    exit 2
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: Bash

---

## Block Deploy Without Commit

**Problem:** Claude deploys without committing. Uncommitted changes silently revert on next sync ([#37314](https://github.com/anthropics/claude-code/issues/37314))

```bash
CMD=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0
if echo "$CMD" | grep -qiE '(rsync|scp|deploy|firebase\s+deploy|vercel|netlify\s+deploy)'; then
    git rev-parse --git-dir &>/dev/null || exit 0
    DIRTY=$(git status --porcelain 2>/dev/null | head -1)
    if [[ -n "$DIRTY" ]]; then
        echo "BLOCKED: Uncommitted changes. Commit before deploying." >&2
        exit 2
    fi
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: Bash

---

## Block Hardcoded API Keys in Export

**Problem:** Claude hardcodes API keys into `export` commands, exposing them in shell history

```bash
CMD=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0
if echo "$CMD" | grep -qE 'export\s+\w+=.*(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|glpat-[a-zA-Z0-9]{20,})'; then
    echo "BLOCKED: Hardcoded API key in export" >&2
    echo "Use: export VAR=\$(cat ~/.credentials/key)" >&2
    exit 2
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: Bash

---

## Block Path Traversal in Edit/Write

**Problem:** Claude uses `../../` in file paths to write outside the project directory

```bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0
if echo "$FILE" | grep -qE '\.\./\.\./|^/(etc|usr|bin|sbin|var)/'; then
    echo "BLOCKED: Path traversal or system directory: $FILE" >&2
    exit 2
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: `Edit|Write`

## Case-Insensitive Filesystem Guard

**Problem:** On exFAT/NTFS/HFS+ (case-insensitive), `mkdir Content` silently uses existing `content/`, then `rm -rf content` destroys everything ([#37875](https://github.com/anthropics/claude-code/issues/37875))

```bash
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0
echo "$COMMAND" | grep -qE '^\s*(mkdir|rm)\s' || exit 0

# Extract target path
TARGET=""
echo "$COMMAND" | grep -qE '^\s*mkdir' && TARGET=$(echo "$COMMAND" | grep -oP 'mkdir\s+(-p\s+)?\K\S+' | tail -1)
echo "$COMMAND" | grep -qE '^\s*rm\s' && TARGET=$(echo "$COMMAND" | grep -oP 'rm\s+(-[rf]+\s+)*\K\S+' | tail -1)
[[ -z "$TARGET" ]] && exit 0

PARENT=$(dirname "$TARGET" 2>/dev/null)
BASE=$(basename "$TARGET" 2>/dev/null)
[[ ! -d "$PARENT" ]] && exit 0

# Test if filesystem is case-insensitive
TEST_FILE="${PARENT}/.cc_case_test_$$"
touch "$TEST_FILE" 2>/dev/null || exit 0
if [[ -f "${PARENT}/.CC_CASE_TEST_$$" ]]; then
    rm -f "$TEST_FILE"
    # Case-insensitive FS — check for collisions
    BASE_LOWER=$(echo "$BASE" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r entry; do
        ENTRY_LOWER=$(echo "$entry" | tr '[:upper:]' '[:lower:]')
        if [[ "$ENTRY_LOWER" == "$BASE_LOWER" ]] && [[ "$entry" != "$BASE" ]]; then
            echo "BLOCKED: Case collision on case-insensitive filesystem." >&2
            echo "'$BASE' and '$entry' resolve to the SAME path on this drive." >&2
            exit 2
        fi
    done < <(ls -1 "$PARENT" 2>/dev/null)
else
    rm -f "$TEST_FILE"
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: `Bash`

## Auto-Approve Safe Compound Commands

**Problem:** `Bash(git:*)` doesn't match `cd /path && git log`. Permission prompts fire on every compound command. ([#30519](https://github.com/anthropics/claude-code/issues/30519) 53r, [#16561](https://github.com/anthropics/claude-code/issues/16561) 101r)

```bash
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0
echo "$COMMAND" | grep -qE '&&|\|\||;' || exit 0

# Split and check each component
ALL_SAFE=1
while IFS= read -r part; do
    part=$(echo "$part" | sed 's/^\s*//; s/\s*$//')
    [[ -z "$part" ]] && continue
    if ! echo "$part" | grep -qE '^\s*(cd|ls|pwd|echo|cat|head|tail|wc|sort|grep|find|test|true|mkdir\s+-p)\s|^\s*git\s+(status|log|diff|branch|show|rev-parse|tag|add|commit)\s|^\s*(npm|yarn|pnpm)\s+(test|run|list|audit)\s|^\s*(python3?|pytest|cargo|go|make)\s+(test|build|check)\s'; then
        ALL_SAFE=0; break
    fi
done < <(echo "$COMMAND" | sed 's/&&/\n/g; s/||/\n/g; s/;/\n/g')

if [ "$ALL_SAFE" = 1 ]; then
    jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"compound command auto-approved"}}'
fi
exit 0
```
**Trigger:** PreToolUse, Matcher: `Bash`

## Clean Up /tmp/claude-*-cwd Files

**Problem:** Claude Code creates `/tmp/claude-{hex}-cwd` files but never deletes them. Hundreds accumulate per day. ([#8856](https://github.com/anthropics/claude-code/issues/8856) 67r, 102 comments)

```bash
#!/bin/bash
# Runs on session end — cleans files older than 60 minutes
find /tmp -maxdepth 1 -name 'claude-*-cwd' -type f -mmin +60 -delete 2>/dev/null
exit 0
```
**Trigger:** Stop, Matcher: `""` (empty)

## Debug Any Hook (Wrapper)

**Problem:** Hook silently fails. No error, no output, nothing in logs. What went wrong?

```bash
#!/bin/bash
# Wrap any hook: hook-debug-wrapper.sh <actual-hook.sh>
HOOK="$1"; INPUT=$(cat)
START=$(($(date +%s%N)/1000000))
STDOUT=$(mktemp); STDERR=$(mktemp)
echo "$INPUT" | bash "$HOOK" >"$STDOUT" 2>"$STDERR"; EC=$?
MS=$(($(($(date +%s%N)/1000000))-START))
{
  echo "=== $(date -Iseconds) $(basename "$HOOK") exit:$EC ${MS}ms ==="
  [ -s "$STDERR" ] && echo "err: $(head -c 200 "$STDERR")"
  [ -s "$STDOUT" ] && echo "out: $(head -c 200 "$STDOUT")"
  echo "in: $(echo "$INPUT" | head -c 300)"
} >> ~/.claude/hook-debug.log
cat "$STDOUT"; cat "$STDERR" >&2; rm -f "$STDOUT" "$STDERR"; exit $EC
```
**Usage:** Change hook command to `hook-debug-wrapper.sh ~/.claude/hooks/your-hook.sh`

## Break Command Repetition Loops

**Problem:** Claude gets stuck running the same command (or cycle) repeatedly, wasting context window and time.

```bash
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0
STATE="/tmp/cc-loop-history"
NORM=$(echo "$COMMAND" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
echo "$NORM" >> "$STATE"
tail -n 10 "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
COUNT=$(grep -cF "$NORM" "$STATE" 2>/dev/null || echo 0)
[ "$COUNT" -ge 5 ] && echo "BLOCKED: Repeated $COUNT times. Try a different approach." >&2 && exit 2
[ "$COUNT" -ge 3 ] && echo "WARNING: Command repeated $COUNT times." >&2
exit 0
```
**Trigger:** PreToolUse, Matcher: `Bash`
**Problem:** After `/compact` or session restart, Claude forgets what it was doing.
```bash
HANDOFF="${CC_HANDOFF_FILE:-$HOME/.claude/session-handoff.md}"
{
    echo "# Session Handoff"
    echo "**Ended:** $(date -Iseconds)"
    if [ -d ".git" ]; then
        echo "**Branch:** $(git branch --show-current 2>/dev/null)"
        echo "**Last commit:** $(git log --oneline -1 2>/dev/null)"
        CHANGES=$(git diff --name-only 2>/dev/null | head -5)
        [ -n "$CHANGES" ] && echo '```' && echo "$CHANGES" && echo '```'
    fi
} > "$HANDOFF"
exit 0
```
**Trigger:** Stop, Matcher: `""` (empty)
**Problem:** Claude modifies 30+ files without committing. The resulting diff is unreviable.
```bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0
echo "$COMMAND" | grep -qE '^\s*git\s+(commit|add\s+(-A|--all|\.))' || exit 0
[ -d .git ] || exit 0
TOTAL=$(git diff --name-only HEAD 2>/dev/null | wc -l)
STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l)
COUNT=$((TOTAL + STAGED))
[ "$COUNT" -ge 50 ] && echo "BLOCKED: $COUNT files — split into smaller commits" >&2 && exit 2
[ "$COUNT" -ge 10 ] && echo "WARNING: $COUNT files changed" >&2
exit 0
```
**Trigger:** PreToolUse, Matcher: `Bash`
**Problem:** rm -rf follows symlinks/junctions and deletes data outside the target. C:\Users deleted via NTFS junction (#36339, 93r).
```bash
CMD=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0
echo "$CMD" | grep -qE '^\s*rm\s+.*-[rf]' || exit 0
TARGET=$(echo "$CMD" | grep -oP 'rm\s+(-[rf]+\s+)*\K\S+' | tail -1)
[ -z "$TARGET" ] || [ ! -d "$TARGET" ] && exit 0
LINKS=$(find "$TARGET" -maxdepth 3 -type l 2>/dev/null | while read l; do
    R=$(readlink -f "$l" 2>/dev/null)
    [[ "$R" != "$(pwd)"* ]] && echo "$l -> $R"
done | head -3)
[ -n "$LINKS" ] && echo "BLOCKED: symlinks pointing outside project" >&2 && exit 2
exit 0
```
**Trigger:** PreToolUse, Matcher: `Bash`
**Problem:** Claude Code sometimes modifies CLAUDE.md or settings.json without permission.
```bash
FILE=$(cat | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0
case "$(basename "$FILE")" in
    CLAUDE.md|settings.json|settings.local.json)
        echo "BLOCKED: Cannot modify config file: $FILE" >&2
        exit 2 ;;
esac
exit 0
```
**Trigger:** PreToolUse, Matcher: `Edit|Write`
