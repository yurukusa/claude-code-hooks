#!/bin/bash
# ================================================================
# branch-guard.sh — Main/Master Branch Push Blocker
# ================================================================
# PURPOSE:
#   Prevents accidental git push commands to main or master branches
#   without explicit approval. Allows pushes to feature/staging branches.
#
#   Protects production branches from unintended force-pushes,
#   incomplete changes, or unauthorized modifications.
#
# TRIGGER: PreToolUse
# MATCHER: "Bash"
#
# WHAT IT BLOCKS (exit 2):
#   - git push origin main
#   - git push --force origin master
#   - Any variant targeting main/master
#
# WHAT IT ALLOWS (exit 0):
#   - git push origin feature-branch
#   - git push origin develop
#   - All other git commands
#   - All non-git commands
#
# CONFIGURATION:
#   CC_PROTECT_BRANCHES — colon-separated list of protected branches
#     default: "main:master"
#     Example: "main:master:production" to add more
#
# NOTE: This hook exits 2 (not 1) to distinguish from errors.
# ================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Only check git push commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+push'; then
    exit 0
fi

# Get protected branches from env, default to main and master
PROTECTED="${CC_PROTECT_BRANCHES:-main:master}"

# Check if any protected branch appears in the push command
BLOCKED=0
IFS=':' read -ra BRANCHES <<< "$PROTECTED"
for branch in "${BRANCHES[@]}"; do
    # Match whole word branch names (main, not mainline)
    if echo "$COMMAND" | grep -qwE "origin\s+${branch}|${branch}\s|${branch}$"; then
        BLOCKED=1
        break
    fi
done

if (( BLOCKED == 1 )); then
    echo "BLOCKED: Attempted push to protected branch." >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Protected branches: $PROTECTED" >&2
    echo "" >&2
    echo "This is likely unintended. Push to a feature/staging branch first," >&2
    echo "then create a pull request for manual review." >&2
    exit 2
fi

exit 0
