#!/bin/bash
# ================================================================
# proof-log-session.sh — Automatic Session Summary Generator
# ================================================================
# PURPOSE:
#   Generates a structured 5W1H summary when a Claude Code session
#   ends (or compacts). Answers: When, Who, What files changed,
#   Where (working directory), How (which tools were used).
#
#   Creates daily log files so you have a paper trail of everything
#   Claude Code did, even across multiple sessions per day.
#
# TRIGGER: Stop, PreCompact
# MATCHER: "" (empty)
#
# OUTPUT:
#   Daily markdown files at $CC_PROOF_LOG_DIR/YYYY-MM-DD.md
#   Each session gets a timestamped section with:
#   - Session duration
#   - Files changed (with +/- line counts)
#   - Tools used and frequency
#
# CONFIGURATION:
#   CC_PROOF_LOG_DIR — directory for daily proof logs
#     default: $HOME/proof-log
#
#   CC_ACTIVITY_LOG — path to activity-logger.sh's JSONL output
#     default: $HOME/claude-activity-log.jsonl
#
#   CC_SESSION_START_FILE — path to session start timestamp
#     default: /tmp/cc-session-start-ts
#     (auto-created by session-start-marker.sh)
#
# REQUIRES: python3
#
# PAIRS WITH:
#   session-start-marker.sh (records session start time)
#   activity-logger.sh (records individual file changes)
# ================================================================

PROOF_LOG_DIR="${CC_PROOF_LOG_DIR:-$HOME/proof-log}"
ACTIVITY_LOG="${CC_ACTIVITY_LOG:-$HOME/claude-activity-log.jsonl}"

mkdir -p "$PROOF_LOG_DIR"

# Resolve session start timestamp
# Supports both per-session (PPID-based) and legacy single-file formats
SESSION_START_EPOCH=0
SESSION_ID="${PPID:-$$}"
SESSION_START_FILE_PID="/tmp/cc-session-start-ts-${SESSION_ID}"
SESSION_START_FILE="${CC_SESSION_START_FILE:-/tmp/cc-session-start-ts}"

if [[ -f "$SESSION_START_FILE_PID" ]]; then
    SESSION_START_EPOCH=$(cat "$SESSION_START_FILE_PID" 2>/dev/null || echo 0)
    SESSION_START_FILE="$SESSION_START_FILE_PID"
elif [[ -f "$SESSION_START_FILE" ]]; then
    SESSION_START_EPOCH=$(cat "$SESSION_START_FILE" 2>/dev/null || echo 0)
elif [[ -f "/tmp/cc-context-monitor-count" ]]; then
    SESSION_START_EPOCH=$(stat -c %Y "/tmp/cc-context-monitor-count" 2>/dev/null || echo 0)
fi

NOW_EPOCH=$(date +%s)

# Session timing
if [[ "$SESSION_START_EPOCH" -gt 0 ]]; then
    START_TIME=$(date -d "@$SESSION_START_EPOCH" '+%H:%M' 2>/dev/null || echo "?")
    END_TIME=$(date '+%H:%M')
    DURATION_MIN=$(( (NOW_EPOCH - SESSION_START_EPOCH) / 60 ))
else
    START_TIME="unknown"
    END_TIME=$(date '+%H:%M')
    DURATION_MIN="unknown"
fi

# Skip 0-minute sessions (hook fired but no real work happened)
if [[ "$DURATION_MIN" == "0" ]]; then
    rm -f "$SESSION_START_FILE" >/dev/null 2>&1 || true
    exit 0
fi

# Date for the daily file
TODAY=$(date '+%Y-%m-%d')
DAILY_FILE="${PROOF_LOG_DIR}/${TODAY}.md"

# Duplicate prevention: don't add same session twice
ENTRY_HEADER="### ${TODAY} ${START_TIME}-${END_TIME}"
if [[ -f "$DAILY_FILE" ]] && grep -qF "$ENTRY_HEADER" "$DAILY_FILE" 2>/dev/null; then
    rm -f "$SESSION_START_FILE" >/dev/null 2>&1 || true
    exit 0
fi

# --- Aggregate activity log for this session ---
FILTER_START=$((SESSION_START_EPOCH > 300 ? SESSION_START_EPOCH - 300 : 0))

REPORT="$(
    python3 - "$ACTIVITY_LOG" "$FILTER_START" 2>/dev/null <<'PY'
import json, sys, os
from datetime import datetime
import time

activity_log = sys.argv[1]
session_start = int(sys.argv[2])

files_changed = {}
total_add = 0
total_del = 0
tools_used = {}

if session_start <= 0:
    session_start = int(time.time()) - 1800

try:
    with open(activity_log, 'r') as f:
        for line in f:
            try:
                entry = json.loads(line.strip())
                ts_str = entry.get('ts', '')
                if ts_str:
                    dt = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                    entry_epoch = int(dt.timestamp())
                else:
                    continue
                if entry_epoch >= session_start:
                    path = entry.get('path', '')
                    tool = entry.get('tool', '?')
                    add = entry.get('add', 0)
                    dele = entry.get('del', 0)
                    tools_used[tool] = tools_used.get(tool, 0) + 1
                    if path:
                        basename = os.path.basename(path)
                        if path in files_changed:
                            files_changed[path]['add'] += add
                            files_changed[path]['del'] += dele
                            files_changed[path]['count'] += 1
                        else:
                            files_changed[path] = {'add': add, 'del': dele, 'name': basename, 'count': 1}
                        total_add += add
                        total_del += dele
            except (json.JSONDecodeError, ValueError):
                pass
except FileNotFoundError:
    pass

out = []
items = sorted(files_changed.items(), key=lambda x: x[1]['add'] + x[1]['del'], reverse=True)[:8]
if items:
    out.append(f"- What: {len(files_changed)} files changed (+{total_add}/-{total_del})")
    for path, info in items:
        out.append(f"  - {info['name']} (+{info['add']}/-{info['del']}, {info['count']} edits)")
if tools_used:
    parts = [f"{t}: {c}x" for t, c in sorted(tools_used.items(), key=lambda x: -x[1])]
    out.append(f"- How: {', '.join(parts)}")

print('\n'.join(out))
PY
)" || REPORT=""

# --- Write daily log ---
if [[ ! -f "$DAILY_FILE" ]]; then
    cat > "$DAILY_FILE" <<EOF
# Proof Log ${TODAY}

EOF
fi

{
    echo ""
    echo "${ENTRY_HEADER} — Session Summary (auto-generated)"
    echo ""
    echo "- When: ${START_TIME} - ${END_TIME} (${DURATION_MIN} min)"
    echo "- Where: $(basename "$(pwd)")"
    if [[ -n "$REPORT" ]]; then
        echo "$REPORT"
    else
        echo "- (no file changes recorded)"
    fi
} >> "$DAILY_FILE"

# Cleanup session start file
rm -f "$SESSION_START_FILE" "/tmp/cc-session-start-ts-${SESSION_ID}" >/dev/null 2>&1 || true

exit 0
