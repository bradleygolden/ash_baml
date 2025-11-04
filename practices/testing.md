# Testing Practices

Guidelines for writing tests in this repository.

## Structure & Conventions

- Never use Process.sleep - causes flaky tests

### Unit Tests
- Should be in test/ash_baml
- Follow naming: `<filename>_test.exs` in test/ matching lib/ structure
- Use `async: true` when possible

### Integration Tests
- Should be in test/integration
- Name describes the workflow: `user_workflow_test.exs`, `api_flow_test.exs`
- Use `async: false` (typically can't isolate side effects)

## Test Design

- One behavior per test name
- Use pattern matching for assertions: `assert value = func()` not `assert value == func()`
- Group variations with for-comprehensions instead of separate tests
- Use setup for fixtures, not inline defmodules

## Avoid Redundancy

- Don't test the same behavior multiple times
- Don't check preconditions that will fail anyway (e.g., `File.exists?` before `File.read!`)
- Consolidate multiple similar assertions with for-comprehensions

## Consistency

- Be consistent within each test (all pattern match OR all string match)
- Assert on actual values, not types
