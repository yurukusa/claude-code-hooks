# Lessons Learned

Record errors, fixes, and prevention rules. Build a playbook of what you've learned.

## Format

Each entry captures an incident, not assumptions.

```markdown
### YYYY-MM-DD | Problem Title
- **What**: What error or issue occurred?
- **Root**: Why did it happen? (investigation findings)
- **Fix**: What solution was applied?
- **Prevention**: What rule/check will prevent this in future?
```

---

## Examples

### 2026-02-28 | Python venv not activated during script execution
- **What**: `ModuleNotFoundError: No module named 'requests'` when running data processor
- **Root**: Script started without activating Python virtual environment. Dependencies installed only in venv, not system Python
- **Fix**: Added venv check at script startup + explicit shebang `#!/usr/bin/env python3` with venv activation in wrapper
- **Prevention**:
  - All Python scripts must include venv activation in their startup routine
  - Never assume `python3` has dependencies installed
  - Test script invocation from clean shell before committing

### 2026-02-28 | API POST succeeded but data didn't appear
- **What**: POST request returned 200 OK, but fetching the resource with GET returned 404
- **Root**: API handler had bug—it returned success but didn't actually write to database. Only discovered via GET verification
- **Fix**:
  - Fixed database write logic in handler
  - Added automated POST→GET verification in test suite
- **Prevention**:
  - Always verify external changes with GET/screenshot after every POST/publish
  - Never trust HTTP response code alone
  - Add "verify after publish" to dod-checklists.md for external operations

---

## Common Patterns to Watch

Add these as you discover them in your project:

- [Pattern 1]: [What to watch for]
- [Pattern 2]: [Symptom and check]

---

## How to Use This File

1. **During troubleshooting**: Read this file for similar issues. If found, apply the same prevention rule
2. **After fixing a bug**: Add an entry so the next session learns from it
3. **Loop detection**: If same error appears 3 times, escalate and update prevention rules
4. **Onboarding**: New team members read this to avoid known pitfalls

---

## Rule Updates

As you discover new patterns, update `CLAUDE-autonomous.md` or `dod-checklists.md` with checks that would have caught the issue.

Example:
- Bug: "Forgot to activate venv" → Add to dod-checklists.md: "[ ] Python: venv activated (source venv/bin/activate)"
- Bug: "API verification missing" → Add to dod-checklists.md: "[ ] External POST verified with GET or screenshot"

---

**Last reviewed**: 2026-02-28
