#!/bin/bash
cd /home/patso/repos/b2

FAILED_FILE="/tmp/failed_targets.txt"
> "$FAILED_FILE"

succeeded=0
failed=0
total=0

while read -r target; do
    total=$((total + 1))
    echo "[$total] Building: $target"
    if buck2 build "$target" 2>&1 | grep -q "BUILD SUCCEEDED"; then
        succeeded=$((succeeded + 1))
        echo "  ✓ SUCCESS"
    else
        failed=$((failed + 1))
        echo "$target" >> "$FAILED_FILE"
        echo "  ✗ FAILED"
    fi
done < <(head -50 /tmp/all_targets.txt)

echo ""
echo "=== SUMMARY ==="
echo "Succeeded: $succeeded / $total"
echo "Failed: $failed / $total"
echo ""
echo "Failed targets saved to: $FAILED_FILE"
