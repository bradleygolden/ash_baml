---
name: ralph-wiggum
description: |
  Run Ralph pattern - background loop feeding PROMPT.md to Claude CLI. Activate on "run ralph", "check on ralph", "stop ralph". You run it in background, monitor via tail SCRATCHPAD.md + git log, decide when to kill based on goal completion.
allowed-tools:
  - Read
  - Bash
  - BashOutput
  - KillShell
---

# Ralph Pattern

Run PROMPT.md in infinite loop. You monitor and decide when to stop.

## Start Ralph
- Check for `practices/` directory and read relevant practice files to understand project conventions
- Verify PROMPT.md exists at the root of the project (offer template if not)
- Note user's goal for evaluation later
- Run in background: `bash .claude/skills/ralph-wiggum/scripts/ralph.sh` with `run_in_background: true`
- Save bash_id, tell user it's running

## Check Progress
- `tail -n 50 SCRATCHPAD.md`
- `git log --oneline -n 10`
- Run verification command (e.g., `mix test --cover`)
- Report concisely (2-3 sentences)
- Kill if goal met, alert if stuck, continue if progressing

## Stop Ralph
- `KillShell` with bash_id
- Summarize: tail SCRATCHPAD.md + recent commits
- Offer to clean up or restart with refined PROMPT.md

See `REFERENCE.md` for Ralph philosophy (eventual consistency, iterative refinement).
