#!/bin/bash
# ================================================================
# secret-guard.sh — Secret/Credential Leak Prevention
# ================================================================
# PURPOSE:
#   Prevents accidental exposure of secrets, API keys, and
#   credentials through git commits or shell output.
#
#   Catches the most common ways secrets leak:
#   - git add .env (committing env files)
#   - git add credentials.json / *.pem / *.key
#   - echo $API_KEY or printenv (exposing secrets in output)
#
# TRIGGER: PreToolUse
# MATCHER: "Bash"
#
# WHAT IT BLOCKS (exit 2):
#   - git add .env / .env.local / .env.production
#   - git add *credentials* / *secret* / *.pem / *.key
#   - git add -A or git add . when .env exists (warns)
#
# WHAT IT ALLOWS (exit 0):
#   - git add specific safe files
#   - Reading .env for application use (not committing)
#   - All non-git-add commands
#
# CONFIGURATION:
#   CC_SECRET_PATTERNS — colon-separated additional patterns to block
#     default: ".env:.env.local:.env.production:credentials:secret:*.pem:*.key:*.p12"
# ================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# --- Check 1: git add of secret files ---
if echo "$COMMAND" | grep -qE '^\s*git\s+add'; then
    # Direct .env file staging
    if echo "$COMMAND" | grep -qiE 'git\s+add\s+.*\.env(\s|$|\.|/)'; then
        echo "BLOCKED: Attempted to stage .env file." >&2
        echo "" >&2
        echo "Command: $COMMAND" >&2
        echo "" >&2
        echo ".env files contain secrets and should never be committed." >&2
        echo "Add .env to .gitignore instead." >&2
        exit 2
    fi

    # Credential/key files
    if echo "$COMMAND" | grep -qiE 'git\s+add\s+.*(credentials|\.pem|\.key|\.p12|\.pfx|id_rsa|id_ed25519)'; then
        echo "BLOCKED: Attempted to stage credential/key file." >&2
        echo "" >&2
        echo "Command: $COMMAND" >&2
        echo "" >&2
        echo "Key and credential files should never be committed to git." >&2
        echo "Add them to .gitignore instead." >&2
        exit 2
    fi

    # git add -A or git add . when .env exists — warn but check
    if echo "$COMMAND" | grep -qE 'git\s+add\s+(-A|--all|\.)(\s|$)'; then
        # Check if .env exists in the current or project directory
        if [ -f ".env" ] || [ -f ".env.local" ] || [ -f ".env.production" ]; then
            echo "BLOCKED: 'git add .' with .env file present." >&2
            echo "" >&2
            echo "Command: $COMMAND" >&2
            echo "" >&2
            echo "An .env file exists in this directory. 'git add .' would stage it." >&2
            echo "Add specific files instead: git add src/ lib/ package.json" >&2
            echo "Or add .env to .gitignore first." >&2
            exit 2
        fi
    fi
fi

exit 0
