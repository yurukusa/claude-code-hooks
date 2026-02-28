#!/bin/bash
# ================================================================
# activity-logger.sh — Automatic File Change Logger
# ================================================================
# PURPOSE:
#   Records every file edit/write to a JSONL log file. Gives you
#   a complete audit trail of what was changed, when, and how much.
#   Useful for session summaries, debugging, and understanding
#   what Claude Code actually did during a session.
#
# TRIGGER: PostToolUse
# MATCHER: "Edit|Write"
#
# OUTPUT FORMAT (JSONL, one line per change):
#   {"ts":"2026-02-28T12:00:00Z","tool":"Edit","path":"/path/to/file",
#    "add":5,"del":2,"summary":"file.py","needs_review":false}
#
# CONFIGURATION:
#   CC_ACTIVITY_LOG — path to the JSONL log file
#     default: $HOME/claude-activity-log.jsonl
#
#   CC_MONITORED_PATHS — colon-separated list of paths that trigger
#     the needs_review flag (e.g., "$HOME/bin:$HOME/.claude/hooks")
#     default: "" (no paths monitored)
#
# REQUIRES: jq, python3
# ================================================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

TOOL_INPUT_RAW=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_NAME="${TOOL_NAME:-Edit}"

TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Estimate lines added/deleted from the edit operation
ADD_LINES=0
DEL_LINES=0
SUMMARY=""
if [[ -n "$TOOL_INPUT_RAW" ]]; then
    eval "$(echo "$TOOL_INPUT_RAW" | python3 -c "
import sys, json, os
d = json.load(sys.stdin)
old = d.get('old_string', '')
new = d.get('new_string', '')
content = d.get('content', '')
old_lines = len(old.splitlines()) if old else 0
new_lines = len(new.splitlines()) if new else 0
if content:
    new_lines = len(content.splitlines())
    old_lines = 0
add = max(0, new_lines - old_lines) if not content else new_lines
dele = max(0, old_lines - new_lines) if not content else 0
print(f'ADD_LINES={add}')
print(f'DEL_LINES={dele}')
print(f'SUMMARY=\"{os.path.basename(d.get(\"file_path\",\"\"))}\"')
" 2>/dev/null || echo "")"
fi

# Write to activity log
LOG_FILE="${CC_ACTIVITY_LOG:-$HOME/claude-activity-log.jsonl}"
LOG_DIR="$(dirname "$LOG_FILE")"
mkdir -p "$LOG_DIR"

# Check if the changed file is in a monitored path
NEEDS_REVIEW="False"
IFS=':' read -ra MONITORED <<< "${CC_MONITORED_PATHS:-}"
for monitored_path in "${MONITORED[@]}"; do
    if [[ -n "$monitored_path" ]] && [[ "$FILE_PATH" == "${monitored_path}"* ]]; then
        NEEDS_REVIEW="True"
        break
    fi
done

# Write JSONL entry
python3 -c "
import json
entry = {
    'ts': '$TS',
    'tool': '$TOOL_NAME',
    'path': '$FILE_PATH',
    'add': $ADD_LINES,
    'del': $DEL_LINES,
    'summary': '$SUMMARY',
    'needs_review': $NEEDS_REVIEW
}
print(json.dumps(entry, ensure_ascii=False))
" >> "$LOG_FILE" 2>/dev/null || true

exit 0
