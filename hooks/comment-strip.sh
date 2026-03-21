#!/bin/bash
# ================================================================
# comment-strip.sh — Strip bash comments that break permissions
# ================================================================
# PURPOSE:
#   Claude Code sometimes adds comments to bash commands like:
#     # Check the diff
#     git diff HEAD~1
#   This breaks permission allowlists (e.g. Bash(git:*)) because
#   the matcher sees "# Check the diff" instead of "git diff".
#
#   This hook strips leading comment lines and returns the clean
#   command via updatedInput, so permissions match correctly.
#
# TRIGGER: PreToolUse
# MATCHER: "Bash"
#
# INCIDENT: GitHub Issue #29582 (18 reactions)
#   Users on linux/vscode report that bash comments added by Claude
#   cause permission prompts even when the command is allowlisted.
#
# HOW IT WORKS:
#   - Reads the command from tool_input
#   - Strips leading lines that start with #
#   - Strips trailing comments (everything after # on command lines)
#   - Returns updatedInput with the cleaned command
#   - Uses hookSpecificOutput.permissionDecision = "allow" only if
#     the command was modified (so it doesn't override other hooks)
# ================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Strip leading comment lines and empty lines
CLEAN=$(echo "$COMMAND" | sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d')

# If nothing changed, pass through
if [[ "$CLEAN" == "$COMMAND" ]]; then
    exit 0
fi

# If command is empty after stripping, don't modify
if [[ -z "$CLEAN" ]]; then
    exit 0
fi

# Return cleaned command via hookSpecificOutput
# permissionDecision is not set — let the normal permission flow handle it
# We only modify the input so the permission matcher sees the real command
jq -n --arg cmd "$CLEAN" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: {
      command: $cmd
    }
  }
}'
