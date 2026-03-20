#!/bin/bash
# ================================================================
# destructive-guard.sh — Destructive Command Blocker
# ================================================================
# PURPOSE:
#   Blocks dangerous shell commands that can cause irreversible damage.
#   Catches rm -rf on sensitive paths, git reset --hard, git clean -fd,
#   and other destructive operations before they execute.
#
#   Built after a real incident where rm -rf on a pnpm project
#   followed NTFS junctions and deleted an entire C:\Users directory.
#   (GitHub Issue #36339)
#
# TRIGGER: PreToolUse
# MATCHER: "Bash"
#
# WHAT IT BLOCKS (exit 2):
#   - rm -rf / rm -r on root, home, or parent paths (/, ~, .., /home, /etc)
#   - git reset --hard
#   - git clean -fd / git clean -fdx
#   - chmod -R 777 on sensitive paths
#   - find ... -delete on broad patterns
#
# WHAT IT ALLOWS (exit 0):
#   - rm -rf on specific project subdirectories (node_modules, dist, build)
#   - git reset --soft, git reset HEAD
#   - All non-destructive commands
#
# CONFIGURATION:
#   CC_ALLOW_DESTRUCTIVE=1 — disable this guard (not recommended)
#   CC_SAFE_DELETE_DIRS — colon-separated list of safe-to-delete dirs
#     default: "node_modules:dist:build:.cache:__pycache__:coverage"
#
# NOTE: On Windows/WSL2, rm -rf can follow NTFS junctions (symlinks)
# and delete far more than intended. This guard is especially critical
# on WSL2 environments.
# ================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Allow override (not recommended)
if [[ "${CC_ALLOW_DESTRUCTIVE:-0}" == "1" ]]; then
    exit 0
fi

# Safe directories that can be deleted
SAFE_DIRS="${CC_SAFE_DELETE_DIRS:-node_modules:dist:build:.cache:__pycache__:coverage:.next:.nuxt:tmp}"

# --- Check 1: rm -rf on dangerous paths ---
if echo "$COMMAND" | grep -qE 'rm\s+(-[rf]+\s+)*(\/$|\/\s|\/[^a-z]|\/home|\/etc|\/usr|\/var|~\/|~\s*$|\.\.\/|\.\.\s*$)'; then
    # Exception: safe directories
    SAFE=0
    IFS=':' read -ra DIRS <<< "$SAFE_DIRS"
    for dir in "${DIRS[@]}"; do
        if echo "$COMMAND" | grep -qE "rm\s+.*${dir}\s*$|rm\s+.*${dir}/"; then
            SAFE=1
            break
        fi
    done

    if (( SAFE == 0 )); then
        echo "BLOCKED: rm on sensitive path detected." >&2
        echo "" >&2
        echo "Command: $COMMAND" >&2
        echo "" >&2
        echo "This command targets a sensitive directory that could cause" >&2
        echo "irreversible data loss. On WSL2, rm -rf can follow NTFS" >&2
        echo "junctions and delete far beyond the target directory." >&2
        echo "" >&2
        echo "If you need to delete a specific subdirectory, target it directly:" >&2
        echo "  rm -rf ./specific-folder" >&2
        exit 2
    fi
fi

# --- Check 2: git reset --hard ---
# Only match when git is the actual command, not inside strings/arguments
if echo "$COMMAND" | grep -qE '^\s*git\s+reset\s+--hard|;\s*git\s+reset\s+--hard|&&\s*git\s+reset\s+--hard|\|\|\s*git\s+reset\s+--hard'; then
    echo "BLOCKED: git reset --hard discards all uncommitted changes." >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Consider: git stash, or git reset --soft to keep changes staged." >&2
    exit 2
fi

# --- Check 3: git clean -fd ---
if echo "$COMMAND" | grep -qE '^\s*git\s+clean\s+-[a-z]*[fd]|;\s*git\s+clean|&&\s*git\s+clean|\|\|\s*git\s+clean'; then
    echo "BLOCKED: git clean removes untracked files permanently." >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Consider: git clean -n (dry run) first to see what would be deleted." >&2
    exit 2
fi

# --- Check 4: chmod 777 on broad paths ---
if echo "$COMMAND" | grep -qE 'chmod\s+(-R\s+)?777\s+(\/|~|\.)'; then
    echo "BLOCKED: chmod 777 on broad path is a security risk." >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    exit 2
fi

# --- Check 5: find -delete on broad patterns ---
if echo "$COMMAND" | grep -qE 'find\s+(\/|~|\.\.)\s.*-delete'; then
    echo "BLOCKED: find -delete on broad path risks mass deletion." >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Consider: find ... -print first to verify what matches." >&2
    exit 2
fi

exit 0
