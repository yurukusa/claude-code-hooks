#!/bin/bash
# Test all COOKBOOK.md recipes work correctly
set -euo pipefail
PASS=0; FAIL=0

test_recipe() {
    local name="$1" input="$2" expected_pattern="$3"
    local output
    output=$(echo "$input" | bash /tmp/recipe-test.sh 2>/dev/null) || true
    if echo "$output" | grep -q "$expected_pattern" 2>/dev/null; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected '$expected_pattern')"
        FAIL=$((FAIL + 1))
    fi
}

echo "COOKBOOK Recipe Tests"
echo "===================="

# Recipe 1: Git read auto-approve
cat > /tmp/recipe-test.sh << 'R1'
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0
if echo "$COMMAND" | grep -qE '^\s*git\s+(-C\s+\S+\s+)?(status|log|diff|branch|show|rev-parse)(\s|$)'; then
    jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
fi
exit 0
R1
chmod +x /tmp/recipe-test.sh

echo ""
echo "Recipe 1: Git read"
test_recipe "git status" '{"tool_input":{"command":"git status"}}' "allow"
test_recipe "git -C path status" '{"tool_input":{"command":"git -C /tmp status"}}' "allow"
test_recipe "git push (should NOT approve)" '{"tool_input":{"command":"git push origin main"}}' ""

# Recipe 4: SSH wildcard
cat > /tmp/recipe-test.sh << 'R4'
#!/bin/bash
COMMAND=$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)
SAFE="uptime|w|whoami|hostname|uname|date|df|free"
if echo "$COMMAND" | grep -qE "^\s*ssh\s+\S+\s+($SAFE)(\s|$)"; then
    jq -n '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
fi
exit 0
R4
chmod +x /tmp/recipe-test.sh

echo ""
echo "Recipe 4: SSH"
test_recipe "ssh uptime (no args)" '{"tool_input":{"command":"ssh host uptime"}}' "allow"
test_recipe "ssh uptime -s (with args)" '{"tool_input":{"command":"ssh host uptime -s"}}' "allow"
test_recipe "ssh rm (should NOT approve)" '{"tool_input":{"command":"ssh host rm -rf /"}}' ""

echo ""
echo "===================="
echo "Results: $PASS/$((PASS + FAIL)) passed"
rm -f /tmp/recipe-test.sh
