#!/usr/bin/env bash

# Grundle Specification Traceability Compliance Checker
# This script verifies that all public functions have required @spec: and @implements: comments

echo "🔍 SPECIFICATION TRACEABILITY VERIFICATION"
echo "=========================================="

# Check for pattern existence
echo "🔍 Checking for @spec: patterns..."
spec_total=$(grep -r "@spec:" src/ | wc -l)
echo "Found $spec_total @spec: comments"

echo "🔍 Checking for @implements: patterns..."  
implements_total=$(grep -r "@implements:" src/ | wc -l)
echo "Found $implements_total @implements: comments"

# Per-file compliance check
echo ""
echo "🔍 Checking specification traceability compliance..."
overall_compliant=true

for file in src/*.gleam; do
  if [ -f "$file" ]; then
    echo "Checking $file..."
    pub_functions=$(grep -c "^pub fn" "$file" 2>/dev/null)
    priv_functions=$(grep -c "^fn " "$file" 2>/dev/null)
    total_functions=$((pub_functions + priv_functions))
    spec_comments=$(grep -c "@spec:" "$file" 2>/dev/null || echo "0")
    implements_comments=$(grep -c "@implements:" "$file" 2>/dev/null || echo "0")
    
    echo "  Public functions: $pub_functions"
    echo "  Private functions: $priv_functions"
    echo "  Total functions: $total_functions"
    echo "  @spec: comments: $spec_comments" 
    echo "  @implements: comments: $implements_comments"
    
    if [ "$spec_comments" -lt "$total_functions" ] || [ "$implements_comments" -lt "$total_functions" ]; then
      echo "  ❌ COMPLIANCE FAILURE: Missing traceability comments (need $total_functions each)"
      overall_compliant=false
    else
      echo "  ✅ COMPLIANCE OK"
    fi
    echo ""
  fi
done

# Summary
echo "=========================================="
if [ "$overall_compliant" = true ]; then
  echo "✅ OVERALL COMPLIANCE: PASSED"
  echo "All public functions have required @spec: and @implements: comments"
  exit 0
else
  echo "❌ OVERALL COMPLIANCE: FAILED"
  echo "Some public functions are missing required traceability comments"
  exit 1
fi