#!/bin/bash
# ================================================================
# secret-output-guard.sh — Credential Leak Prevention (stdout/transcript)
# ================================================================
# PURPOSE:
#   Companion to secret-guard.sh. Where secret-guard.sh stops secrets being
#   *committed* (git add .env / *.pem), this stops a credential VALUE being
#   *printed* — i.e. read and echoed into the command output, which for an AI
#   agent means straight into the conversation transcript.
#
#   This is a real and easy leak: reading a token "just to check it" prints it.
#       pass show github/token | head        # the token is now in the transcript
#       gh auth token                         # prints the token
#       echo "$(pass show api/key)"           # prints the token
#   secret-guard.sh does not catch these (they are not `git add`).
#
# TRIGGER: PreToolUse
# MATCHER: "Bash"
#
# WHAT IT BLOCKS (exit 2):
#   - `pass show <name>` / `pass <user>/<entry>` whose output is not captured
#     or redirected (bare, or piped to a printer like head/cat/tee)
#   - `gh auth token` printed to stdout
#   - a credential-read substitution fed to echo/printf/cat/tee/…:
#       echo $(pass show X) ,  printf ... $(gh auth token)
#   - a literal credential in the command text:
#       ghp_… / gho_… / github_pat_… / glpat-… / xox[bp]-… / AKIA… / PRIVATE KEY
#
# WHAT IT ALLOWS (exit 0):
#   - TOK=$(pass show <name>)            # captured into a variable, not printed
#   - pass show <name> >/dev/null        # redirected (e.g. warm a gpg-agent)
#   - pass show <name> > file            # written to a file, not the transcript
#   - pass insert / pass ls / pass git   # not a value read
#   - curl -H "Authorization: token $(pass show <name>)"   # token -> request
#
# CONFIGURATION:
#   CC_SECRET_OUTPUT_OK=1  — prefix a command with this to bypass (audited).
# ================================================================
set -u

INPUT=$(cat 2>/dev/null)
[ -z "$INPUT" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Audited override.
echo "$COMMAND" | grep -q 'CC_SECRET_OUTPUT_OK=1' && exit 0

READ='pass[[:space:]]+show([[:space:]]|$)|pass[[:space:]]+[A-Za-z0-9_.@-]+/|gh[[:space:]]+auth[[:space:]]+token([[:space:]]|$)'

block() {
    {
        echo "BLOCKED: $1"
        echo ""
        echo "A credential value would be printed into the command output/transcript."
        echo "Capture it instead of printing it:"
        echo "  TOK=\$(pass show <name>) ; use \"\$TOK\"   # captured, never printed"
        echo "  pass show <name> >/dev/null              # redirect (just warm the agent)"
        echo ""
        echo "Audited bypass: prefix the command with CC_SECRET_OUTPUT_OK=1"
    } >&2
    exit 2
}

# 1) Literal credential pasted into the command text.
if echo "$COMMAND" | grep -Eq '(gh[pousr]|ghu)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{18,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
    block "command text contains a literal credential/token."
fi

# 2) Credential-read substitution fed to a command that prints to stdout.
if echo "$COMMAND" | grep -Eq '\b(echo|printf|print|cat|tee|head|tail|xxd|od|base64|hexdump)\b[^|;&]*(\$\(|`)[^)`]*('"$READ"')'; then
    block "a secret read is piped into a command that prints to stdout."
fi

# 3) Bare / piped credential-read that is neither captured nor redirected.
#    Strip command substitutions; a read left in the remainder runs to stdout.
BARE=$(echo "$COMMAND" | sed -E 's/\$\([^)]*\)//g; s/`[^`]*`//g')
if echo "$BARE" | grep -Eq "$READ"; then
    if echo "$BARE" | grep -Eq '>[[:space:]]*/dev/null|>>?[[:space:]]*[^|&[:space:]]'; then
        : # redirected off the transcript (to /dev/null or a file) — allow
    else
        block "a secret read (pass show / pass <path> / gh auth token) prints to stdout."
    fi
fi

exit 0
