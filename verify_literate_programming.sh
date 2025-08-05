#!/usr/bin/env bash

# Grundle Literate Programming Verification
# Comprehensive check for compliance and traceability integrity

echo "🔍 LITERATE PROGRAMMING VERIFICATION"
echo "===================================="

echo ""
echo "📋 Step 1: Checking specification compliance..."
if ./check_compliance.sh; then
    echo "✅ Compliance check passed"
else
    echo "❌ Compliance check failed"
    exit 1
fi

echo ""
echo "🔗 Step 2: Checking traceability integrity..."
if ./verify_traceability.sh; then
    echo "✅ Traceability integrity check passed"
else
    echo "❌ Traceability integrity check failed"
    exit 1
fi

echo ""
echo "===================================="
echo "✅ LITERATE PROGRAMMING: PASSED"
echo "All functions documented and all links verified"
echo "Ready for code implementation and testing"
exit 0