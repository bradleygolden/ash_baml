#!/bin/bash

# Ralph Loop - Fixed Version
# Uses prompt as argument, not stdin

set -e

PROJECT_DIR="/Users/bradleygolden/Development/bradleygolden/ash_baml"
PROMPT_FILE="$PROJECT_DIR/RALPH_PROMPT.md"
MAX_ITERATIONS=100

# Check API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY not set"
    exit 1
fi

# Check Claude CLI
if ! command -v claude &> /dev/null; then
    echo "Error: Claude CLI not found"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Ralph Loop - Fixed Version                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi
echo ""

ITERATION=0

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))

    # Check if mission complete
    if grep -q "MISSION COMPLETE" "$PROMPT_FILE"; then
        echo ""
        echo "🎉 MISSION COMPLETE!"
        break
    fi

    COMPLETED=$(grep -c "\[x\]" "$PROMPT_FILE" 2>/dev/null || echo "0")

    echo "─────────────────────────────────────────────────────────────"
    echo "Iteration $ITERATION | Completed: $COMPLETED tests"
    echo "─────────────────────────────────────────────────────────────"
    echo ""

    # Read prompt file content
    PROMPT=$(cat "$PROMPT_FILE")

    # Pass prompt as argument (use -p with the prompt string)
    # For long prompts, we need to be careful with shell argument limits
    claude -p "$PROMPT" --verbose --dangerously-skip-permissions

    echo ""
    echo "Waiting 1 second before next iteration..."
    sleep 1
done

if [ $ITERATION -eq $MAX_ITERATIONS ]; then
    echo "⚠ Maximum iterations reached"
fi

echo ""
echo "Ralph loop complete"
