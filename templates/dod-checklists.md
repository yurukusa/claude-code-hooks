# Definition of Done Checklists

Use these checklists before marking any task complete.

## Code Change DoD

- [ ] Syntax is clean (no linting/parse errors)
  - Python: `python -m py_compile <file>`
  - GDScript: `godot --headless --check-only`
  - JavaScript: `node -c <file>` or `npm run lint`
- [ ] All modified files committed with descriptive message
- [ ] No commented-out code left in
- [ ] No hardcoded debug values
- [ ] Related tests pass (if applicable)
- [ ] LESSONS.md updated with any errors encountered and fixes applied
- [ ] Changes do not break existing functionality (manual check or test)

## Publication/External Push DoD

- [ ] Target URL verified (GET request or manual load)
- [ ] Content appears correctly (screenshot taken if visual)
- [ ] manifest.yaml or equivalent updated with new URL/metadata
- [ ] If posting to multiple platforms, verify each one
- [ ] No sensitive information exposed (email, credentials, PII)
- [ ] Commit created documenting the publish action
- [ ] `mission.md` updated with publication result and proof link

## General Task DoD

- [ ] Current goal achieved (meets task description)
- [ ] Changes committed (if code/files modified)
- [ ] `mission.md` updated with completion details
- [ ] `task-queue.yaml` status updated to `done` with date
- [ ] LESSONS.md updated if this was a fix or learning moment
- [ ] Blocked items cleared or documented with `blocked_reason`
- [ ] Next task identified and status updated to `in-progress`

## Session Handoff DoD

Before ending a session:

- [ ] `mission.md` updated with current state
- [ ] In-progress tasks have clear context/next steps noted
- [ ] Blocked items have `blocked_reason` filled in
- [ ] `task-queue.yaml` sorted by priority (highest first)
- [ ] No uncommitted changes in git (or explicitly stashed with reason)
- [ ] Recent commits have clear messages explaining "why"

---

*If any item fails, fix it before declaring the task done. Incomplete tasks go back to task-queue.yaml with status: `in-progress` and notes on where to resume.*
