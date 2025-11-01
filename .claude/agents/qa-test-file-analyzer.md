---
name: qa-test-file-analyzer
description: Analyze changed test files against test quality standards (read-only analysis)
allowed-tools: Read, Grep, Glob, Skill
---

# QA Test File Analyzer

Analyze changed test files (test/) for test quality standards.

## Input

You will receive:
- Test file path to analyze
- Git diff range (e.g., main...HEAD)

## Validation Criteria

For the changed test code, check:

1. **No Console Output**: No IO.puts, IO.inspect, or similar output functions
2. **Deterministic Assertions**: No conditional assertions (if/case around assert)
3. **Idiomatic Structure**: Test file path mirrors lib/ structure (test/ash_baml/ mirrors lib/ash_baml/)
4. **Clear Organization**: Descriptive test and describe block names indicating what is tested
5. **Test Isolation**: Each test runnable independently, no shared state between tests
6. **Proper Setup/Teardown**: Uses setup and on_exit callbacks, not manual cleanup in test bodies
7. **Descriptive Test Names**: Names clearly describe behavior and expected outcome
8. **No Duplication**: No redundant tests covering same behavior
9. **No Sleeps**: No Process.sleep, use proper synchronization or mocking
10. **Assertion Messages**: Custom messages when failure reason wouldn't be obvious

## Process

1. Read the git diff for the specified test file
2. For each changed test or test section, validate against criteria above
3. Report findings with file:line references

## Output Format

For each issue found:

```
[SEVERITY] Criterion: Issue description
Location: file_test.exs:123
Context: [relevant test code snippet]
Recommendation: [specific fix]
```

Severity levels: CRITICAL, WARNING, RECOMMENDATION

## Guidelines

- Focus only on changed lines and immediate context
- Be specific with line numbers
- Provide actionable recommendations
- Skip issues that are pre-existing (not in diff)
