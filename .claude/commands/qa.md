---
description: Comprehensive quality assurance and validation for Elixir projects
argument-hint: [optional-plan-name]
allowed-tools: Read, Grep, Glob, Task, Bash, TodoWrite, Write, SlashCommand, AskUserQuestion
---

# QA

Systematically validate Elixir implementation against quality standards and success criteria.

**Project Type**: Library/Package

## Purpose

Validate completed work through automated checks, code review, and comprehensive quality analysis to ensure implementation meets standards.

## Steps to Execute:

### Step 1: Determine Scope

**If plan name provided:**
- Locate plan file: `.thoughts/plans/*[plan-name]*.md`
- Read plan completely
- Extract success criteria
- Validate implementation against that plan

**If no plan provided:**
- General Elixir project health check
- Run all quality tools
- Review recent changes
- Provide overall quality assessment

### Step 2: Initial Discovery

**Read implementation plan** (if validating against plan):
```bash
find .thoughts/plans -name "*[plan-name]*.md" -type f
```

**Gather git evidence:**
```bash
# See what changed
git status
git diff --stat
git log --oneline -10

# If validating a specific branch
git diff main...HEAD --stat
```

**Create validation plan** using TodoWrite:
```
1. [in_progress] Gather context and plan
2. [pending] Run automated quality checks
3. [pending] Spawn validation agents
4. [pending] Check manual criteria
5. [pending] Generate validation report
6. [pending] Offer fix plan generation if critical issues found
```

### Step 3: Run Automated Quality Checks

**IMPORTANT: Maximize parallel execution for speed!**

Execute ALL automated checks in a SINGLE message with multiple Bash tool calls:

Run these concurrently in ONE message:
- `mix test --warnings-as-errors` - Execute all tests
- `mix format --check-formatted` - Verify code formatting
- `mix credo --strict` - Static code analysis
- `mix dialyzer` - Type checking
- `mix compile --warnings-as-errors` - Clean compilation
- `mix sobelow --exit Low` - Security scanning
- `mix docs` - Documentation generation

**Capture results** from each check:
- Exit code (0 = pass, non-zero = fail)
- Output messages
- Any warnings or errors

Mark this step complete in TodoWrite.

### Step 4: Spawn Validation Agents

**IMPORTANT: Launch ALL agents in parallel for speed!**

Execute ALL four subagents in a SINGLE message with multiple Task tool calls.

Launch these custom agents concurrently in ONE message:
- **consistency-checker**: Verify documentation/code consistency
- **documentation-completeness-checker**: Check @moduledoc, @doc, @spec coverage
- **code-smell-checker**: Detect anti-patterns and non-idiomatic code
- **dead-code-detector**: Find unused functions and modules

**Example Task launches (all in one message):**

```
Task(subagent_type="consistency-checker", description="Check consistency", prompt="Analyze this Elixir project for consistency between documentation, code examples, and configuration. Verify README examples match actual code usage, check mix.exs dependencies are used, and ensure cross-references are accurate.")

Task(subagent_type="documentation-completeness-checker", description="Check documentation", prompt="Verify all public modules and functions in lib/ have complete documentation. Check for @moduledoc, @doc, and @spec coverage. Report any missing or boilerplate documentation.")

Task(subagent_type="code-smell-checker", description="Detect code smells", prompt="Analyze code quality for Elixir best practices. Check for pattern matching usage, pipe operators, function complexity, and idiomatic patterns. Flag bloated or non-idiomatic code. Use Skill tool to verify dependency usage against hex docs.")

Task(subagent_type="dead-code-detector", description="Find dead code", prompt="Find unused private functions, unused modules, unreachable code, and large commented-out code blocks in lib/. Report findings with confidence levels.")
```

**Wait for all agents** to complete before proceeding.

**Collect all findings** for the final report.

Mark this step complete in TodoWrite.

### Step 5: Verify Success Criteria

**If validating against plan:**

**Read success criteria** from plan:
- Automated verification section
- Manual verification section

**Check automated criteria:**
- Match each criterion against actual checks
- Confirm all automated checks passed
- Note any that failed

**Check manual criteria:**
- Review each manual criterion
- Assess whether it's met (check implementation)
- Document status for each

**If general health check:**

**Automated Health Indicators:**
- Compilation succeeds
- All tests pass
- Format check passes
- Quality tools pass (if configured)

**Manual Health Indicators:**
- Recent changes are logical
- Code follows project patterns
- No obvious bugs or issues
- Documentation is adequate

Mark this step complete in TodoWrite.

### Step 6: Elixir-Specific Quality Checks

**Module Organization:**
- Are modules properly namespaced?
- Is module structure clear (use, import, alias at top)?
- Are public vs private functions clearly separated?

**Pattern Matching:**
- Are function heads used effectively?
- Is pattern matching preferred over conditionals?
- Are guard clauses used appropriately?

**Error Handling:**
- Are tuple returns used ({:ok, result}/{:error, reason})?
- Are with blocks used for complex error flows?
- Are errors propagated correctly?

**Library-Specific:**
- Is the public API well-designed and documented?
- Are internal modules marked as private?
- Is versioning handled correctly?
- Are dependencies properly specified?

Mark this step complete in TodoWrite.

### Step 7: Generate Validation Report

**Compile all findings:**
- Automated check results
- Agent findings (code review, tests, docs)
- Success criteria status
- Elixir-specific observations

**Create validation report structure:**

```markdown
---
date: [ISO timestamp]
validator: [Git user name]
commit: [Current commit hash]
branch: [Current branch name]
plan: [Plan name if applicable]
status: [PASS / PASS_WITH_WARNINGS / FAIL]
tags: [qa, validation, elixir, library, hex, elixir]
---

# QA Report: [Plan Name or "General Health Check"]

**Date**: [Current date and time]
**Validator**: [Git user name]
**Commit**: [Current commit hash]
**Branch**: [Current branch]
**Project Type**: Library/Package

## Executive Summary

**Overall Status**: ✅ PASS / ⚠️ PASS WITH WARNINGS / ❌ FAIL

**Quick Stats:**
- Compilation: ✅/❌
- Tests: [N] passed, [N] failed
- Credo: ✅/❌
- Dialyzer: ✅/❌
- Sobelow: ✅/❌
- Documentation: ✅/❌
- Code Review: [N] observations
- Test Coverage: [Assessment]
- Documentation: [Assessment]

## Automated Verification Results

### Compilation
```
[Output from mix compile]
```
**Status**: ✅ Success / ❌ Failed
**Issues**: [List any warnings or errors]

### Test Suite
```
[Output from test command]
```
**Status**: ✅ All passed / ❌ [N] failed
**Failed Tests**:
- [test name] - [reason]

### Code Formatting
```
[Output from mix format --check-formatted]
```
**Status**: ✅ Formatted / ❌ Needs formatting

### Credo Analysis
```
[Output from mix credo --strict]
```
**Status**: ✅ Passed / ❌ Issues found
**Issues**:
- [List any Credo warnings/errors]

### Dialyzer Type Checking
```
[Output from mix dialyzer]
```
**Status**: ✅ No type errors / ❌ Type errors found
**Type Errors**:
- [List any type errors]

### Sobelow Security Scan
```
[Output from mix sobelow]
```
**Status**: ✅ No security issues / ⚠️ Warnings / ❌ Issues found
**Findings**:
- [List any security findings]

### Documentation Generation
```
[Output from mix docs]
```
**Status**: ✅ Generated successfully / ❌ Errors
**Issues**:
- [List any documentation warnings]

## Agent Validation Results

### Consistency Check

[Findings from consistency-checker agent]

**Consistency Issues**: [N] found
- Documentation vs code mismatches
- Configuration inconsistencies
- Cross-reference errors

### Documentation Completeness

[Findings from documentation-completeness-checker agent]

**Documentation Status**:
- Modules with @moduledoc: [N]/[M] ([X]%)
- Functions with @doc: [N]/[M] ([X]%)
- Functions with @spec: [N]/[M] ([X]%)
- Quality assessment: [Good/Adequate/Needs Work]

### Code Smell Analysis

[Findings from code-smell-checker agent]

**Code Quality**:
- Code smells found: [N]
- Bloated functions: [N]
- Non-idiomatic patterns: [N]
- File ratings: [X clean, Y minor issues, Z needs refactoring]

### Dead Code Detection

[Findings from dead-code-detector agent]

**Dead Code Found**:
- Unused private functions: [N]
- Unused modules: [N]
- Unreachable code blocks: [N]
- Commented-out code: [N] blocks

## Success Criteria Validation

[If validating against plan, list each criterion]

**Automated Criteria**:
- [x] Compilation succeeds
- [x] mix test --warnings-as-errors passes
- [x] Credo analysis passes
- [x] Dialyzer type checking passes
- [x] Sobelow security scan passes
- [x] Documentation generates successfully

**Manual Criteria**:
- [x] Feature works as expected
- [ ] Edge cases handled [Status]
- [x] Documentation updated

## Elixir-Specific Observations

**Module Organization**: [Assessment]
**Pattern Matching**: [Assessment]
**Error Handling**: [Assessment]
**Library API Design**: [Assessment]
**Documentation Quality**: [Assessment]

## Issues Found

[If any issues, list them by severity]

### Critical Issues (Must Fix)
[None or list]

### Warnings (Should Fix)
[None or list]

### Recommendations (Consider)
[None or list]

## Overall Assessment

[IF PASS]
✅ **IMPLEMENTATION VALIDATED**

All quality checks passed:
- Automated verification: Complete
- Code review: No issues
- Tests: All passing
- Documentation: Adequate

Implementation meets quality standards and is ready for merge/deploy.

[IF PASS WITH WARNINGS]
⚠️ **PASS WITH WARNINGS**

Core functionality validated but some areas need attention:
- [List warning areas]

Address warnings before merge or create follow-up tasks.

[IF FAIL]
❌ **VALIDATION FAILED**

Critical issues prevent approval:
- [List critical issues]

Fix these issues and re-run QA: `/qa "[plan-name]"`

## Next Steps

[IF PASS]
- Merge to main branch
- Deploy (if applicable)
- Close related tickets

[IF PASS WITH WARNINGS]
- Address warnings
- Re-run QA or accept warnings and proceed
- Document accepted warnings

[IF FAIL]
- Fix critical issues
- Address failing tests
- Re-run: `/qa "[plan-name]"`
```

Save report to: `.thoughts/qa-reports/YYYY-MM-DD-[plan-name]-qa.md`

Mark this step complete in TodoWrite.

### Step 8: Present Results

**Show concise summary to user:**

```markdown
# QA Validation Complete

**Plan**: [Plan name or "General Health Check"]
**Status**: ✅ PASS / ⚠️ PASS WITH WARNINGS / ❌ FAIL

## Results Summary

**Automated Checks**:
- Compilation: ✅
- Tests: ✅ [N] passed
- Credo: ✅
- Dialyzer: ✅
- Sobelow: ✅
- Documentation: ✅

**Code Quality**:
- Consistency: [N] issues
- Documentation Completeness: [X]% coverage
- Code Smells: [N] found
- Dead Code: [N] items

**Detailed Report**: `.thoughts/qa-reports/YYYY-MM-DD-[plan-name]-qa.md`

[IF FAIL]
**Critical Issues**:
1. [Issue with file:line]
2. [Issue with file:line]

Fix these and re-run: `/qa "[plan-name]"`

[IF PASS]
**Ready to merge!** ✅
```

### Step 9: Offer Fix Plan Generation (Conditional)

**Only execute this step if overall status is ❌ FAIL**

If QA detected critical issues:

**9.1 Count Critical Issues**

Count issues from validation report that are marked as ❌ CRITICAL or blocking.

**9.2 Prompt User for Fix Plan Generation**

Use AskUserQuestion tool:
```
Question: "QA detected [N] critical issues. Generate a fix plan to address them?"
Header: "Fix Plan"
Options (multiSelect: false):
  Option 1:
    Label: "Yes, generate fix plan"
    Description: "Create a detailed plan to address all critical issues using /plan command"
  Option 2:
    Label: "No, I'll fix manually"
    Description: "Exit QA and fix issues manually, then re-run /qa"
```

**9.3 If User Selects "Yes, generate fix plan":**

**9.3.1 Extract QA Report Filename**

Get the most recent QA report generated in Step 7:
```bash
ls -t .thoughts/qa-reports/*-qa.md 2>/dev/null | head -1
```

Store filename in variable: QA_REPORT_PATH

**9.3.2 Invoke Plan Command**

Use SlashCommand tool:
```
Command: /plan "Fix critical issues from QA report: [QA_REPORT_PATH]"
```

Wait for plan generation to complete.

**9.3.3 Extract Plan Filename**

Parse the output from /plan command to find the generated plan filename.
Typical format: `.thoughts/plans/plan-YYYY-MM-DD-fix-*.md`

Store plan name without path/extension in variable: FIX_PLAN_NAME

Report to user:
```
Fix plan created at: [PLAN_FILENAME]
```

**9.3.4 Prompt User for Plan Execution**

Use AskUserQuestion tool:
```
Question: "Fix plan created. Execute the fix plan now?"
Header: "Execute Plan"
Options (multiSelect: false):
  Option 1:
    Label: "Yes, execute fix plan"
    Description: "Run /implement to apply fixes, then re-run /qa for validation"
  Option 2:
    Label: "No, I'll review first"
    Description: "Exit and review the plan manually before implementing"
```

**9.3.5 If User Selects "Yes, execute fix plan":**

Use SlashCommand tool:
```
Command: /implement "[FIX_PLAN_NAME]"
```

Wait for implementation to complete.

Report:
```
Fix implementation complete. Re-running QA for validation...
```

Use SlashCommand tool:
```
Command: /qa
```

Wait for QA to complete.

Report:
```
Fix cycle complete. Check QA results above.
```

**9.3.6 If User Selects "No, I'll review first":**

Report:
```
Fix plan saved at: [PLAN_FILENAME]

When ready to implement:
  /implement "[FIX_PLAN_NAME]"

After implementing, re-run QA:
  /qa
```

**9.4 If User Selects "No, I'll fix manually":**

Report:
```
Manual fixes required.

Critical issues documented in: [QA_REPORT_PATH]

After fixing, re-run QA:
  /qa
```

**9.5 If QA Status is NOT ❌ FAIL:**

Skip this step entirely (no fix plan offer needed).

## Quality Tool Integration

**Credo** - Static code analysis:
- Integrated via `mix credo --strict`
- Checks code style, design patterns, readability
- Configuration: `.credo.exs` (if present)

**Dialyzer** - Type checking:
- Integrated via `mix dialyzer`
- Performs static type analysis
- Requires PLT file (auto-generated)

**Sobelow** - Security scanning:
- Integrated via `mix sobelow --exit Low`
- Scans for security vulnerabilities
- Particularly important for Phoenix/web apps

**ExDoc** - Documentation generation:
- Integrated via `mix docs`
- Validates documentation syntax
- Generates HTML docs

## Important Guidelines

### Automated vs Manual

**Automated Verification:**
- Must be runnable via command
- Exit code determines pass/fail
- Repeatable and consistent

**Manual Verification:**
- Requires human judgment
- UI/UX quality
- Business logic correctness
- Edge case appropriateness

### Thoroughness

**Be comprehensive:**
- Run all configured quality tools
- Spawn all validation agents
- Check all success criteria
- Document all findings

**Be objective:**
- Report what you find
- Don't minimize issues
- Don't over-report non-issues
- Focus on facts

### Validation Philosophy

**Not a rubber stamp:**
- Real validation, not formality
- Find real issues
- Assess true quality

**Not overly strict:**
- Focus on significant issues
- Warnings vs failures
- Practical quality bar

## Edge Cases

### If Plan Doesn't Exist

User provides plan name but file not found:
- Search .thoughts/plans/
- List available plans
- Ask user to clarify or choose

### If No Changes Detected

Running QA but no git changes:
- Note in report
- Run general health check anyway
- Report clean state

### If Tests Have Pre-Existing Failures

Tests failing before this implementation:
- Document which tests are pre-existing
- Focus on new failures
- Note technical debt in report

### If Quality Tools Not Installed

If Credo, Dialyzer, etc. not in mix.exs:
- Note in report
- Skip that tool
- Don't fail validation for missing optional tools

## Example Session

**User**: `/qa "user-authentication"`

**Process**:
1. Find plan: `.thoughts/plans/2025-01-23-user-authentication.md`
2. Read success criteria from plan
3. Run automated checks (compile, test, format, Credo, Dialyzer)
4. Spawn 3 validation agents (code review, test coverage, docs)
5. Wait for agents to complete
6. Verify success criteria
7. Check Elixir-specific patterns
8. Generate comprehensive report
9. Present summary: "✅ PASS - All 12 success criteria met"
