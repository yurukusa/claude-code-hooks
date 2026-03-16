---
name: setup
description: Set up claude-code-hooks for your project. Guides you through choosing which hooks to enable and configuring environment variables.
---

# Claude Code Hooks Setup

You are helping the user set up production safety hooks for Claude Code.

## Available Hooks

| Hook | Purpose | Event | Matcher |
|------|---------|-------|---------|
| context-monitor.sh | Context window warnings (40% → 25% → 20% → 15%) | PostToolUse | all |
| activity-logger.sh | JSONL audit trail of file changes | PostToolUse | Edit\|Write |
| syntax-check.sh | Auto syntax validation after edits | PostToolUse | Edit\|Write |
| decision-warn.sh | Alerts on edits to sensitive paths | PreToolUse | Edit\|Write |
| cdp-safety-check.sh | Blocks raw WebSocket CDP construction | PreToolUse | Bash |
| proof-log-session.sh | 5W1H session summaries | Stop, PreCompact | all |
| session-start-marker.sh | Records session start time | PostToolUse | all |
| no-ask-human.sh | Blocks questions during autonomous operation | PostToolUse | all |
| branch-guard.sh | Blocks pushes to main/master | PreToolUse | Bash |
| error-gate.sh | Blocks external actions when errors exist | PreToolUse | Bash |

## Setup Profiles

### Minimal (recommended for beginners)
- context-monitor.sh + syntax-check.sh
- Catches the two most common failure modes

### Standard (recommended for most users)
- All of minimal + activity-logger.sh + branch-guard.sh + decision-warn.sh + proof-log-session.sh + session-start-marker.sh
- Good balance of safety and visibility

### Autonomous (for unattended operation)
- All hooks enabled including no-ask-human.sh and error-gate.sh
- Maximum safety for headless/autonomous Claude Code sessions

## Steps

1. Ask which profile the user wants (or let them pick individual hooks)
2. The plugin's hooks.json already configures the autonomous profile by default
3. Help configure environment variables if needed:
   - `CC_CONTEXT_MISSION_FILE` — path to mission.md (default: `$HOME/mission.md`)
   - `CC_ACTIVITY_LOG` — path to activity log (default: `$HOME/claude-activity-log.jsonl`)
   - `CC_MONITORED_DIRS` — colon-separated paths for decision-warn (default: `$HOME/bin:$HOME/.claude/hooks`)
   - `CC_PROTECT_BRANCHES` — colon-separated branch names (default: `main:master`)
   - `CC_ERROR_LOG` — path to error tracker (default: `$HOME/.claude/error-tracker.log`)
   - `CC_PROOF_LOG_DIR` — path to proof logs (default: `$HOME/proof-log`)
4. Verify the setup works by running a quick test
