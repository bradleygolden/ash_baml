# Elixir Project Workflows

This project uses a standardized workflow system for research, planning, implementation, and quality assurance.

## Generated for: Library/Package (Elixir)

---

## Available Commands

### /interview

Gather context through interactive questioning before starting workflow phases.

**Usage**:
```bash
/interview              # Auto-detect workflow phase
/interview research     # Prepare for research phase
/interview plan         # Prepare for planning phase
/interview implement    # Prepare for implementation phase
```

**What it does**:
- Asks contextual questions specific to your task
- Captures preferences and constraints
- Generates workflow directives
- Saves interview context to `.thoughts/interview/interview-YYYY-MM-DD-phase-topic.md`

**When to use**:
- Before starting research to clarify scope and focus
- Before planning to establish priorities and architectural preferences
- Before implementing to define code style and validation criteria

---

### /research

Research the codebase to answer questions and document existing implementations.

**Usage**:
```bash
/research "How does authentication work?"
/research "What is the API structure?"
```

**Output**: Research documents saved to `.thoughts/research-YYYY-MM-DD-topic.md`

**What it does**:
- Spawns parallel agents to find and analyze code patterns
- Documents existing implementations with file:line references
- Captures architectural patterns and design decisions
- Provides comprehensive technical documentation

---

### /plan

Create detailed implementation plans with success criteria.

**Usage**:
```bash
/plan "Add user profile page"
/plan "Refactor database layer"
```

**Output**: Plans saved to `.thoughts/plans/YYYY-MM-DD-description.md`

**Plan Structure**: Detailed phases

**What it does**:
- Gathers context through research and analysis
- Presents design options and trade-offs
- Creates phased implementation plan with code examples
- Defines automated and manual success criteria
- Includes verification steps for each phase

---

### /implement

Execute implementation plans with automated verification.

**Usage**:
```bash
/implement "2025-01-23-user-profile"
/implement   # Will prompt for plan selection
```

**Verification Commands**:
- Compile: `mix compile --warnings-as-errors`
- Test: `mix test --warnings-as-errors`
- Format: `mix format --check-formatted`
- Credo: `mix credo --strict`
- Dialyzer: `mix dialyzer`
- Sobelow: `mix sobelow --exit Low`
- Documentation: `mix docs`

**What it does**:
- Reads the implementation plan
- Executes phase by phase with verification checkpoints
- Updates plan with checkmarks to track progress
- Handles plan vs reality mismatches gracefully
- Pauses for user confirmation between phases

---

### /qa

Validate implementation against success criteria and project quality standards.

**Usage**:
```bash
/qa                    # General health check
/qa "plan-name"        # Validate specific plan implementation
```

**Quality Gates**:
- Compilation: No errors or warnings
- Tests: All passing
- Format: Code properly formatted
- Credo: Static analysis passes
- Dialyzer: No type errors
- Sobelow: No security issues
- Documentation: Complete and accurate

**What it does**:
- Runs all automated quality checks (in parallel for speed)
- Spawns validation agents for code review, test coverage, and documentation
- Generates comprehensive QA report
- Validates against plan success criteria
- Offers automatic fix plan generation for critical issues

**Fix Workflow** (automatic): When critical issues are detected, `/qa` offers to automatically generate and execute a fix plan.

---

### /oneshot

Execute the complete workflow (research → plan → implement → qa) in one command.

**Usage**:
```bash
/oneshot "Add OAuth integration for GitHub"
/oneshot "Refactor authentication module"
```

**What it does**:
- Runs `/research` to understand existing patterns
- Runs `/plan` to create implementation strategy
- Runs `/implement` to execute the plan
- Runs `/qa` to validate quality
- Offers automatic fix workflow if QA detects issues
- Provides comprehensive summary of entire workflow

**When to use**:
- Starting a new feature from scratch
- You want full automation end-to-end
- Feature scope is well-defined

---

## Fix Workflow (Automatic)

When `/qa` detects critical issues, it automatically offers to generate a fix plan and execute it.

**Automatic Fix Flow**:
```
/qa → ❌ Critical issues detected
    ↓
"Generate fix plan?" → Yes
    ↓
/plan "Fix critical issues from QA report: ..."
    ↓
Fix plan created at .thoughts/plans/plan-YYYY-MM-DD-fix-*.md
    ↓
"Execute fix plan?" → Yes
    ↓
/implement fix-plan-name
    ↓
/qa → Re-validation
    ↓
✅ Pass or iterate
```

**Manual Fix Flow**:
```
/qa → ❌ Critical issues detected → Decline auto-fix
    ↓
Review QA report manually
    ↓
Fix issues manually or create plan: /plan "Fix [specific issue]"
    ↓
/qa → Re-validation
```

**Oneshot with Auto-Fix**:

The `/oneshot` command automatically attempts fix workflows when QA fails:
```
/oneshot "Feature" → Research → Plan → Implement → QA
                                                     ↓
                                          ❌ Fails with critical issues
                                                     ↓
                                    "Auto-fix and re-validate?" → Yes
                                                     ↓
                        /plan "Fix..." → /implement fix → /qa
                                                     ↓
                                          ✅ Pass → Complete oneshot
```

**Benefits of Fix Workflow**:
- ✅ Reuses existing plan/implement infrastructure
- ✅ Fix plans documented like feature plans
- ✅ Handles complex multi-step fixes
- ✅ Full audit trail in `.thoughts/plans/`
- ✅ Iterative: Can re-run `/qa` to generate new fix plans

---

## Workflow Sequence

The recommended workflow for new features:

1. **Interview** (`/interview`) - Optional: Gather context and clarify requirements
2. **Research** (`/research`) - Understand current implementation
3. **Plan** (`/plan`) - Create detailed implementation plan
4. **Implement** (`/implement`) - Execute plan with verification
5. **QA** (`/qa`) - Validate against success criteria

---

## Customization

These commands were generated based on your project configuration. You can edit them directly:

- `.claude/commands/interview.md`
- `.claude/commands/research.md`
- `.claude/commands/plan.md`
- `.claude/commands/implement.md`
- `.claude/commands/qa.md`
- `.claude/commands/oneshot.md`

To regenerate: `/meta:workflow-generator`

---

## Custom Agents

You can define custom agents in `.claude/agents/` for specialized validation or analysis tasks. Custom agents are particularly useful for:

- Project-specific quality checks
- Domain-specific code analysis
- Custom documentation validation
- Security scanning tailored to your stack

**Example**: The ash_agent project uses custom agents like:
- `consistency-checker` - Validates docs match code
- `documentation-completeness-checker` - Ensures all public APIs are documented
- `code-smell-checker` - Detects non-idiomatic Elixir patterns
- `dead-code-detector` - Finds unused functions and modules
- `comment-scrubber` - Removes non-critical comments

See your existing commands for how to invoke custom agents with the Task tool.

---

## Parallel Execution for Performance

When running QA or other multi-check workflows, maximize parallel execution:

**Run all bash commands in a single message**:
```elixir
# Instead of sequential:
mix test          # wait
mix credo         # wait
mix dialyzer      # wait

# Use parallel execution in a single message:
- mix test
- mix credo
- mix dialyzer
# All execute concurrently!
```

**Launch all agents in a single message**:
```elixir
# Instead of sequential:
Task(consistency-checker)     # wait
Task(code-smell-checker)      # wait

# Use parallel execution:
- Task(consistency-checker)
- Task(code-smell-checker)
# All launch concurrently!
```

This can reduce QA execution time from minutes to seconds.

---

## Project Configuration

**Project Type**: Library/Package
**Tech Stack**: Elixir
**Test Command**: mix test --warnings-as-errors
**Documentation**: .thoughts
**Planning Style**: Detailed phases

**Quality Tools**:
- Credo (Static code analysis)
- Dialyzer (Type checking)
- Sobelow (Security scanning)
- ExDoc (Documentation generation)

---

## Quick Start

### 1. Research the Codebase

```bash
/research "How does [feature] work?"
```

This will:
- Spawn parallel research agents
- Document findings with file:line references
- Save to `.thoughts/research-YYYY-MM-DD-topic.md`

### 2. Create an Implementation Plan

```bash
/plan "Add new feature X"
```

This will:
- Gather context via research
- Present design options
- Create phased plan with success criteria
- Save to `.thoughts/plans/YYYY-MM-DD-feature-x.md`

### 3. Execute the Plan

```bash
/implement "2025-01-23-feature-x"
```

This will:
- Read the plan
- Execute phase by phase
- Run verification after each phase
- Update checkmarks
- Pause for confirmation

### 4. Validate Implementation

```bash
/qa "feature-x"
```

This will:
- Run all quality gate checks
- Generate validation report
- Provide actionable feedback
- Offer fix plan if needed

---

## Workflow Example

**Scenario**: Adding a new library module

```bash
# 0. Optional: Gather context first
/interview research

# 1. Research existing patterns
/research "How are library modules structured in this codebase?"

# 2. Create implementation plan
/plan "Add DataProcessor module with validation"

# 3. Execute the plan
/implement "2025-01-23-data-processor"

# 4. Validate implementation
/qa "data-processor"
```

**Or use oneshot for full automation**:
```bash
/oneshot "Add DataProcessor module with validation"
```

---

## Documentation

All workflow documents are stored in `.thoughts/`:

```
.thoughts/
├── interview/              # Context gathering sessions
│   └── interview-YYYY-MM-DD-phase-topic.md
├── research/               # Research documents
│   └── research-YYYY-MM-DD-topic.md
├── plans/                  # Implementation plans
│   └── YYYY-MM-DD-description.md
└── qa-reports/             # QA validation reports
    └── YYYY-MM-DD-plan-name-qa.md
```

---

## Next Steps

1. ✅ Try your first research: `/research "project structure"`
2. Read full command documentation in `.claude/commands/`
3. Customize commands as needed (edit `.claude/commands/*.md`)
4. Define custom agents in `.claude/agents/` for specialized tasks
5. Start your first planned feature!

**Need help?** Each command has detailed instructions in its markdown file.
