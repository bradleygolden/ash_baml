#!/bin/bash

ITERATION=0
START_TIME=$(date +%s)

echo "Ralph starting at $(date)"
echo "=========================================="

while true; do
    ITERATION=$((ITERATION + 1))
    LOOP_START=$(date +%s)

    echo -e "\n[ITERATION $ITERATION] Starting at $(date)"

    cat PROMPT.md | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --verbose \
        | npx repomirror visualize

    LOOP_END=$(date +%s)
    LOOP_DURATION=$((LOOP_END - LOOP_START))
    TOTAL_DURATION=$((LOOP_END - START_TIME))

    echo -e "\n[ITERATION $ITERATION] Completed in ${LOOP_DURATION}s (total runtime: ${TOTAL_DURATION}s)"
    echo "========================LOOP=========================\n"
    sleep 10
done
