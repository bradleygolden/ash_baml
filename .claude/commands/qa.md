---
description: Comprehensive quality assurance and validation for Elixir projects
argument-hint: [optional-plan-name]
allowed-tools: Read, Grep, Glob, Task, Bash, TodoWrite, Write, SlashCommand, AskUserQuestion
---

# QA

Validate implementation against quality standards and success criteria.

## Execution Steps

### Step 1: Determine Scope

**If plan name provided:**
- Locate plan: `.thoughts/plans/*[plan-name]*.md`
- Read plan and extract success criteria
- Validate implementation against plan

**If no plan:**
- General health check
- Run all quality tools
- Review recent changes

### Step 2: Generate QA Plan

**2.1 Gather Git Evidence**

Run in parallel:
```bash
git status
git diff --stat main...HEAD
git log --oneline -10
git diff --name-only main...HEAD | grep '^lib/.*\.ex$'
git diff --name-only main...HEAD | grep '^test/.*\.exs$'
```

**2.2 Create QA Plan Document**

Save to: `.thoughts/qa-plans/YYYY-MM-DD-[plan-name]-qa-plan.md`

```markdown
---
date: [ISO timestamp]
plan: [Plan name if applicable]
branch: [Current branch]
commit: [Current commit hash]
files_changed: [N]
---

# QA Plan: [Plan Name or "General Health Check"]

**Created**: [Date/time]
**Branch**: [branch]
**Comparing**: main...HEAD
**Files Changed**: [N] lib/, [N] test/

## Automated Quality Checks

- [ ] mix compile --warnings-as-errors
- [ ] mix test --warnings-as-errors
- [ ] mix format --check-formatted
- [ ] mix credo --strict
- [ ] mix dialyzer
- [ ] mix sobelow --exit Low
- [ ] mix docs

## Codebase-Wide Analysis

- [ ] consistency-checker
- [ ] documentation-completeness-checker
- [ ] dead-code-detector

## Per-File Diff Analysis

### Lib Files

[For each lib file:]
- [ ] [file_path]

### Test Files

[For each test file:]
- [ ] [file_path]

## Success Criteria

[If plan exists, include criteria from plan, otherwise general criteria]

## Execution Order

1. Automated checks (parallel)
2. Codebase-wide agents (parallel)
3. Per-file lib analysis (sequential)
4. Per-file test analysis (sequential)
5. Generate report
```

**2.3 Setup TodoWrite**

```
1. [completed] Generate QA plan
2. [in_progress] Run automated quality checks
3. [pending] Run codebase-wide analysis
4. [pending] Analyze changed lib files
5. [pending] Analyze changed test files
6. [pending] Generate QA report
7. [pending] Offer fix plan if needed
```

### Step 3: Run Automated Quality Checks

Execute ALL checks in parallel (single message, multiple Bash tool calls):

```bash
mix compile --warnings-as-errors
mix test --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix dialyzer
mix sobelow --exit Low
mix docs
```

Capture exit codes and output for each.

Mark step complete in TodoWrite.

### Step 4: Run Codebase-Wide Analysis

Launch ALL agents in parallel (single message, multiple Task tool calls):

```
Task(subagent_type="consistency-checker",
     description="Check consistency",
     prompt="Analyze this Elixir project for consistency between documentation, code examples, and configuration. Verify README examples match actual code usage, check mix.exs dependencies are used, and ensure cross-references are accurate.")

Task(subagent_type="documentation-completeness-checker",
     description="Check documentation",
     prompt="Verify all public modules and functions in lib/ have complete documentation. Check for @moduledoc and @doc coverage. Report any missing or boilerplate documentation.")

Task(subagent_type="dead-code-detector",
     description="Find dead code",
     prompt="Find unused private functions, unused modules, unreachable code, and large commented-out code blocks in lib/. Report findings with confidence levels.")
```

Wait for all agents to complete.

Mark step complete in TodoWrite.

### Step 5: Analyze Changed Lib Files

**5.1 Get Changed Lib Files**

```bash
git diff --name-only main...HEAD | grep '^lib/.*\.ex$'
```

**5.2 Spawn One Agent Per File**

For each lib file, launch sequentially (or in waves of 5 if many files):

```
Task(subagent_type="qa-lib-file-analyzer",
     description="Analyze [filename]",
     prompt="Analyze the git diff for [file_path] comparing main...HEAD. Report findings.")
```

Collect findings from each agent.

Mark step complete in TodoWrite.

### Step 6: Analyze Changed Test Files

**6.1 Get Changed Test Files**

```bash
git diff --name-only main...HEAD | grep '^test/.*\.exs$'
```

**6.2 Spawn One Agent Per File**

For each test file, launch sequentially (or in waves of 5 if many files):

```
Task(subagent_type="qa-test-file-analyzer",
     description="Analyze [filename]",
     prompt="Analyze the git diff for [file_path] comparing main...HEAD. Report findings.")
```

Collect findings from each agent.

Mark step complete in TodoWrite.

### Step 7: Generate QA Report

**7.1 Compile Findings**

- Automated check results
- Codebase-wide agent findings
- Per-file lib analysis findings
- Per-file test analysis findings
- Success criteria status (if validating plan)

**7.2 Determine Overall Status**

- PASS: All checks passed, no critical issues
- PASS_WITH_WARNINGS: Checks passed, some warnings found
- FAIL: Checks failed or critical issues found

**7.3 Create Report**

Save to: `.thoughts/qa-reports/YYYY-MM-DD-[plan-name]-qa.md`

```markdown
---
date: [ISO timestamp]
validator: [Git user name]
commit: [Current commit hash]
branch: [Current branch]
plan: [Plan name if applicable]
status: [PASS / PASS_WITH_WARNINGS / FAIL]
tags: [qa, validation, elixir, library]
qa_plan: [Path to QA plan file]
---

# QA Report: [Plan Name or "General Health Check"]

**Date**: [Date/time]
**Validator**: [Git user]
**Commit**: [hash]
**Branch**: [branch]
**QA Plan**: [path to qa-plan.md]

## Executive Summary

**Overall Status**: [PASS / PASS_WITH_WARNINGS / FAIL]

**Quick Stats:**
- Compilation: [PASS/FAIL]
- Tests: [N passed, N failed]
- Credo: [PASS/FAIL]
- Dialyzer: [PASS/FAIL]
- Sobelow: [PASS/FAIL]
- Documentation: [PASS/FAIL]
- Files Analyzed: [N lib, N test]

## Automated Verification Results

### Compilation
```
[Output]
```
Status: [PASS/FAIL]

### Test Suite
```
[Output]
```
Status: [PASS/FAIL]
Failed Tests: [list if any]

### Code Formatting
```
[Output]
```
Status: [PASS/FAIL]

### Credo Analysis
```
[Output]
```
Status: [PASS/FAIL]
Issues: [list if any]

### Dialyzer Type Checking
```
[Output]
```
Status: [PASS/FAIL]
Type Errors: [list if any]

### Sobelow Security Scan
```
[Output]
```
Status: [PASS/FAIL]
Findings: [list if any]

### Documentation Generation
```
[Output]
```
Status: [PASS/FAIL]

## Codebase-Wide Analysis

### Consistency Check
[Findings from consistency-checker]

### Documentation Completeness
[Findings from documentation-completeness-checker]

### Dead Code Detection
[Findings from dead-code-detector]

## Per-File Analysis Results

### Lib Files

[For each lib file analyzed:]

#### [file_path]

[Findings from qa-lib-file-analyzer]

### Test Files

[For each test file analyzed:]

#### [file_path]

[Findings from qa-test-file-analyzer]

## Success Criteria Validation

[If validating against plan:]

**Automated Criteria**:
- [ ] [criterion from plan]

**Manual Criteria**:
- [ ] [criterion from plan]

[If general health check, list standard criteria]

## Issues Summary

### Critical Issues
[List all CRITICAL severity issues with file:line]

### Warnings
[List all WARNING severity issues with file:line]

### Recommendations
[List all RECOMMENDATION severity issues with file:line]

## Overall Assessment

[IF PASS]
PASS: All quality checks passed. Implementation meets standards and is ready for merge.

[IF PASS_WITH_WARNINGS]
PASS WITH WARNINGS: Core functionality validated. Address warnings before merge or document accepted warnings.

[IF FAIL]
FAIL: Critical issues prevent approval. Fix issues and re-run QA.

## Next Steps

[IF PASS]
- Merge to main
- Deploy if applicable

[IF PASS_WITH_WARNINGS]
- Address warnings or document accepted warnings
- Re-run QA or proceed with caution

[IF FAIL]
- Fix critical issues
- Re-run: `/qa [plan-name]`
```

Mark step complete in TodoWrite.

### Step 8: Present Summary

Show concise summary:

```markdown
# QA Validation Complete

**Plan**: [Plan name or "General Health Check"]
**Status**: [PASS / PASS_WITH_WARNINGS / FAIL]

**Automated Checks**: [X/7 passed]
**Files Analyzed**: [N lib, N test]
**Issues Found**: [N critical, N warnings, N recommendations]

**Detailed Report**: `.thoughts/qa-reports/YYYY-MM-DD-[plan-name]-qa.md`

[IF FAIL]
**Critical Issues**: [count]
[List top 3 critical issues with file:line]

[IF PASS]
Ready to merge.
```

### Step 9: Offer Fix Plan (If Status is FAIL)

**Only if status is FAIL:**

**9.1 Count Critical Issues**

Count issues marked CRITICAL in report.

**9.2 Ask User**

Use AskUserQuestion:
```
Question: "QA detected [N] critical issues. Generate a fix plan?"
Header: "Fix Plan"
Options (multiSelect: false):
  - Label: "Yes, generate fix plan"
    Description: "Create plan to address all critical issues"
  - Label: "No, I'll fix manually"
    Description: "Exit and fix manually, then re-run /qa"
```

**9.3 If "Yes":**

a. Get QA report path:
```bash
ls -t .thoughts/qa-reports/*-qa.md | head -1
```

b. Generate fix plan:
```
SlashCommand: /plan "Fix critical issues from QA report: [report_path]"
```

c. Ask to execute:
```
Question: "Fix plan created. Execute now?"
Header: "Execute Plan"
Options (multiSelect: false):
  - Label: "Yes, execute"
    Description: "Run /implement then re-run /qa"
  - Label: "No, I'll review first"
    Description: "Exit and review plan manually"
```

d. If "Yes, execute":
```
SlashCommand: /implement "[plan_name]"
SlashCommand: /qa
```

Report: "Fix cycle complete. Check QA results above."

e. If "No, I'll review first":

Report:
```
Fix plan saved at: [plan_path]

To implement: /implement "[plan_name]"
To re-validate: /qa
```

**9.4 If "No, I'll fix manually":**

Report:
```
Critical issues documented in: [report_path]

After fixing, re-run: /qa
```

## Guidelines

**Parallelization**: Execute independent operations in parallel (single message, multiple tool calls).

**Thoroughness**: Run all checks, document all findings, be objective.

**Validation Philosophy**: Real validation, not rubber stamp. Focus on significant issues.

**Edge Cases**:
- If plan file not found: search `.thoughts/plans/`, list options, ask user
- If no changes detected: note in report, run general health check
- If quality tools not installed: note in report, skip tool, don't fail QA
- If pre-existing test failures: document which are pre-existing, focus on new failures

## Quality Tool Requirements

- **Credo**: Static analysis via `mix credo --strict`
- **Dialyzer**: Type checking via `mix dialyzer`
- **Sobelow**: Security scanning via `mix sobelow --exit Low`
- **ExDoc**: Documentation via `mix docs`
