#!/bin/bash

# Autonomous Test Improvement Loop
# This script helps kick off the AI agent's autonomous test development cycle

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    AshBaml Autonomous Test Improvement Loop                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "This will start an autonomous loop where Claude will:"
echo "  1. Implement comprehensive integration tests"
echo "  2. Run them with your provided API key"
echo "  3. Verify they work correctly"
echo "  4. Iterate until coverage is complete"
echo ""
echo "Expected cost: ~\$0.01 total (using gpt-4o-mini)"
echo "Expected tests: ~60 integration tests"
echo "Expected time: ~10-15 minutes for full loop"
echo ""

# Check if API key is provided
if [ -z "$1" ]; then
    echo "Usage: ./scripts/autonomous_test_improvement.sh <OPENAI_API_KEY>"
    echo ""
    echo "To get an API key:"
    echo "  1. Go to https://platform.openai.com/api-keys"
    echo "  2. Create a new API key"
    echo "  3. Set usage limit to \$1-5 at https://platform.openai.com/usage"
    echo "  4. Run this script with the key as an argument"
    echo ""
    exit 1
fi

export OPENAI_API_KEY="$1"

echo "✓ API key set"
echo ""

# Verify the key works by running existing integration tests
echo "═══════════════════════════════════════════════════════════════"
echo "Step 1: Verifying API key with existing tests..."
echo "═══════════════════════════════════════════════════════════════"
echo ""

if mix test --include integration 2>&1 | tee /tmp/ashbaml_test_output.log; then
    echo ""
    echo "✓ Existing integration tests passed!"
    echo ""
else
    echo ""
    echo "✗ Integration tests failed. Check API key and try again."
    echo "Error output saved to: /tmp/ashbaml_test_output.log"
    echo ""
    echo "Common issues:"
    echo "  - Invalid API key"
    echo "  - Usage limit reached"
    echo "  - Network connectivity"
    echo ""
    exit 1
fi

# Count current tests
CURRENT_TESTS=$(grep -r "@moduletag :integration" test/integration/ | wc -l | tr -d ' ')
echo "Current integration test files: $CURRENT_TESTS"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "Step 2: Ready to begin autonomous test development"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "The AI agent (Claude) will now:"
echo "  • Implement Phase 1: Streaming, Auto-generated Actions, Telemetry"
echo "  • Implement Phase 2: Error Handling, Edge Cases"
echo "  • Implement Phase 3: Advanced Scenarios, Regression Tests"
echo ""
echo "Each test will be:"
echo "  • Written"
echo "  • Executed with your API key"
echo "  • Verified"
echo "  • Fixed if needed"
echo ""
echo "You can monitor progress in real-time as tests are created."
echo ""
echo "Press ENTER to continue or Ctrl+C to cancel..."
read

# Create progress tracking file
PROGRESS_FILE=".thoughts/test-improvement-progress.md"
cat > "$PROGRESS_FILE" <<EOF
# Test Improvement Progress

**Started**: $(date)
**API Key**: Set (budget limited)
**Initial Tests**: $CURRENT_TESTS integration test files

## Progress Tracking

### Phase 1: Core Functionality
- [ ] Streaming tests
- [ ] Auto-generated actions E2E
- [ ] Telemetry with real API

### Phase 2: Error Handling & Edge Cases
- [ ] Error conditions
- [ ] Input edge cases

### Phase 3: Advanced Scenarios
- [ ] Advanced tool calling
- [ ] Regression tests
- [ ] Concurrency tests

## Test Runs

\`\`\`
# Initial verification
$(tail -20 /tmp/ashbaml_test_output.log)
\`\`\`

## Notes

EOF

echo "Progress tracking file created: $PROGRESS_FILE"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Claude is now ready to begin autonomous test development!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps in Claude:"
echo "  1. Say: 'Begin autonomous test improvement loop'"
echo "  2. Claude will implement tests phase by phase"
echo "  3. Claude will run tests and verify they work"
echo "  4. Monitor progress in: $PROGRESS_FILE"
echo ""
echo "💡 Tips:"
echo "  • Tests will be created in test/integration/"
echo "  • Each phase will be implemented sequentially"
echo "  • You can stop at any time and resume later"
echo "  • Final run should cost < \$0.01 total"
echo ""
