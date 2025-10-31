#!/bin/bash

# Single Ralph Iteration Script
# Run this each time Claude completes a task to trigger the next iteration

PROJECT_DIR="/Users/bradleygolden/Development/bradleygolden/ash_baml"
PROMPT_FILE="$PROJECT_DIR/RALPH_PROMPT.md"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Ralph Iteration - Next Task                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Count progress
COMPLETED=$(grep -c "\[x\]" "$PROMPT_FILE" 2>/dev/null || echo "0")
PENDING=$(grep -c "\[ \]" "$PROMPT_FILE" 2>/dev/null || echo "0")

echo -e "${GREEN}✓ Completed:${NC} $COMPLETED tests"
echo -e "${BLUE}⧗ Pending:${NC} $PENDING tests"
echo ""

# Find next task
NEXT_TASK=$(grep -m 1 "^\s*- \[ \]" "$PROMPT_FILE" | sed 's/^[[:space:]]*- \[ \] //')

if [ -z "$NEXT_TASK" ]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${GREEN}🎉 ALL TASKS COMPLETE! 🎉${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Next steps:"
    echo "  1. Run full suite: mix test --include integration"
    echo "  2. Check coverage: $COMPLETED tests implemented"
    echo "  3. Delete temporary API key"
    echo ""
    exit 0
fi

echo "─────────────────────────────────────────────────────────────"
echo -e "${YELLOW}Next Task:${NC}"
echo ""
echo "  $NEXT_TASK"
echo ""
echo "─────────────────────────────────────────────────────────────"
echo ""
echo "Copy this prompt to Claude:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat << EOF

Read RALPH_PROMPT.md and execute the current task:
- Implement the next unchecked test
- Run it with the API key
- Verify it passes
- Update RALPH_PROMPT.md
- Report completion

EOF
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "After Claude completes, run: ./scripts/ralph_iteration.sh"
echo ""
