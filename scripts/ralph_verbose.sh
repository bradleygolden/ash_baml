#!/bin/bash

# Ralph Wiggum Loop with Verbose Real-Time Output
# Shows Claude's thinking, tool usage, and results as they happen

set -e

PROJECT_DIR="/Users/bradleygolden/Development/bradleygolden/ash_baml"
PROMPT_FILE="$PROJECT_DIR/RALPH_PROMPT.md"
MAX_ITERATIONS=100

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found (brew install jq)"
    exit 1
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Ralph Loop - Verbose Real-Time Mode                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${YELLOW}⚠️  Verbose mode shows Claude's real-time actions${NC}"
echo "   You'll see: thinking, file edits, bash commands, results"
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

    # Stream Claude's output with real-time parsing
    cat "$PROMPT_FILE" | claude --print --output-format stream-json --include-partial-messages --verbose --dangerously-skip-permissions | \
    while IFS= read -r line; do
        # Parse the JSON event
        event_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

        case "$event_type" in
            "message_start")
                echo -e "${CYAN}🤖 Claude is thinking...${NC}"
                ;;
            "content_block_start")
                block_type=$(echo "$line" | jq -r '.content_block.type // empty' 2>/dev/null)
                if [ "$block_type" = "tool_use" ]; then
                    tool_name=$(echo "$line" | jq -r '.content_block.name // empty' 2>/dev/null)
                    tool_id=$(echo "$line" | jq -r '.content_block.id // empty' 2>/dev/null)
                    echo ""
                    echo -e "${MAGENTA}🔧 Using tool: $tool_name${NC} (id: $tool_id)"
                fi
                ;;
            "content_block_delta")
                delta_type=$(echo "$line" | jq -r '.delta.type // empty' 2>/dev/null)
                if [ "$delta_type" = "text_delta" ]; then
                    text=$(echo "$line" | jq -r '.delta.text // empty' 2>/dev/null)
                    printf "%s" "$text"
                elif [ "$delta_type" = "input_json_delta" ]; then
                    # Tool input is being streamed
                    partial=$(echo "$line" | jq -r '.delta.partial_json // empty' 2>/dev/null)
                    if [ -n "$partial" ]; then
                        echo -e "${YELLOW}  Input: ${partial}${NC}"
                    fi
                fi
                ;;
            "content_block_stop")
                # Block completed
                ;;
            "message_delta")
                stop_reason=$(echo "$line" | jq -r '.delta.stop_reason // empty' 2>/dev/null)
                if [ "$stop_reason" = "end_turn" ]; then
                    echo ""
                    echo -e "${GREEN}✓ Iteration complete${NC}"
                fi
                ;;
        esac
    done

    echo ""
    echo ""
    echo "Waiting 1 second before next iteration..."
    sleep 1
done

if [ $ITERATION -eq $MAX_ITERATIONS ]; then
    echo "⚠ Maximum iterations reached"
fi

echo ""
echo "Ralph loop complete"
