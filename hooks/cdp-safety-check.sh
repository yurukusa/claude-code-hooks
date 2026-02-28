#!/bin/bash
# ================================================================
# cdp-safety-check.sh — Chrome DevTools Protocol Safety Guard
# ================================================================
# PURPOSE:
#   Prevents Claude Code from constructing raw WebSocket CDP
#   connections, which are fragile and fail repeatedly. Forces
#   use of established CDP tools (like cdp-eval) instead.
#
#   Also detects dangerous browser navigation patterns that can
#   cause CDP timeouts (e.g., window.location.href assignments
#   that trigger beforeunload dialogs).
#
# TRIGGER: PreToolUse
# MATCHER: "Bash"
#
# WHAT IT BLOCKS (exit 1):
#   - Raw WebSocket construction (ClientWebSocket, System.Net.WebSockets)
#   - Direct devtools/page/ WebSocket URL usage
#   - window.location direct navigation (causes beforeunload timeout)
#
# WHAT IT ALLOWS:
#   - Commands that go through your CDP tool (configure CDP_TOOL_NAME)
#   - Any Bash command that doesn't touch CDP
#
# CONFIGURATION:
#   CC_CDP_TOOL_NAME — name of your CDP tool binary
#     default: "cdp-eval"
#     The hook will allow commands that reference this tool name.
#
# BORN FROM:
#   6 consecutive failures trying to update a Zenn article using
#   hand-written PowerShell WebSocket code. Each attempt wasted
#   context window. The existing cdp-eval tool worked first try.
#
# NOTE: If you don't use Chrome DevTools Protocol automation,
#   this hook is harmless — it will exit 0 for all non-CDP commands.
#   But if you DO use CDP, this hook will save you from the single
#   most common failure mode: reinventing the wheel badly.
# ================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

CDP_TOOL="${CC_CDP_TOOL_NAME:-cdp-eval}"

# --- Block: Raw WebSocket CDP construction ---
if echo "$COMMAND" | grep -qiE 'ClientWebSocket|System\.Net\.WebSockets|WebSocketDebuggerUrl' ; then
    # Allow if going through the designated CDP tool
    if echo "$COMMAND" | grep -qE "${CDP_TOOL}" ; then
        : # allowed
    else
        echo "BLOCKED: Raw WebSocket CDP construction detected." >&2
        echo "" >&2
        echo "Use your CDP tool (${CDP_TOOL}) instead of building raw WebSocket connections." >&2
        echo "" >&2
        echo "Why: Raw WebSocket CDP code fails repeatedly due to connection" >&2
        echo "     timing, tab targeting, and protocol version issues." >&2
        echo "     A proven tool handles all of this." >&2
        exit 1
    fi
fi

# --- Block: Direct devtools/page/ URL construction ---
if echo "$COMMAND" | grep -qE 'ws://localhost:[0-9]+/devtools/page/' ; then
    if echo "$COMMAND" | grep -qE "${CDP_TOOL}" ; then
        : # tool-mediated is OK
    else
        echo "BLOCKED: Direct devtools/page/ WebSocket URL usage." >&2
        echo "Use ${CDP_TOOL} with a tab ID flag instead." >&2
        exit 1
    fi
fi

# --- Block: window.location direct navigation ---
if echo "$COMMAND" | grep -qiE 'window\.location\.(href|replace|assign)|location\.href\s*=' ; then
    if echo "$COMMAND" | grep -qE "${CDP_TOOL}" ; then
        exit 0  # tool-mediated navigation is OK
    fi
    echo "BLOCKED: Direct window.location navigation detected." >&2
    echo "This triggers beforeunload dialogs that cause CDP timeouts." >&2
    echo "Use your CDP tool to execute navigation JS instead." >&2
    exit 1
fi

exit 0
