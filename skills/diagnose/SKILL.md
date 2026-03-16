---
name: diagnose
description: Diagnose your Claude Code hooks setup. Checks which hooks are active, verifies permissions, and identifies common configuration issues.
---

# Diagnose Claude Code Hooks

Run a diagnostic check on the user's Claude Code hooks setup.

## Checks to perform

1. **Hook files exist and are executable**
   ```bash
   for hook in context-monitor.sh syntax-check.sh activity-logger.sh branch-guard.sh decision-warn.sh cdp-safety-check.sh error-gate.sh no-ask-human.sh proof-log-session.sh session-start-marker.sh; do
     if [ -f "${CLAUDE_PLUGIN_ROOT}/hooks/$hook" ]; then
       if [ -x "${CLAUDE_PLUGIN_ROOT}/hooks/$hook" ]; then
         echo "OK: $hook (executable)"
       else
         echo "WARN: $hook exists but not executable"
       fi
     else
       echo "MISSING: $hook"
     fi
   done
   ```

2. **Dependencies available**
   - `jq` — required by most hooks
   - `python3` — required by activity-logger, proof-log, context-monitor
   - `node` — optional, for JS syntax checking

3. **Environment variables**
   - Check if CC_ACTIVITY_LOG, CC_PROOF_LOG_DIR, CC_CONTEXT_MISSION_FILE are set
   - Report defaults if not set

4. **Settings.json integration**
   - Check `~/.claude/settings.json` for hook entries
   - Report which hooks are wired and which are missing

5. **Recent activity**
   - Check if activity log exists and has recent entries
   - Check if proof-log directory has recent session logs

## Output format

Present results as a health report:
```
=== Claude Code Hooks Health Check ===
Hooks:     8/10 active
Deps:      jq ✓  python3 ✓  node ✓
Env:       3/5 configured
Activity:  Last entry 2h ago
Overall:   HEALTHY (2 warnings)
```

List any warnings or errors with actionable fix instructions.
