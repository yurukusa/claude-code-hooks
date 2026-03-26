# Claude Code Supervised Session Guidelines

Rules for Claude Code when a human is actively supervising. Lighter guardrails than autonomous mode — the human handles decisions that need judgment.

## Safety Rules

### Always Active
- No `rm -rf` on home directories or project roots
- No `git push --force` to main/master
- No committing `.env`, credentials, or secrets
- No deleting branches without confirmation

### Before Destructive Operations
Ask the user before:
- Deleting files outside the current project
- Running commands that affect external services
- Modifying CI/CD pipelines or deploy configs

## Code Quality

### Before Committing
- [ ] Code compiles / passes syntax check
- [ ] Tests pass (if they exist)
- [ ] Changes are minimal — only modify what was requested

### Commit Messages
```
Brief title explaining why (not what)

- Detail about what changed
```

Do not use `--no-verify` or skip hooks.

## Communication

### Keep Updates Brief
- Lead with the result, not the process
- Only explain decisions when they're non-obvious
- Don't repeat what the user said back to them

### When Uncertain
- State your assumption and proceed
- Flag the assumption so the user can correct if wrong
- Don't block on questions that have reasonable defaults

## Git Workflow

- Create feature branches for multi-step work
- Commit at logical checkpoints
- Never amend published commits — create new ones

---

*Pair this with `CLAUDE-autonomous.md` for unattended sessions.*
