#!/bin/sh
# Show coverage percentage for Nim TestKit

# Run our coverage script with the correct flags 
cd "$(dirname "$(dirname "$(dirname "$(realpath "$0")")")")" || exit

# Create required directories
mkdir -p build/coverage/raw build/coverage/html

# Manual coverage check for source files
TOTAL_LINES=0
COVERED_LINES=0

echo "Computing coverage by module..."
echo "------------------------------"

for file in src/*.nim; do
  filename=$(basename "$file")
  
  # Skip utility module
  if [ "$filename" = "coverage_helper.nim" ]; then
    continue
  fi
  
  # Run gcov on the file
  gcov -o build/nimcache "$file" > /dev/null 2>&1
  
  # Process gcov output
  if [ -f "$filename.gcov" ]; then
    FILE_TOTAL=$(grep -v "#####:" "$filename.gcov" | grep -v "-:" | wc -l)
    FILE_COVERED=$(grep -v "#####:" "$filename.gcov" | grep -v "-:" | grep -v "^0:" | wc -l)
    
    TOTAL_LINES=$((TOTAL_LINES + FILE_TOTAL))
    COVERED_LINES=$((COVERED_LINES + FILE_COVERED))
    
    if [ "$FILE_TOTAL" -gt 0 ]; then
      COV_PERCENT=$((FILE_COVERED * 100 / FILE_TOTAL))
      echo "$filename: $FILE_COVERED/$FILE_TOTAL lines ($COV_PERCENT%)"
    else
      echo "$filename: No coverable lines found"
    fi
    
    mv "$filename.gcov" "build/coverage/raw/${filename}.gcov"
  else
    echo "$filename: No coverage data found"
  fi
done

echo "------------------------------"
if [ "$TOTAL_LINES" -gt 0 ]; then
  OVERALL_PERCENT=$((COVERED_LINES * 100 / TOTAL_LINES))
  echo "Overall coverage: $COVERED_LINES/$TOTAL_LINES lines ($OVERALL_PERCENT%)"
  
  # Check threshold
  if [ "$OVERALL_PERCENT" -ge 90 ]; then
    echo "✅ Coverage exceeds 90% threshold"
  elif [ "$OVERALL_PERCENT" -ge 80 ]; then
    echo "⚠️ Coverage above minimum threshold (80%), but below target (90%)"
  else
    echo "❌ Coverage below 80% threshold"
  fi
else
  echo "No coverable lines found in the project"
fi