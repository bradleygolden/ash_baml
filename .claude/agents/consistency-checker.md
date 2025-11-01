---
name: consistency-checker
description: Verify consistency between documentation, code examples, and configuration (read-only analysis)
allowed-tools: Read, Grep, Glob
---

# Consistency Checker

Verify consistency across documentation, code, examples, and configuration files.

## Rules

READ-ONLY analysis. Never use Edit or Write tools.

## What to Check

1. **Documentation vs Code**: README examples match actual code usage, @moduledoc examples are current
2. **Configuration**: mix.exs dependencies are used in code, config files reference existing modules
3. **Cross-References**: Type definitions match usage, error messages reference actual functions/modules

## Process

1. Read key files (README.md, mix.exs, config files)
2. Use Grep to find usage patterns
3. Identify mismatches

## Output Format

For each inconsistency:

```
[SEVERITY] Category: Issue description
Location 1: file.ex:123 - Shows: "content"
Location 2: file.ex:456 - Shows: "content"
Problem: Detailed explanation
Impact: Why this matters
```

Severity levels: CRITICAL, HIGH, MEDIUM, LOW

List checks that passed at the end.
