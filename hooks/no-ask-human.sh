#!/bin/bash
# ================================================================
# no-ask-human.sh — Autonomous Decision Enforcement
# ================================================================
# PURPOSE:
#   Detects when Claude Code's output contains questions directed
#   at the user ("Should I...?", "Would you like...?", "Which
#   approach do you prefer?") and reminds the agent to decide
#   autonomously instead of asking.
#
#   This is essential for autonomous/unattended operation where
#   no human is available to answer questions. Every question is
#   a blocking call with no one on the other end.
#
# TRIGGER: PostToolUse (all tools) OR Notification
# MATCHER: "" (empty)
#
# NOTE ON IMPLEMENTATION:
#   This hook works on the tool output / notification content.
#   It reads from stdin and checks for question patterns.
#   It NEVER blocks (always exit 0) — it issues a reminder only.
#
# DESIGN PHILOSOPHY:
#   "Every question to the user is a context switch they didn't
#   ask for, and in autonomous mode, it's a deadlock."
#   The hook doesn't prevent the question — it can't unsend text.
#   But it trains the agent (via system message feedback) to
#   self-correct in future interactions.
#
# CONFIGURATION:
#   CC_NO_ASK_ENABLED — set to "0" to disable (default: "1")
#   CC_NO_ASK_PATTERNS_FILE — path to a file with additional
#     patterns (one regex per line). Merged with built-in patterns.
#
# PATTERNS DETECTED:
#   - "Should I...?"
#   - "Would you like...?"
#   - "Do you want...?"
#   - "Which approach/option...?"
#   - "What do you think...?"
#   - "Shall I...?"
#   - "Do you prefer...?"
#   - "Can you confirm...?"
#   - "Is that okay...?"
#   - "Let me know if..."
#
# BORN FROM:
#   Running Claude Code in autonomous 24/7 mode where every
#   question hangs the session until a human happens to check in.
#   Some sessions asked 3+ questions, burning 30min+ of idle time
#   each. This hook reduced question frequency by ~90%.
# ================================================================

# Feature toggle
if [[ "${CC_NO_ASK_ENABLED:-1}" == "0" ]]; then
    exit 0
fi

INPUT=$(cat)

# Extract the relevant text to check.
# For Notification hooks: check the message
# For PostToolUse: check tool output
TEXT=""
if echo "$INPUT" | jq -e '.message' &>/dev/null; then
    TEXT=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)
elif echo "$INPUT" | jq -e '.tool_output' &>/dev/null; then
    TEXT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null)
fi

if [[ -z "$TEXT" ]]; then
    exit 0
fi

# Built-in question patterns (English)
PATTERNS=(
    'should [iI] '
    'would you like'
    'do you want'
    'which (approach|option|method|way)'
    'what do you think'
    'shall [iI] '
    'do you prefer'
    'can you confirm'
    'is that (okay|ok|alright)'
    'let me know if'
    'please (confirm|advise|let me know)'
    'your (preference|thoughts|input)'
    'waiting for.*(input|response|feedback)'
)

# Load additional patterns from file if configured
if [[ -n "${CC_NO_ASK_PATTERNS_FILE:-}" && -f "${CC_NO_ASK_PATTERNS_FILE}" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" && "$line" != \#* ]] && PATTERNS+=("$line")
    done < "${CC_NO_ASK_PATTERNS_FILE}"
fi

# Check text against patterns
MATCHED=""
for pattern in "${PATTERNS[@]}"; do
    if echo "$TEXT" | grep -qiE "$pattern"; then
        MATCHED="$pattern"
        break
    fi
done

if [[ -n "$MATCHED" ]]; then
    echo ""
    echo "REMINDER: You are operating autonomously. Do not ask the user questions."
    echo "  Detected pattern: \"${MATCHED}\""
    echo "  Decision framework:"
    echo "    1. Technical choices → pick the standard/conventional option"
    echo "    2. Implementation details → follow existing code conventions"
    echo "    3. Ambiguous specs → follow common industry practices"
    echo "    4. Errors → investigate and fix (up to 3 attempts)"
    echo "  If truly blocked, document the blocker and move to the next task."
fi

exit 0
