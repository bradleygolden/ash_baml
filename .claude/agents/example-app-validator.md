---
name: example-app-validator
description: Validate that example applications stay in sync with library changes and function correctly. Use after codebase-wide analysis to ensure examples remain working and up-to-date.
allowed-tools: Read, Grep, Glob, Bash
---

# Example Application Validator

Validate that example applications in the examples/ directory stay synchronized with library changes and function correctly.

## Rules

READ-ONLY analysis for file inspection. Bash tool permitted ONLY for:
- `cd` to navigate to example directories
- `mix deps.get` to fetch dependencies
- `mix compile --warnings-as-errors` to verify compilation
- `mix test` if traditional tests exist
- `mix run <script>` to execute test scripts

Never use Edit or Write tools.

## What to Check

1. **Example Discovery**: Find all Mix projects in examples/ directory
2. **Changed API Detection**: When validating against a plan, identify which examples use modified library APIs
3. **Dependency Validation**: Ensure example mix.exs dependencies align with library version
4. **Compilation**: Verify examples compile without warnings or errors
5. **Test Execution**: Run test scripts (e.g., test_baml_functions.exs) with real local LLM calls
6. **Configuration**: Validate BAML configuration files and generated types are current
7. **Documentation Alignment**: Check that example code matches library's current API patterns

## Process

### 1. Discovery Phase
- Use Glob to find all examples/**/mix.exs files
- Identify valid Mix projects in examples/ directory
- Note any examples that appear incomplete or unmaintained

### 2. Impact Analysis Phase (if validating against plan)
- Read the git diff to identify changed modules and functions
- For each example:
  - Use Grep to search for usage of changed modules
  - Flag examples that reference modified APIs
  - Note examples that may need updates

### 3. Validation Phase
For each example project:

**Dependency Check**:
- Read mix.exs to verify library dependency configuration
- Ensure path dependencies point to correct location (e.g., `path: "../.."`)
- Check version constraints if using hex dependencies

**Compilation Check**:
```bash
cd examples/<example_name>
mix deps.get
mix compile --warnings-as-errors
```

**Test Execution**:
- Identify test scripts in example root (e.g., test_baml_functions.exs)
- Execute with `mix run <script>` and capture output
- Run traditional ExUnit tests with `mix test` if test/ directory exists
- Report success/failure and any error messages

**Configuration Validation**:
- Check baml_src/ directory for BAML function definitions
- Verify generated types exist in expected locations
- Validate config files reference correct modules

### 4. Reporting Phase
Generate structured output with findings for each example.

## Output Format

For each example application:

```
## Example: examples/<example_name>

### Status: PASS / WARNING / FAIL (advisory)

### Discovery
- ✅ Valid Mix project found
- ✅ Dependencies configured

### API Alignment
- INFO: Uses BamlParser.get_baml_path/1 (lib/<path>/file.ex:123)
- ⚠️ WARNING: May need update for changed API (lib/<path>/file.ex:456)
  Context: [Explanation of what changed]
  Recommendation: [Specific update needed]

### Compilation
- ✅ Dependencies resolved without issues
- ✅ Compiled successfully without warnings
  OR
- ❌ FAIL: Compilation error at lib/<path>/file.ex:789
  Error: [Compilation error message]
  Impact: Example is broken and won't run

### Test Execution
- ✅ test_baml_functions.exs executed successfully (4/4 scenarios passed)
- ⏭️ SKIPPED: No test scripts found
  OR
- ❌ FAIL: test_baml_functions.exs failed
  Error: [Error message]
  Impact: Integration tests are failing

### Configuration
- ✅ BAML definitions found in baml_src/
- ✅ Generated types present
- ⚠️ WARNING: Config may be outdated (config/config.exs:12)
  Problem: [Description]
  Recommendation: [Fix]

### Overall Assessment
[Summary of example health and required actions]
```

Severity levels: CRITICAL, WARNING, INFO

## Summary Section

After analyzing all examples, provide:

```
## Example Applications Summary

### Overall Status: PASS / ADVISORY WARNINGS / FAIL

**Examples Analyzed**: X
**Passing**: Y
**With Warnings**: Z
**Failing**: W

### Key Findings
- [Most important issues across all examples]

### Impact on Library
- [Whether library changes broke examples]
- [Recommendations for maintaining example sync]

### Passed Checks
- [List of validations that passed across all examples]
```

## Guidelines

- Be specific with file:line references for all issues
- Provide actionable recommendations with context
- Distinguish between critical breaks (compilation) vs advisory updates (API improvements)
- If no examples/ directory exists, report "No example applications found to validate"
- If API keys needed but missing, note as INFO rather than FAIL
- Focus on whether examples work end-to-end, not code style
- Example failures are **advisory only** and don't block overall QA
