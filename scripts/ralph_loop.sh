#!/bin/bash

# Ralph Wiggum Loop for Autonomous Test Improvement
# Inspired by: https://ghuntley.com/ralph/
#
# This creates a continuous loop where Claude autonomously:
# 1. Reads RALPH_PROMPT.md for instructions
# 2. Implements the next test
# 3. Runs and verifies it
# 4. Updates RALPH_PROMPT.md with progress
# 5. Repeats until complete

set -e

PROJECT_DIR="/Users/bradleygolden/Development/bradleygolden/ash_baml"
PROMPT_FILE="$PROJECT_DIR/RALPH_PROMPT.md"
LOG_FILE="$PROJECT_DIR/.thoughts/ralph_loop.log"
ITERATION=0
MAX_ITERATIONS=100  # Safety limit

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Ralph Wiggum Loop - Autonomous Testing             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if API key is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${RED}✗ OPENAI_API_KEY not set${NC}"
    echo ""
    echo "Usage:"
    echo "  export OPENAI_API_KEY='sk-proj-...'"
    echo "  ./scripts/ralph_loop.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} API key is set"
echo ""

# Check if prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED}✗ RALPH_PROMPT.md not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} RALPH_PROMPT.md found"
echo ""

# Initialize log
echo "Ralph Loop Started: $(date)" > "$LOG_FILE"
echo "Max Iterations: $MAX_ITERATIONS" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "═══════════════════════════════════════════════════════════════"
echo " Starting Ralph Loop"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Press Ctrl+C at any time to stop gracefully"
echo ""
sleep 2

# Function to check if mission is complete
check_completion() {
    if grep -q "MISSION COMPLETE" "$PROMPT_FILE"; then
        return 0
    fi
    return 1
}

# Function to count completed tests
count_completed() {
    grep -c "\[x\]" "$PROMPT_FILE" || echo "0"
}

# Trap Ctrl+C for graceful exit
trap 'echo ""; echo "Ralph loop interrupted by user"; exit 0' INT

# Main Ralph loop
while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))
    COMPLETED=$(count_completed)

    echo "─────────────────────────────────────────────────────────────"
    echo -e "${BLUE}Iteration $ITERATION${NC} | ${GREEN}Completed: $COMPLETED tests${NC}"
    echo "─────────────────────────────────────────────────────────────"
    echo ""

    # Check if mission complete
    if check_completion; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "${GREEN}🎉 MISSION COMPLETE! 🎉${NC}"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "All tests implemented and verified!"
        echo "Total iterations: $ITERATION"
        echo "Tests completed: $COMPLETED"
        echo ""
        echo "Next steps:"
        echo "  1. Review test files in test/integration/"
        echo "  2. Run full suite: mix test --include integration"
        echo "  3. Delete temporary API key"
        echo ""
        break
    fi

    # Log iteration
    echo "--- Iteration $ITERATION ---" >> "$LOG_FILE"
    echo "Timestamp: $(date)" >> "$LOG_FILE"

    # Claude Code CLI approach (if available)
    # Note: As of 2025, Claude Code may not have a CLI mode that accepts piped input
    # This is a placeholder for when/if that capability exists

    if command -v claude &> /dev/null; then
        echo -e "${YELLOW}Running Claude CLI...${NC}"
        cat "$PROMPT_FILE" | claude --print --output-format stream-json --include-partial-messages --verbose --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"
    else
        # Fallback: Interactive mode (requires manual intervention)
        echo -e "${YELLOW}Claude CLI not available. Using interactive mode.${NC}"
        echo ""
        echo "════════════════════════════════════════════════════════════"
        echo "Manual Iteration Required"
        echo "════════════════════════════════════════════════════════════"
        echo ""
        echo "In your Claude Code session, say:"
        echo ""
        echo -e "${GREEN}\"Read RALPH_PROMPT.md and execute the current task\"${NC}"
        echo ""
        echo "After Claude completes the task and updates RALPH_PROMPT.md:"
        echo ""
        echo -e "  ${BLUE}[ENTER]${NC} - Continue to next iteration"
        echo -e "  ${BLUE}[Q]${NC} - Quit the loop"
        echo ""
        read -p "Your choice: " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Qq]$ ]]; then
            echo ""
            echo "Ralph loop stopped by user"
            echo "Progress saved in RALPH_PROMPT.md"
            echo "Resume anytime by running this script again"
            break
        fi
    fi

    # Small delay between iterations
    sleep 1

    echo "" | tee -a "$LOG_FILE"
done

# Check if we hit max iterations
if [ $ITERATION -eq $MAX_ITERATIONS ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${YELLOW}⚠ Maximum iterations reached ($MAX_ITERATIONS)${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Progress saved in RALPH_PROMPT.md"
    echo "Increase MAX_ITERATIONS in script if needed"
    echo ""
fi

echo ""
echo "Ralph loop completed: $(date)" | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE"
echo ""
