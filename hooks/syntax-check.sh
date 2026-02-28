#!/bin/bash
# ================================================================
# syntax-check.sh — Automatic Syntax Validation After Edits
# ================================================================
# PURPOSE:
#   Runs syntax checks immediately after Claude Code edits or
#   writes a file. Catches syntax errors before they propagate
#   into downstream failures.
#
# SUPPORTED LANGUAGES:
#   .py    — python -m py_compile
#   .sh    — bash -n
#   .bash  — bash -n
#   .json  — jq empty
#   .yaml  — python3 yaml.safe_load (if PyYAML installed)
#   .yml   — python3 yaml.safe_load (if PyYAML installed)
#   .js    — node --check (if node installed)
#   .ts    — npx tsc --noEmit (if tsc available) [EXPERIMENTAL]
#
# TRIGGER: PostToolUse
# MATCHER: "Edit|Write"
#
# DESIGN PHILOSOPHY:
#   - Never blocks (always exit 0) — reports errors but doesn't
#     prevent the edit from completing
#   - Silent on success — only speaks up when something is wrong
#   - Fails open — if a checker isn't installed, silently skips
#
# BORN FROM:
#   Countless sessions where Claude Code introduced a syntax error,
#   continued working for 10+ tool calls, then hit a wall when
#   trying to run the broken file. Catching it immediately saves
#   context window and frustration.
# ================================================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# No file path = nothing to check
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    exit 0
fi

EXT="${FILE_PATH##*.}"

case "$EXT" in
    py)
        if python3 -m py_compile "$FILE_PATH" 2>&1; then
            :  # silent on success
        else
            echo "SYNTAX ERROR (Python): $FILE_PATH" >&2
        fi
        ;;
    sh|bash)
        if bash -n "$FILE_PATH" 2>&1; then
            :
        else
            echo "SYNTAX ERROR (Shell): $FILE_PATH" >&2
        fi
        ;;
    json)
        if command -v jq &>/dev/null; then
            if jq empty "$FILE_PATH" 2>&1; then
                :
            else
                echo "SYNTAX ERROR (JSON): $FILE_PATH" >&2
            fi
        fi
        ;;
    yaml|yml)
        if python3 -c "import yaml" 2>/dev/null; then
            if python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    yaml.safe_load(f)
" "$FILE_PATH" 2>&1; then
                :
            else
                echo "SYNTAX ERROR (YAML): $FILE_PATH" >&2
            fi
        fi
        ;;
    js)
        if command -v node &>/dev/null; then
            if node --check "$FILE_PATH" 2>&1; then
                :
            else
                echo "SYNTAX ERROR (JavaScript): $FILE_PATH" >&2
            fi
        fi
        ;;
    ts)
        # EXPERIMENTAL: TypeScript check requires tsc in PATH
        if command -v npx &>/dev/null; then
            if npx tsc --noEmit "$FILE_PATH" 2>&1; then
                :
            else
                echo "SYNTAX ERROR (TypeScript) [experimental]: $FILE_PATH" >&2
            fi
        fi
        ;;
    *)
        # Unknown extension — skip silently
        ;;
esac

exit 0
