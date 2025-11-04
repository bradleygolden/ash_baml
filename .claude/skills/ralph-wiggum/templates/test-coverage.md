You are running in a loop via ./scripts/ralph.sh. Your task is to improve unit test coverage for this repository to improve the overall quality of the codebase.

Goal: [SPECIFY YOUR TARGET - e.g., "Achieve 80% test coverage"]

Steps:
- Read from SCRATCHPAD.md
- If the prior loop requires a fix:
  - Implement the fix
- Else if the prior loop doesn't require a fix:
  - Run the mix test --cover --warnings-as-errors command to check for coverage
  - If there are warnings:
    - Document the warnings in SCRATCHPAD.md
    - Stop and allow the next loop iteration to fix the warnings
  - Identify which code you want to increase coverage for
- Document your reasoning in SCRATCHPAD.md
- Implement the tests and run the tests
- Document the implementation in SCRATCHPAD.md
- If the tests fail:
    - Document the failure in SCRATCHPAD.md
    - Stop and allow the next loop iteration to fix the test
- Else if the tests pass:
  - Commit the changes (exclude SCRATCHPAD.md and PROMPT.md or any other temporary files)
- If SCRATCHPAD.md is longer than 1000 lines and there are no unresolved issues, delete it.

Note: The orchestrator (Claude Code) will monitor your progress and decide when to stop the loop based on evaluating whether the goal is achieved.

Guidelines:
  - Structure & Conventions:
    - Follow naming: `<filename>_test.exs` in test/ matching lib/ structure
    - Never use Process.sleep - causes flaky tests
    - Focus on unit tests in test/ash_baml only

  - Test Design:
    - One behavior per test name
    - Use pattern matching for assertions: `assert value = func()` not `assert value == func()`
    - Group variations with for-comprehensions instead of separate tests
    - Use setup for fixtures, not inline defmodules

  - Avoid Redundancy:
    - Don't test the same behavior multiple times
    - Don't check preconditions that will fail anyway (e.g., `File.exists?` before `File.read!`)
    - Consolidate multiple similar assertions with for-comprehensions

  - Consistency:
    - Be consistent within each test (all pattern match OR all string match)
    - Assert on actual values, not types
