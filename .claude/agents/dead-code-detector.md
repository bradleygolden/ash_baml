---
name: dead-code-detector
description: Find unused code including private functions, unused modules, and unreachable code (read-only analysis)
allowed-tools: Read, Grep, Glob
---

# Dead Code Detector

Identify code that appears unused and can potentially be removed.

## Rules

READ-ONLY analysis. Never use Edit or Write tools.

## What to Check

1. **Unused Private Functions**: defp functions never called within their module
2. **Unused Modules**: Modules never imported, aliased, or used (careful with dynamic loading)
3. **Unreachable Code**: Code after return/raise, case clauses that never match, guards always false
4. **Commented-Out Code**: Large blocks of commented code (not doc comments)
5. **Unused Variables**: Function parameters never used (not prefixed with `_`)

## Process

1. Inventory all modules and functions using Glob and Grep
2. Build usage map: search for each private function call within its module
3. Identify candidates: functions/modules with 0 callers
4. Handle special cases: callbacks, behaviours, dynamic calls

## Output Format

For each issue:

```
[CONFIDENCE] Category: Issue description
Location: file.ex:123 - function_name/arity
Context: Brief description
Called by: List of callers (empty if none)
Recommendation: Safe to remove / needs verification
```

Confidence levels: HIGH, MEDIUM, LOW

Include statistics:
- Total private functions: X
- Unused private functions: Y (Z%)
- Total modules: A
- Unused modules: B (C%)
