# Changelog

## 2.0.0 — 2026-02-28

Major expansion: from 8 hooks to 10 hooks + 5 operational templates. Now covers 18 of 20 cc-health-check checks.

### New hooks:
- **branch-guard.sh** — PreToolUse hook that blocks `git push` to main/master branches. Configurable via `CC_PROTECT_BRANCHES`
- **error-gate.sh** — PreToolUse hook that blocks external actions (push, publish, POST) when unresolved errors exist. Configurable via `CC_ERROR_LOG` and `CC_ERROR_THRESHOLD`

### New templates:
- **CLAUDE-autonomous.md** — Operational rules for autonomous execution: backup branches, loop detection, decision autonomy, state persistence, output verification
- **dod-checklists.md** — Definition of Done checklists for code changes, publications, general tasks, and session handoffs
- **task-queue.yaml** — Structured task queue with priority, status tracking, blocked items, and completion history
- **mission.md** — Persistent state template for cross-session continuity: goals, progress, blockers, handoff notes
- **LESSONS.md** — Structured incident log format: what failed, root cause, fix applied, prevention rule

### Updated:
- Example settings files now include branch-guard.sh and error-gate.sh
- README rewritten with health check coverage mapping table

---

## 1.0.0 — 2026-02-28

Initial release. All hooks extracted from a production autonomous Claude Code system with 108 hours of runtime.

### Hooks included:
- **context-monitor.sh** — Context window capacity monitoring with graduated warnings
- **activity-logger.sh** — JSONL audit trail for all file changes
- **syntax-check.sh** — Automatic post-edit syntax validation (Python, Shell, JSON, YAML, JS, TS)
- **decision-warn.sh** — Non-blocking alerts for edits to monitored paths
- **cdp-safety-check.sh** — Chrome DevTools Protocol safety guard
- **proof-log-session.sh** — Automatic 5W1H session summary generation
- **session-start-marker.sh** — Session start time recording
- **no-ask-human.sh** — Autonomous decision enforcement for unattended operation

### Example configurations:
- `settings.json` — Recommended full setup
- `settings-minimal.json` — Context monitor + syntax check only
- `settings-autonomous.json` — Full autonomous mode with question detection
