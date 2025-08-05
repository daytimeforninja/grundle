#!/usr/bin/env bash

# Grundle Traceability Integrity Checker
# Verifies that all @spec: and @implements: links point to real, existing content

echo "🔗 TRACEABILITY INTEGRITY VERIFICATION"
echo "====================================="

all_links_valid=true

echo ""
echo "🔍 CHECKING @spec: LINKS..."
echo "----------------------------"

# Extract all @spec: links and verify they exist
while IFS= read -r line; do
    # Extract file and link
    file=$(echo "$line" | cut -d: -f1)
    spec_link=$(echo "$line" | grep -o "@spec: .*" | sed 's/@spec: //')
    
    echo "Checking: $spec_link (from $file)"
    
    # Parse the link (format: path#section)
    if [[ "$spec_link" == *"#"* ]]; then
        spec_file=$(echo "$spec_link" | cut -d'#' -f1)
        spec_section=$(echo "$spec_link" | cut -d'#' -f2)
        
        # Check if file exists
        if [ ! -f "$spec_file" ]; then
            echo "  ❌ BROKEN: File '$spec_file' does not exist"
            all_links_valid=false
            continue
        fi
        
        # Check if section exists in file
        if [ "${spec_file##*.}" = "md" ]; then
            # For .md files, look for section headers or anchor IDs
            # Check both regular section headers and {#anchor-id} patterns
            if grep -q "{#$spec_section}" "$spec_file" 2>/dev/null; then
                echo "  ✅ VALID: Found anchor {#$spec_section} in $spec_file"
            elif grep -qi "#{1,4}.*$(echo "$spec_section" | sed 's/-/ /g')" "$spec_file" 2>/dev/null; then
                echo "  ✅ VALID: Found section header matching '$spec_section' in $spec_file"
            else
                echo "  ❌ BROKEN: Section '$spec_section' not found in '$spec_file'"
                echo "    Available sections:"
                grep "^#\|{#" "$spec_file" | head -10 | sed 's/^/      /'
                all_links_valid=false
            fi
        elif [ "${spec_file##*.}" = "gleam" ]; then
            # For .gleam files, look for comments or function names
            if ! grep -q "$spec_section" "$spec_file" 2>/dev/null; then
                echo "  ❌ BROKEN: Section '$spec_section' not found in '$spec_file'"
                all_links_valid=false
            else
                echo "  ✅ VALID: Found reference in $spec_file"
            fi
        fi
    else
        echo "  ❌ BROKEN: Invalid link format (missing #section): $spec_link"
        all_links_valid=false
    fi
    echo ""
done < <(grep -r "@spec:" src/ 2>/dev/null)

echo ""
echo "🔍 CHECKING @implements: LINKS..."
echo "--------------------------------"

# Extract all @implements: links and verify they exist
while IFS= read -r line; do
    # Extract file and link
    file=$(echo "$line" | cut -d: -f1)
    impl_link=$(echo "$line" | grep -o "@implements: .*" | sed 's/@implements: //')
    
    echo "Checking: $impl_link (from $file)"
    
    # Parse the link (format: path#section)
    if [[ "$impl_link" == *"#"* ]]; then
        impl_file=$(echo "$impl_link" | cut -d'#' -f1)
        impl_section=$(echo "$impl_link" | cut -d'#' -f2)
        
        # Check if file exists
        if [ ! -f "$impl_file" ]; then
            echo "  ❌ BROKEN: File '$impl_file' does not exist"
            all_links_valid=false
            continue
        fi
        
        # For README.md, look for section headers with anchors
        if [ "$impl_file" = "README.md" ]; then
            # Check for {#anchor-id} patterns in README.md
            if grep -q "{#$impl_section}" "$impl_file" 2>/dev/null; then
                echo "  ✅ VALID: Found anchor {#$impl_section} in README.md"
            else
                echo "  ❌ BROKEN: Section '$impl_section' not found in README.md"
                echo "    Available anchors:"
                grep "{#" README.md | head -10 | sed 's/^/      /'
                all_links_valid=false
            fi
        fi
    else
        echo "  ❌ BROKEN: Invalid link format (missing #section): $impl_link"
        all_links_valid=false
    fi
    echo ""
done < <(grep -r "@implements:" src/ 2>/dev/null)

echo "====================================="
if [ "$all_links_valid" = true ]; then
    echo "✅ TRACEABILITY INTEGRITY: PASSED"
    echo "All links point to existing content"
    exit 0
else
    echo "❌ TRACEABILITY INTEGRITY: FAILED"
    echo "Some links are broken and need to be fixed"
    exit 1
fi