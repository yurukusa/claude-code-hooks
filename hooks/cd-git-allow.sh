#!/bin/bash
# ================================================================
# cd-git-allow.sh — Auto-approve cd+git compound commands
# ================================================================
# PURPOSE:
#   Claude Code shows "Compound commands with cd and git require
#   approval" for commands like: cd /path && git log
#   This is safe in trusted project directories but causes
#   constant permission prompts.
#
#   This hook auto-approves cd+git compounds when the git operation
#   is read-only (log, diff, status, branch, show, etc.)
#   Destructive git operations (push, reset, clean) are NOT
#   auto-approved — they still require manual approval.
#
# TRIGGER: PreToolUse
# MATCHER: "Bash"
#
# INCIDENT: GitHub Issue #32985 (9 reactions)
#
# WHAT IT AUTO-APPROVES:
#   - cd /path && git log
#   - cd /path && git diff
#   - cd /path && git status
#   - cd /path && git branch
#   - cd /path && git show
#   - cd /path && git rev-parse
#
# WHAT IT DOES NOT APPROVE (still prompts):
#   - cd /path && git push
#   - cd /path && git reset --hard
#   - cd /path && git clean
#   - cd /path && git checkout (could discard changes)
# ================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Only handle cd + git compounds
if ! echo "$COMMAND" | grep -qE '^\s*cd\s+.*&&\s*git\s'; then
    exit 0
fi

# Extract the git subcommand
GIT_CMD=$(echo "$COMMAND" | grep -oP '&&\s*git\s+\K\S+')

# Read-only git operations — safe to auto-approve
SAFE_GIT="log diff status branch show rev-parse tag remote stash-list describe name-rev"

for safe in $SAFE_GIT; do
    if [[ "$GIT_CMD" == "$safe" ]]; then
        jq -n '{
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "allow",
            permissionDecisionReason: "cd+git compound auto-approved (read-only git operation)"
          }
        }'
        exit 0
    fi
done

# Not a read-only git op — let normal permission flow handle it
exit 0
