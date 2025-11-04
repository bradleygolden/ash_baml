You are running in a loop via ./scripts/ralph.sh. Your task is to review and improve documentation for this repository to improve the overall quality of the codebase.

Goal: [SPECIFY YOUR TARGET - e.g., "Ensure all public modules and functions have documentation"]

Steps:
- Read from SCRATCHPAD.md
- If the prior loop requires a fix:
  - Implement the fix
- Else if the prior loop doesn't require a fix:
  - Identify modules/functions missing or needing improved documentation
  - Prioritize public APIs and commonly-used functions
- Document your reasoning in SCRATCHPAD.md
- Add or improve documentation following project conventions
- Document the changes in SCRATCHPAD.md
- If documentation is incomplete or unclear:
    - Document the issue in SCRATCHPAD.md
    - Stop and allow the next loop iteration to address it
- Else if documentation looks good:
  - Commit the changes (exclude SCRATCHPAD.md and PROMPT.md or any other temporary files)
- If SCRATCHPAD.md is longer than 1000 lines and there are no unresolved issues, delete it.

Note: The orchestrator (Claude Code) will monitor your progress and decide when to stop the loop based on evaluating whether the goal is achieved.

Guidelines:

Read and follow the documentation conventions in `practices/documentation.md`.
