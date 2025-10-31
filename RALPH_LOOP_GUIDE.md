# Ralph Wiggum Loop - Implementation Guide

## What is the Ralph Loop?

The Ralph Wiggum loop (named after the Simpsons character) is an autonomous development pattern where:

1. **Instructions live in a file** (`RALPH_PROMPT.md`)
2. **AI agent reads and executes** the current task
3. **AI agent updates the file** with progress
4. **Loop repeats** until mission complete

This creates a **self-directed, autonomous improvement cycle** where the AI continuously works toward a goal without manual intervention between iterations.

**Inspiration**: https://ghuntley.com/ralph/

## How It Works Here

```
┌─────────────────────────────────────────────┐
│  RALPH_PROMPT.md                            │
│  ├─ Current Mission                         │
│  ├─ Task Checklist                          │
│  ├─ [ ] Next Task ← AI reads this          │
│  ├─ [x] Completed Task                      │
│  └─ Instructions                            │
└─────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────┐
│  Claude (AI Agent)                          │
│  1. Reads RALPH_PROMPT.md                   │
│  2. Identifies next unchecked task          │
│  3. Implements the test                     │
│  4. Runs test with API key                  │
│  5. Verifies it passes                      │
│  6. Updates RALPH_PROMPT.md                 │
│     - Marks task [x] complete               │
│     - Adds learnings/notes                  │
│     - Updates next task pointer             │
└─────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────┐
│  Loop Script                                │
│  - Detects completion                       │
│  - Shows next task                          │
│  - Continues until all tasks done           │
└─────────────────────────────────────────────┘
```

## Two Approaches

### Approach 1: Semi-Automated (Current)

Since Claude Code doesn't yet have a CLI that accepts piped input, we use a **hybrid approach**:

**Setup:**
```bash
export OPENAI_API_KEY='sk-proj-YOUR-KEY-HERE'
```

**Each iteration:**
```bash
# Shows next task and provides prompt
./scripts/ralph_iteration.sh

# Copy the shown prompt to Claude
# Claude executes, updates RALPH_PROMPT.md, reports completion

# Run again to get next task
./scripts/ralph_iteration.sh
```

**Progress tracked automatically** in `RALPH_PROMPT.md`

### Approach 2: Fully Automated (Future)

When Claude CLI supports piped input:

```bash
export OPENAI_API_KEY='sk-proj-YOUR-KEY-HERE'

# Runs continuously until complete
while :; do
  cat RALPH_PROMPT.md | claude --mode code --non-interactive
  sleep 2
done
```

## Quick Start

### Step 1: Set Up API Key

```bash
# Create temporary API key at https://platform.openai.com/api-keys
# Set usage limit to $1-5

export OPENAI_API_KEY='sk-proj-YOUR-KEY-HERE'
```

### Step 2: Start First Iteration

```bash
./scripts/ralph_iteration.sh
```

This shows:
- Progress summary (completed vs pending)
- Next task to implement
- Prompt to copy to Claude

### Step 3: Copy Prompt to Claude

```
Read RALPH_PROMPT.md and execute the current task:
- Implement the next unchecked test
- Run it with the API key
- Verify it passes
- Update RALPH_PROMPT.md
- Report completion
```

### Step 4: Watch Claude Work

Claude will:
1. Read `RALPH_PROMPT.md`
2. Find next `[ ]` unchecked task
3. Implement that test
4. Run it: `mix test <file> --include integration`
5. Debug if needed
6. Update `RALPH_PROMPT.md`:
   - Change `[ ]` to `[x]`
   - Add notes
7. Report completion

### Step 5: Continue Loop

```bash
./scripts/ralph_iteration.sh
```

Repeat steps 3-5 until all tasks complete!

## The Ralph Prompt File

`RALPH_PROMPT.md` is the **source of truth**. It contains:

### 1. Mission Statement
```markdown
## Current Mission
Expand the ash_baml integration test suite from 3 tests to ~60 comprehensive tests.
```

### 2. Task Checklist
```markdown
### Phase 1: Core Functionality
- [ ] Test: streams response chunks as they arrive
- [x] Test: completes stream and returns final result  ← Completed
- [ ] Test: handles stream with telemetry enabled     ← Next
```

### 3. Current Task Pointer
```markdown
## Current Task
**IMPLEMENT THE NEXT UNCHECKED ITEM IN PHASE 1**
```

### 4. Instructions
```markdown
## Instructions for This Iteration
1. Identify the next unchecked test
2. Implement that specific test
3. Run and verify it passes
4. Update this file
5. Report status
```

### 5. Learnings & Notes
```markdown
## Learnings & Notes
- Streaming tests need `async: false` due to process cleanup
- Token counting requires `BamlElixir.Collector` in collector_opts
- gpt-4o-mini responses are consistent enough for assertions
```

## Progress Tracking

Ralph automatically tracks:

### In RALPH_PROMPT.md
- ✅ Checked tasks `[x]` = completed
- ⧗ Unchecked tasks `[ ]` = pending
- 📝 Notes section = learnings
- 📊 Progress section = statistics

### In .thoughts/ralph_loop.log
- Timestamp of each iteration
- Actions taken
- Test results
- Costs incurred

### Via ralph_iteration.sh
```
╔══════════════════════════════════════════════════════════════╗
║              Ralph Iteration - Next Task                     ║
╚══════════════════════════════════════════════════════════════╝

✓ Completed: 12 tests
⧗ Pending: 48 tests

─────────────────────────────────────────────────────────────
Next Task:

  Test: telemetry works with streaming calls

─────────────────────────────────────────────────────────────
```

## Safety Features

### 1. Mission Complete Detection
When all tasks are `[x]` checked, the loop stops automatically:

```
═══════════════════════════════════════════════════════════════
🎉 ALL TASKS COMPLETE! 🎉
═══════════════════════════════════════════════════════════════
```

### 2. Max Iterations Limit
`ralph_loop.sh` has `MAX_ITERATIONS=100` to prevent infinite loops

### 3. Manual Exit
Press `Ctrl+C` anytime to stop gracefully. Progress is saved.

### 4. Cost Tracking
Each iteration reports estimated cost. Budget protection via OpenAI dashboard.

### 5. Skip Mechanism
If stuck, mark task as `[~]` and add note:
```markdown
- [~] Test: complex edge case (skipped - needs upstream fix)
```

## Real-World Usage

### Typical Session

```bash
# Terminal 1: Set up
$ export OPENAI_API_KEY='sk-proj-...'
$ ./scripts/ralph_iteration.sh

# Shows: Next task is "Test: streams response chunks"

# In Claude Code: Copy/paste the prompt
# Claude implements streaming test, runs it, updates RALPH_PROMPT.md

# Terminal 1: Next iteration
$ ./scripts/ralph_iteration.sh

# Shows: Next task is "Test: completes stream"

# In Claude Code: Copy/paste again
# Claude implements next test, runs it, updates file

# Repeat ~60 times until complete (20-30 minutes)

# Terminal 1: Final check
$ ./scripts/ralph_iteration.sh

# Shows: 🎉 ALL TASKS COMPLETE! 🎉

# Verify everything
$ mix test --include integration

# Clean up
$ # Delete API key at https://platform.openai.com/api-keys
```

### Expected Timeline

- **Setup**: 2 minutes
- **Per iteration**: 20-30 seconds of Claude work
- **60 iterations**: ~20-30 minutes total
- **Final verification**: 1-2 minutes

**Total**: ~25-35 minutes from start to finish

## Advanced Usage

### Parallel Phases

Edit `RALPH_PROMPT.md` to work on multiple phases:

```markdown
## Current Task
IMPLEMENT ANY UNCHECKED ITEM FROM ANY PHASE
```

Claude will pick tasks dynamically.

### Custom Priorities

Reorder tasks in `RALPH_PROMPT.md` to change priority.

### Batch Operations

Implement multiple related tests per iteration:

```markdown
## Current Task
IMPLEMENT ALL UNCHECKED STREAMING TESTS
```

### Debug Mode

Add to instructions:
```markdown
5. After implementing test, run it 3 times to check for flakiness
6. Add debug output to learnings section
```

## Troubleshooting

### "Claude isn't updating RALPH_PROMPT.md"

**Solution**: Be explicit in your iteration prompt:
```
Read RALPH_PROMPT.md, implement the next test,
AND UPDATE RALPH_PROMPT.md before reporting completion.
```

### "Tasks not being marked complete"

**Solution**: Check file for correct syntax:
```markdown
- [x] Test: completed  ✓ Correct
- [X] Test: completed  ✗ Wrong (capital X)
-[x] Test: completed   ✗ Wrong (no space after -)
```

### "Too many tests failing"

**Solution**: Add to prompt:
```markdown
If test fails 3 times, mark as [~] skipped and move to next test.
Document the issue in Learnings section.
```

### "Costs adding up"

**Solution**: Check OpenAI dashboard. Each test should be ~$0.0001.
If higher, tests may be using too many tokens. Simplify prompts.

### "Loop is slow"

**Solution**: This is normal! Each iteration includes:
- Claude reading and planning: 5-10s
- Implementing test code: 5-10s
- Running test with API: 2-5s
- Updating file: 2-3s

Total: 15-30s per iteration is expected.

## Tips for Success

### 1. Start Small
Begin with Phase 1 only. Verify the loop works before expanding.

### 2. Clear Instructions
The clearer `RALPH_PROMPT.md` instructions, the better Claude performs.

### 3. Celebrate Progress
Check `./scripts/ralph_iteration.sh` frequently to see progress!

### 4. Learn as You Go
Read the "Learnings" section after each phase. Patterns emerge.

### 5. Trust the Process
Ralph is "deterministically bad but self-correcting" - let it iterate!

## Comparison to Manual Testing

### Manual Approach
```
Developer: Implements test
Developer: Runs test
Developer: Debugs failures
Developer: Implements next test
Developer: Runs test
Developer: Debugs failures
...repeat 60 times...

Time: 3-4 hours
Cost: $0 API, $150-200 developer time
```

### Ralph Approach
```
Developer: Sets up Ralph, provides API key
Claude: Implements test
Claude: Runs test
Claude: Debugs failures
Claude: Implements next test
Claude: Runs test
Claude: Debugs failures
...repeats 60 times autonomously...

Time: 30 minutes (mostly automated)
Cost: $0.01 API, $10-20 developer time (setup + verification)

Savings: 3+ hours developer time
```

## Files Created

```
RALPH_PROMPT.md                      # The prompt file (source of truth)
RALPH_LOOP_GUIDE.md                  # This file
scripts/ralph_loop.sh                # Automated loop (future)
scripts/ralph_iteration.sh           # Semi-automated iteration (current)
.thoughts/ralph_loop.log             # Iteration log
.thoughts/test-improvement-progress.md  # Human-readable progress
```

## Next Steps

1. **Set API key**: `export OPENAI_API_KEY='sk-proj-...'`
2. **Start loop**: `./scripts/ralph_iteration.sh`
3. **Copy prompt to Claude**: Follow on-screen instructions
4. **Watch it work**: Claude implements, runs, updates, reports
5. **Repeat**: Run `ralph_iteration.sh` after each completion
6. **Verify**: When complete, run `mix test --include integration`
7. **Clean up**: Delete API key

## Philosophy

From the original Ralph article:

> "Ralph is deterministically bad, but self-correcting through iteration."

The key insight: **Don't aim for perfection on the first iteration**.

Instead:
- Let the AI try
- It will fail or produce suboptimal results
- Update the prompt with clarifications
- AI tries again with better instructions
- Results improve through iteration
- Eventually converges on working solution

This is **exactly what we're doing** with test implementation:
- Each test might fail first time
- Claude debugs and fixes it
- Learnings accumulate
- Later tests benefit from earlier lessons
- Final test suite is comprehensive and robust

## Ready?

```bash
./scripts/ralph_iteration.sh
```

Let's Ralph! 🚀
