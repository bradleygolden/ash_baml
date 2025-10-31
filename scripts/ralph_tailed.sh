#!/bin/bash

# Ralph Loop with Tailed Output
# Writes to file and tails it for real-time visibility

set -e

PROJECT_DIR="/Users/bradleygolden/Development/bradleygolden/ash_baml"
PROMPT_FILE="$PROJECT_DIR/RALPH_PROMPT.md"
OUTPUT_DIR="$PROJECT_DIR/.thoughts/ralph_output"
MAX_ITERATIONS=100

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Ralph Loop - Tailed Output Mode                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Output will be written to: $OUTPUT_DIR/"
echo "You'll see real-time updates via tail -f"
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
        echo -e "${GREEN}🎉 MISSION COMPLETE!${NC}"
        break
    fi

    COMPLETED=$(grep -c "\[x\]" "$PROMPT_FILE" 2>/dev/null || echo "0")

    echo "─────────────────────────────────────────────────────────────"
    echo -e "${BLUE}Iteration $ITERATION${NC} | ${GREEN}Completed: $COMPLETED${NC}"
    echo "─────────────────────────────────────────────────────────────"
    echo ""

    # Create output file for this iteration
    OUTPUT_FILE="$OUTPUT_DIR/iteration_${ITERATION}.log"

    # Read prompt
    PROMPT=$(cat "$PROMPT_FILE")

    echo -e "${YELLOW}Starting Claude...${NC}"
    echo "Output file: $OUTPUT_FILE"
    echo ""

    # Start Claude in background, writing to file
    claude -p "$PROMPT" --verbose --dangerously-skip-permissions > "$OUTPUT_FILE" 2>&1 &
    CLAUDE_PID=$!

    # Give it a moment to start
    sleep 1

    # Tail the output file in real-time
    echo "════════════════════════════════════════════════════════════"
    echo "Claude Output (streaming from $OUTPUT_FILE):"
    echo "════════════════════════════════════════════════════════════"

    # Tail the file until Claude process completes
    tail -f "$OUTPUT_FILE" --pid=$CLAUDE_PID 2>/dev/null || true

    # Wait for Claude to finish
    wait $CLAUDE_PID
    CLAUDE_EXIT=$?

    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo ""

    if [ $CLAUDE_EXIT -ne 0 ]; then
        echo -e "${YELLOW}⚠ Claude exited with code $CLAUDE_EXIT${NC}"
        echo "Check $OUTPUT_FILE for details"
        echo ""
        read -p "Continue to next iteration? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            break
        fi
    else
        echo -e "${GREEN}✓ Iteration complete${NC}"
    fi

    echo ""
    echo "Waiting 2 seconds before next iteration..."
    sleep 2
done

if [ $ITERATION -eq $MAX_ITERATIONS ]; then
    echo -e "${YELLOW}⚠ Maximum iterations reached${NC}"
fi

echo ""
echo "Ralph loop complete"
echo ""
echo "All output saved in: $OUTPUT_DIR/"
echo "Latest: $OUTPUT_FILE"
