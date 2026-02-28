#!/bin/bash
# ================================================================
# session-start-marker.sh — Session Start Time Recorder
# ================================================================
# PURPOSE:
#   Records the timestamp when a Claude Code session begins.
#   Used by proof-log-session.sh (Stop hook) to calculate session
#   duration and filter activity logs to the current session.
#
# TRIGGER: PostToolUse (all tools)
# MATCHER: "" (empty = every tool invocation)
#
# HOW IT WORKS:
#   On the first tool invocation of a session, writes the current
#   Unix timestamp to a temp file. Subsequent invocations are
#   no-ops (the file already exists).
#
#   Uses PPID-based file naming so multiple concurrent Claude Code
#   sessions don't overwrite each other's start times.
#
# CONFIGURATION:
#   CC_SESSION_START_FILE — override the timestamp file path
#     default: /tmp/cc-session-start-ts-${PPID}
#
# PAIRS WITH:
#   proof-log-session.sh (reads the start time to compute duration)
# ================================================================

SESSION_ID="${PPID:-$$}"
START_FILE="${CC_SESSION_START_FILE:-/tmp/cc-session-start-ts-${SESSION_ID}}"

# Only record once per session
if [[ -f "$START_FILE" ]]; then
    exit 0
fi

date +%s > "$START_FILE"

exit 0
