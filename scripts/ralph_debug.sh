#!/bin/bash

# Ralph Loop Debug - See what's actually happening

set -e

PROJECT_DIR="/Users/bradleygolden/Development/bradleygolden/ash_baml"
PROMPT_FILE="$PROJECT_DIR/RALPH_PROMPT.md"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Ralph Loop - Debug Mode                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "✗ OPENAI_API_KEY not set"
    exit 1
else
    echo "✓ OPENAI_API_KEY is set"
fi

# Check Claude CLI
if ! command -v claude &> /dev/null; then
    echo "✗ Claude CLI not found"
    exit 1
else
    echo "✓ Claude CLI found: $(which claude)"
fi

# Check prompt file
if [ ! -f "$PROMPT_FILE" ]; then
    echo "✗ RALPH_PROMPT.md not found"
    exit 1
else
    echo "✓ RALPH_PROMPT.md found"
    PROMPT_SIZE=$(wc -c < "$PROMPT_FILE")
    echo "  Size: $PROMPT_SIZE bytes"
fi

echo ""
echo "─────────────────────────────────────────────────────────────"
echo "Testing Claude CLI directly (single iteration)..."
echo "─────────────────────────────────────────────────────────────"
echo ""

# Try to run Claude and capture stderr too
echo "Running command:"
echo "cat RALPH_PROMPT.md | claude --print --output-format text --verbose --dangerously-skip-permissions"
echo ""
echo "Output:"
echo "========================================================================"

cat "$PROMPT_FILE" | claude --print --output-format text --verbose --dangerously-skip-permissions 2>&1

echo ""
echo "========================================================================"
echo ""
echo "Debug complete. Did you see Claude's response above?"
