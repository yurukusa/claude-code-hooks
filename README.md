# claude-code-hooks

**10 hooks + 5 templates from 108 hours of autonomous Claude Code operation.**

Production infrastructure for running Claude Code autonomously. Every hook exists because something went wrong without it. Every template encodes a workflow pattern that survived real-world autonomous operation.

> **Honest disclaimer:** This is what works for us. Your workflow may differ. These hooks and templates address the failure modes we actually encountered.

Covers **18 of 20 checks** in [cc-health-check](https://github.com/yurukusa/cc-health-check).

---

## What's Included

### Hooks (10)

| Hook | Purpose | Trigger |
|------|---------|---------|
| `context-monitor.sh` | Graduated context window warnings (CAUTION → WARNING → CRITICAL → EMERGENCY) | PostToolUse |
| `activity-logger.sh` | JSONL audit trail of every file change (path, lines added/deleted, timestamp) | PostToolUse (Edit\|Write) |
| `syntax-check.sh` | Automatic syntax validation after edits (Python, Shell, JSON, YAML, JS) | PostToolUse (Edit\|Write) |
| `decision-warn.sh` | Alerts on edits to sensitive paths without blocking | PreToolUse (Edit\|Write) |
| `cdp-safety-check.sh` | Blocks raw WebSocket CDP construction, forces use of proven tools | PreToolUse (Bash) |
| `proof-log-session.sh` | Auto-generates 5W1H session summaries into daily markdown files | Stop, PreCompact |
| `session-start-marker.sh` | Records session start time (used by proof-log) | PostToolUse |
| `no-ask-human.sh` | Detects and discourages questions to absent humans during autonomous operation | PostToolUse |
| `branch-guard.sh` | Blocks pushes to main/master branches without review | PreToolUse (Bash) |
| `error-gate.sh` | Blocks external actions (push, publish, POST) when unresolved errors exist | PreToolUse (Bash) |

### Templates (5)

| Template | Purpose |
|----------|---------|
| `CLAUDE-autonomous.md` | Operational rules for autonomous execution: backup branches, loop detection, decision autonomy, state persistence |
| `dod-checklists.md` | Definition of Done for code changes, publications, general tasks, and session handoffs |
| `task-queue.yaml` | Structured task queue with priority, status tracking, and blocked items |
| `mission.md` | Persistent state across session restarts: goals, progress, blockers, handoff notes |
| `LESSONS.md` | Structured incident log: what failed, root cause, fix applied, prevention rule |

### Example Configurations (3)

- `settings-minimal.json` — Context monitor + syntax check. Good starting point.
- `settings.json` — Recommended setup with all core hooks.
- `settings-autonomous.json` — Full autonomous mode with no-ask-human + branch guard + error gate.

---

## Health Check Coverage

How the kit maps to [cc-health-check](https://github.com/yurukusa/cc-health-check)'s 20 checks:

| Dimension | Check | Covered By |
|-----------|-------|-----------|
| Safety | PreToolUse blocks dangerous commands | `cdp-safety-check.sh` |
| Safety | API keys in dedicated files | `CLAUDE-autonomous.md` |
| Safety | Branch protection | `branch-guard.sh` |
| Safety | Error-aware gate | `error-gate.sh` |
| Quality | Syntax checks after edits | `syntax-check.sh` |
| Quality | Error detection and tracking | `error-gate.sh` + `activity-logger.sh` |
| Quality | Definition of Done checklist | `dod-checklists.md` |
| Quality | Output verification | `CLAUDE-autonomous.md` + `dod-checklists.md` |
| Monitoring | Context window alerts | `context-monitor.sh` |
| Monitoring | Activity logging | `activity-logger.sh` |
| Monitoring | Daily summaries | `proof-log-session.sh` |
| Recovery | Backup branches | `CLAUDE-autonomous.md` |
| Recovery | Watchdog for hangs/idle | *(requires external tmux script)* |
| Recovery | Loop detection | `CLAUDE-autonomous.md` |
| Autonomy | Task queue | `task-queue.yaml` |
| Autonomy | Block unnecessary questions | `no-ask-human.sh` |
| Autonomy | Persistent state | `mission.md` |
| Coordination | Decision audit trail | `decision-warn.sh` |
| Coordination | Multi-agent coordination | *(requires external tooling)* |
| Coordination | Lesson capture | `LESSONS.md` |

**18/20 covered.** The 2 uncovered checks (watchdog, multi-agent) require external tooling beyond hooks and templates.

---

## Quick Setup

### 1. Copy hooks and templates

```bash
# Hooks
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# Templates (copy what you need to your project)
cp templates/CLAUDE-autonomous.md ~/CLAUDE.md          # or append to existing
cp templates/dod-checklists.md ~/.claude/
cp templates/task-queue.yaml ~/ops/
cp templates/mission.md ~/ops/
cp templates/LESSONS.md ~/
```

### 2. Wire hooks into settings.json

Open `~/.claude/settings.json` and add the hooks configuration. Use one of the example files as a starting point:

```bash
cat examples/settings-autonomous.json
```

Then copy the `"hooks"` section into your own settings file, replacing `/path/to/hooks/` with your actual path.

**Minimal example** (context monitor + syntax check only):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/context-monitor.sh" }]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/syntax-check.sh" }]
      }
    ]
  }
}
```

### 3. Verify

Start a Claude Code session and make an edit. You should see syntax check output (on error) and context monitoring messages (when context drops below thresholds).

---

## Hook Details

### context-monitor.sh

**The most valuable hook in this collection.**

Monitors remaining context window capacity. Falls back to tool-call-count estimation when debug logs are unavailable.

**Why it exists:** We lost an entire session's work when context hit 3% with no warning.

**Thresholds:** 40% CAUTION → 25% WARNING → 20% CRITICAL (auto-compact) → 15% EMERGENCY

### activity-logger.sh

Records every Edit/Write operation to JSONL with timestamp, file path, and line counts.

**Why it exists:** "What did Claude Code do in the last 2 hours?" needs an instant answer.

### syntax-check.sh

Runs syntax validation immediately after Claude Code edits a file. Supports Python, Shell, JSON, YAML, JS.

**Why it exists:** Claude Code would introduce a syntax error, continue working for 10+ steps, then hit a wall.

### branch-guard.sh

Blocks `git push` to main/master. Allows pushes to feature/staging branches.

**Why it exists:** One accidental force-push to main destroyed a day of work.

**Config:** `CC_PROTECT_BRANCHES="main:master:production"` (default: `main:master`)

### error-gate.sh

Blocks external actions (git push, npm publish, curl POST) when unresolved errors exist in the error log. Allows local operations.

**Why it exists:** Publishing broken code to production while errors were unresolved.

**Config:** `CC_ERROR_LOG` (default: `~/.claude/error-tracker.log`), `CC_ERROR_THRESHOLD` (default: `WARNING`)

### decision-warn.sh

Non-blocking alerts when Claude Code edits files in monitored directories.

### cdp-safety-check.sh

Blocks raw Chrome DevTools Protocol WebSocket construction. Forces use of established tools.

### proof-log-session.sh

Generates 5W1H session summary at session end. Aggregates from activity-logger.sh.

### session-start-marker.sh

Records session start timestamp. Used by proof-log for duration calculation.

### no-ask-human.sh

Detects question patterns and reminds the agent to decide autonomously. Essential for unattended operation.

---

## Environment Variables

| Variable | Used By | Default |
|----------|---------|---------|
| `CC_CONTEXT_MISSION_FILE` | context-monitor | `$HOME/mission.md` |
| `CC_ACTIVITY_LOG` | activity-logger, proof-log | `$HOME/claude-activity-log.jsonl` |
| `CC_MONITORED_PATHS` | activity-logger | *(none)* |
| `CC_MONITORED_DIRS` | decision-warn | `$HOME/bin:$HOME/.claude/hooks` |
| `CC_CDP_TOOL_NAME` | cdp-safety-check | `cdp-eval` |
| `CC_PROOF_LOG_DIR` | proof-log | `$HOME/proof-log` |
| `CC_NO_ASK_ENABLED` | no-ask-human | `1` |
| `CC_PROTECT_BRANCHES` | branch-guard | `main:master` |
| `CC_ERROR_LOG` | error-gate | `$HOME/.claude/error-tracker.log` |
| `CC_ERROR_THRESHOLD` | error-gate | `WARNING` |

---

## Requirements

- **Claude Code** (with hooks support)
- **bash** + **jq**
- **python3** (used by activity-logger, proof-log, context-monitor)
- **Optional:** PyYAML (YAML syntax checking), Node.js (JS syntax checking)

---

## Related Tools

| Tool | What it does |
|------|-------------|
| [cc-health-check](https://github.com/yurukusa/cc-health-check) | Diagnose your setup — find what's missing |
| [cc-session-stats](https://github.com/yurukusa/cc-session-stats) | How much are you using AI? |
| [cc-audit-log](https://github.com/yurukusa/cc-audit-log) | What did your AI do? |
| [cc-roast](https://yurukusa.github.io/cc-roast/) | Your CLAUDE.md, brutally reviewed |
| **claude-code-hooks** | Fix what's missing — hooks and templates |

Run cc-health-check first to see your score, then use this kit to fix what's missing.

---

## License

MIT License.
