#!/bin/bash
# ================================================================
# decision-warn.sh — Monitored Path Change Alerter
# ================================================================
# PURPOSE:
#   Warns (but never blocks) when Claude Code edits files in
#   sensitive/monitored directories. The idea: some paths deserve
#   extra scrutiny — scripts in ~/bin, hook definitions, configs.
#   This hook makes those changes visible without restricting
#   the agent's ability to act.
#
# TRIGGER: PreToolUse
# MATCHER: "Edit|Write"
#
# DESIGN PHILOSOPHY:
#   "Don't tie the agent's hands. Let it do anything, but make
#   important changes loud." — This hook never returns exit 1.
#   It always exits 0. It logs, it warns, it never blocks.
#
# CONFIGURATION:
#   CC_MONITORED_DIRS — colon-separated list of directories to
#     monitor. Edits to files under these dirs trigger a warning.
#     default: "$HOME/bin:$HOME/.claude/hooks"
#
#   CC_DECISIONS_DIR — directory containing decision records.
#     If a decision file with matching scope and "agreed" status
#     exists, the warning is suppressed.
#     default: "" (disabled — all monitored edits warn)
#
# REQUIRES: jq
# ================================================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Check if file is under any monitored directory
MONITORED_DIRS="${CC_MONITORED_DIRS:-$HOME/bin:$HOME/.claude/hooks}"
IN_SCOPE=0

IFS=':' read -ra DIRS <<< "$MONITORED_DIRS"
for dir in "${DIRS[@]}"; do
    # Normalize: ensure trailing slash
    dir="${dir%/}/"
    if [[ "$FILE_PATH" == "${dir}"* ]]; then
        IN_SCOPE=1
        break
    fi
done

if (( IN_SCOPE == 0 )); then
    exit 0
fi

# Optional: check for pre-approved decisions
DECISIONS_DIR="${CC_DECISIONS_DIR:-}"
HAS_AGREED=0

if [[ -n "$DECISIONS_DIR" && -d "$DECISIONS_DIR" ]]; then
    for f in "$DECISIONS_DIR"/D-*.md; do
        [[ -f "$f" ]] || continue

        local_scope=$(grep '^scope: ' "$f" 2>/dev/null | head -1 | sed 's/^scope: //')
        local_status=$(grep '^status: ' "$f" 2>/dev/null | head -1 | sed 's/^status: //')

        scope_base=$(echo "$local_scope" | sed 's/\*\*//' | sed 's|/$||')
        if [[ "$FILE_PATH" == *"$scope_base"* && "$local_status" == "agreed" ]]; then
            HAS_AGREED=1
            break
        fi
    done
fi

if (( HAS_AGREED == 0 )); then
    echo "NOTE: Editing monitored path: $FILE_PATH"
    echo "  This change will be recorded in the activity log."
fi

# Always exit 0 — never block
exit 0
