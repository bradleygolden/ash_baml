#!/bin/bash

# Simple Ralph Wiggum Loop for Claude CLI
# Usage: export OPENAI_API_KEY='sk-proj-...' && ./scripts/ralph.sh
#
# IMPORTANT: This script uses --dangerously-skip-permissions to allow
# autonomous file editing and test execution without prompts.
# Only run in trusted directories!

set -e

PROJECT_DIR="/Users/bradleygolden/Development/bradleygolden/ash_baml"
PROMPT_FILE="$PROJECT_DIR/RALPH_PROMPT.md"
MAX_ITERATIONS=100

# Check API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY not set"
    echo "Usage: export OPENAI_API_KEY='sk-proj-...' && ./scripts/ralph.sh"
    exit 1
fi

# Check Claude CLI
if ! command -v claude &> /dev/null; then
    echo "Error: Claude CLI not found"
    echo "Install from: https://www.claude.com/claude-code"
    exit 1
fi

# Check for jq (needed for streaming JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found (needed for streaming output)"
    echo "Install: brew install jq"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  Ralph Wiggum Loop                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  This will run Claude with --dangerously-skip-permissions"
echo "   Claude will autonomously edit files and run tests"
echo "   Press Ctrl+C anytime to stop"
echo ""
echo "Directory: $PROJECT_DIR"
echo "Max iterations: $MAX_ITERATIONS"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi
echo ""
echo "Starting autonomous test improvement loop..."
echo ""

ITERATION=0

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))

    # Check if mission complete
    if grep -q "MISSION COMPLETE" "$PROMPT_FILE"; then
        echo ""
        echo "🎉 MISSION COMPLETE!"
        echo "All tests implemented and verified!"
        break
    fi

    # Count progress
    COMPLETED=$(grep -c "\[x\]" "$PROMPT_FILE" 2>/dev/null || echo "0")

    echo "─────────────────────────────────────────────────────────────"
    echo "Iteration $ITERATION | Completed: $COMPLETED tests"
    echo "─────────────────────────────────────────────────────────────"

    # Run Claude with streaming output to see progress in real-time
    cat "$PROMPT_FILE" | claude --print --output-format stream-json --include-partial-messages --verbose --dangerously-skip-permissions | \
    while IFS= read -r line; do
        # Parse JSON and extract text content
        text=$(echo "$line" | jq -r '.delta.text // empty' 2>/dev/null)
        if [ -n "$text" ]; then
            printf "%s" "$text"
        fi
    done
    echo ""  # Final newline

    echo ""
    echo "Waiting 1 second before next iteration..."
    sleep 1
done

if [ $ITERATION -eq $MAX_ITERATIONS ]; then
    echo "⚠ Maximum iterations reached. Check RALPH_PROMPT.md for progress."
fi

echo ""
echo "Ralph loop complete. Check test/integration/ for new tests."
