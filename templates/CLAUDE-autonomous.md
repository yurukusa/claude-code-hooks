# Claude Code Autonomous Operation Guidelines

Operational rules for Claude Code to function without human approval gates.

## Safety Rules

### Backup Before Risk
Before any destructive operation (reset, force push, branch delete, rm -rf):
```bash
git checkout -b backup/before-changes-$(date +%Y%m%d-%H%M%S)
```
Keep this branch for rollback. Never delete backup branches.

### Loop Detection
If the same error occurs 3 consecutive times:
1. Stop execution
2. Log the error to `LESSONS.md`
3. Add preventive rule to this file or workflow
4. Move task to "blocked" in `mission.md`
Do not retry the same failing command 4+ times.

### State Persistence
Maintain `mission.md` across session restarts:
- Current goal (1-2 sentences)
- In-progress tasks (with context)
- Completed tasks (what changed)
- Blocked items (reason, next steps)

Update before session ends or after major changes.

## Decision Rules

### No Questions — Decide & Execute
Never output "How should I...?" or "Should I...?". Instead:
- Apply standard conventions (existing codebase style)
- Choose the most common/least risky option
- Execute and report results
- Log decision in `LESSONS.md` if non-obvious

**Exception**: Security risk, monetary cost, irreversible data loss, external push/publish.

### Task Queue
At session start:
1. Read `task-queue.yaml`
2. Pick highest priority task with status: `pending`
3. Update status to `in-progress`
4. After completion, set status to `done` with date

If blocked, update with `blocked_reason` and move next task.

## Quality Gates

### Before Marking Done
Check `dod-checklists.md`:
- [ ] Code syntax clean (python -m py_compile, godot --headless --check-only)
- [ ] Tests pass or manual verification done
- [ ] Changes committed with "why" in message
- [ ] LESSONS.md updated if this was a fix
- [ ] `mission.md` updated with results

If any fail, fix before reporting completion.

### Output Verification
After publishing (push, POST request, screenshot):
- Verify with GET request or screenshot
- Confirm the change actually appeared
- Attach proof to `mission.md` or task notes
Never trust the POST response alone.

### Lesson Capture
When you fix an error:
1. Record in `LESSONS.md`: date, what failed, root cause, fix applied, prevention rule
2. Example:
   ```markdown
   ### 2026-02-28 | Python import error in config.py
   - **What**: `ModuleNotFoundError: No module named 'requests'`
   - **Root**: venv not activated before running script
   - **Fix**: Added shebang `#!/usr/bin/env python3` + venv check in main()
   - **Prevention**: Always check venv in startup scripts
   ```

## Workflow

1. **Start**: Check `mission.md` for context from last session
2. **Plan**: If task is non-trivial (3+ steps, design decision), write plan in `mission.md` before coding
3. **Execute**: Follow dod-checklists.md for quality gates
4. **Verify**: Screenshot/GET request for external changes
5. **Document**: Update `mission.md`, `task-queue.yaml`, `LESSONS.md`
6. **Commit**: Commit with message explaining "why"

## Blocked / Waiting

If you hit a wall:
- Try once more with different approach
- If still blocked, log to `mission.md` with `blocked_reason`
- Attach context needed for human to unblock
- Move to next highest-priority task
- Do not spin retry loops

## Git Commits

- **Frequency**: After each logical change
- **Message format**:
  ```
  Brief title explaining why (not what)

  - Detail about what changed
  - Why this approach over alternatives
  ```
- **Never skip hooks**: `--no-verify`, `--no-gpg-sign` forbidden
- **Never amend existing commits**: Create new commit instead

---

*For issues with these guidelines, update this file and commit the change.*
