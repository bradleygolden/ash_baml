#!/bin/bash

# Ralph Loop - Working Version
# Properly handles Claude completion and continues to next iteration

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
echo "║           Ralph Loop - Working Version                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Output directory: $OUTPUT_DIR/"
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
    PROGRESS_FILE="$OUTPUT_DIR/iteration_${ITERATION}.progress"

    # Read prompt
    PROMPT=$(cat "$PROMPT_FILE")

    echo -e "${YELLOW}Running Claude...${NC}"
    echo "Output: $OUTPUT_FILE"
    echo ""

    # Run Claude and capture output, marking when done
    (
        claude -p "$PROMPT" --verbose --dangerously-skip-permissions > "$OUTPUT_FILE" 2>&1
        echo "DONE" > "$PROGRESS_FILE"
    ) &
    CLAUDE_PID=$!

    # Show live output with timeout detection
    echo "════════════════════════════════════════════════════════════"
    WAIT_COUNT=0
    MAX_WAIT=600  # 10 minutes timeout

    while [ ! -f "$PROGRESS_FILE" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        if [ -f "$OUTPUT_FILE" ]; then
            # Show new content if file exists
            tail -n 50 "$OUTPUT_FILE" 2>/dev/null || true
        fi
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))

        # Check if Claude is still running
        if ! kill -0 $CLAUDE_PID 2>/dev/null; then
            # Claude finished
            break
        fi
    done

    # Wait for Claude to fully complete
    wait $CLAUDE_PID 2>/dev/null || true

    # Show final output
    if [ -f "$OUTPUT_FILE" ]; then
        echo ""
        echo "Final output:"
        tail -n 100 "$OUTPUT_FILE"
    fi

    echo "════════════════════════════════════════════════════════════"
    echo ""

    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo -e "${YELLOW}⚠ Claude timed out after 10 minutes${NC}"
        echo "Check $OUTPUT_FILE for details"
        break
    fi

    if [ -f "$PROGRESS_FILE" ]; then
        echo -e "${GREEN}✓ Iteration complete${NC}"
    else
        echo -e "${YELLOW}⚠ Iteration may not have completed properly${NC}"
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
echo "All output in: $OUTPUT_DIR/"
