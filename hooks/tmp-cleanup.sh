#!/bin/bash
# ================================================================
# tmp-cleanup.sh — Auto-cleanup tmpclaude-*-cwd temporary files
# ================================================================
# PURPOSE:
#   Claude Code creates tmpclaude-XXXX-cwd temporary files in the
#   working directory during bash operations. These pile up and
#   clutter the project directory.
#
#   This hook runs after each tool use and removes any stale
#   tmpclaude-*-cwd files from the current working directory.
#
# TRIGGER: PostToolUse
# MATCHER: "" (all tools)
#
# INCIDENT: GitHub Issues #17673 (11r), #17664 (10r)
#   Both Windows and Linux users report tmpclaude files accumulating.
#
# CONFIGURATION:
#   CC_TMP_CLEANUP_DISABLE=1 — disable this hook
#   CC_TMP_CLEANUP_AGE=60 — only delete files older than N seconds (default: 60)
# ================================================================

INPUT=$(cat)

if [[ "${CC_TMP_CLEANUP_DISABLE:-0}" == "1" ]]; then
    exit 0
fi

# Get the current working directory from the hook input
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
if [[ -z "$CWD" ]]; then
    exit 0
fi

AGE="${CC_TMP_CLEANUP_AGE:-60}"

# Find and remove tmpclaude-*-cwd files older than AGE seconds
find "$CWD" -maxdepth 1 -name "tmpclaude-*-cwd" -mmin "+$((AGE / 60))" -delete 2>/dev/null

exit 0
