# Grundle - Claude Development Guide

## 🚨 CRITICAL RULES

- **Documentation-first development**: All features must be documented before implementation
- **Specification traceability**: Every function connects to README.md requirements and test specs
- **Security-first mindset**: All vulnerabilities addressed - PRODUCTION READY status maintained
- **Test-driven workflow**: Tests based on documented behavior, then implementation follows
- **Single-step compilation**: All commands must pass before commit consideration

## 🎯 PROJECT CONTEXT

**Project**: Grundle - GTD markdown to CalDAV VTODO converter  
**Language**: Gleam  
**Environment**: Nix development environment  
**Architecture**: Literate programming with documentation-driven development  
**Status**: v0.4.1 - Production ready, all security vulnerabilities patched  

### Domain Model
```gleam
// GTD Markdown → Parser → Internal Model → VTODO Generator → CalDAV
// Bidirectional: CalDAV → VTODO Parser → Internal Model → Markdown Generator
```

## 🔧 STANDARD COMMANDS

```bash
# Type checking (always run first)
gleam check

# Code formatting (run before committing)  
gleam format

# Test suite
gleam test

# Build project
make build
gleam build

# Run with arguments
make run ARGS="todo.md --to-ics output/"
```

## 📋 LITERATE PROGRAMMING GUIDELINES

### Core Philosophy
**Programs as Literature**: Programs should be written primarily for human readers, not just computers. Code should tell a story that explains not just what is being done, but why and how the solution evolved.

### Gleam-Specific Patterns

**Specification Traceability** - Every function connects to design:
```gleam
/// Implements "Context Recognition" from README.md section 3.2
/// Handles GTD principle: contexts should be flexible user-defined strings  
/// @spec: test/markdown_parser_test_spec.md#context-extraction
/// @implements: README.md#section-3.2-context-recognition
pub fn extract_contexts(todo_text: String) -> List(Context)
```

**⚠️ MANDATORY FORMAT**: All public functions MUST include both:
- `@spec:` - Reference to test specification file and section
- `@implements:` - Reference to README.md section or design document

**Examples of CORRECT traceability comments:**
```gleam
/// Convert TodoItem to standards-compliant iCalendar VTODO format
/// Handles RFC 5545 text escaping and proper field mappings
/// @spec: test/vtodo_generator_test_spec.md#basic-vtodo-structure  
/// @implements: README.md#section-2.2-vtodo-generation
pub fn item_to_vtodo(item: TodoItem) -> String

/// Parse GTD-style todo.md file into TodoItem list
/// Handles section headers, contexts, dates, and sub-notes per GTD methodology
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-1.1-markdown-parsing
pub fn parse_file(path: String) -> Result(List(TodoItem), ParseError)
```

**❌ INSUFFICIENT** - Basic comments without traceability:
```gleam
// Parse markdown file - WRONG, missing @spec: and @implements:
pub fn parse_file(path: String) -> Result(List(TodoItem), ParseError)

/// Convert TodoItem to VTODO format - WRONG, missing references
pub fn item_to_vtodo(item: TodoItem) -> String
```

**Selective Commentary Principle**:
- ✅ **Comment design decisions**: Why this approach over alternatives
- ✅ **Comment complex logic**: Multi-step algorithms, edge case handling  
- ✅ **Comment domain concepts**: GTD principles, CalDAV requirements
- ❌ **Don't comment obvious code**: Simple assignments, basic operations
- ❌ **Don't comment what code does**: The code shows implementation
- ❌ **Don't comment routine operations**: Standard library usage

## 🧪 TEST-DRIVEN DEVELOPMENT

### Process Flow
1. Review specification in README.md and docs/
2. Write test cases based on documented behavior  
3. Check existing test spec files in test/ directory
4. Implement code to pass tests
5. Update documentation if behavior changes

### Key Test Specs
- `test/markdown_parser_test_spec.md` - Markdown parsing specifications
- `test/roundtrip_conversion_test_spec.md` - Roundtrip integrity specs
- `test/vtodo_generator_test_spec.md` - VTODO generation specs

## 🔒 SECURITY STATUS (v0.4.1)

**PRODUCTION READY** - All vulnerabilities comprehensively addressed:

**CRITICAL (Fixed):**
- ✅ Path traversal in backup system - comprehensive filename sanitization
- ✅ Unvalidated file paths - strict path validation with allowlist approach  
- ✅ Tilde expansion vulnerability - secure home directory expansion

**HIGH (Fixed):**
- ✅ Race conditions in sync - atomic file operations
- ✅ Date validation gaps - comprehensive validation (handles Feb 31st, etc.)
- ✅ Resource exhaustion - limits on note count (100) and length (1000 chars)

**MEDIUM (Fixed):**
- ✅ Silent error handling - configurable strict/permissive modes
- ✅ Directory traversal in ICS operations - filename sanitization for UIDs
- ✅ Information leakage - sanitized error messages and logging
- ✅ Sync failure with tilde paths - path expansion works correctly

**LOW (Fixed):**
- ✅ Environment variable validation - path safety checks with tilde expansion
- ✅ Hardcoded fallback dates - dynamic date generation
- ✅ Input length limits - comprehensive bounds checking

### Recent Security Fixes (v0.4.1)
- **Fixed sync failure**: Tilde expansion (`~/path`) works correctly in environment variables
- **Improved timestamp handling**: Removed 1-second buffer preventing edge-case syncs

## 🚀 PRE-COMMIT VERIFICATION SEQUENCE

**All steps must pass before commit consideration:**

### 1. Standard Checks
```bash
gleam format
gleam check  
gleam test
```

### 1.5. **SPECIFICATION TRACEABILITY VERIFICATION** ⚠️ CRITICAL
```bash
# Run comprehensive literate programming verification
./verify_literate_programming.sh

# This script runs two critical checks:
# 1. Compliance: All functions have @spec: and @implements: comments
# 2. Integrity: All links point to existing sections/files

# Individual scripts can also be run separately:
# ./check_compliance.sh        # Check documentation compliance
# ./verify_traceability.sh     # Check link integrity

# This step MUST pass before proceeding to other verification steps
echo "📋 Literate programming verification complete."
echo "If any failures shown above, fix documentation before proceeding."
```

### 2. Build Verification  
```bash
make build
make binary
make test-binary
./dist/grundle --help
```

### 3. Functional Testing
```bash
# Create test data
cat > /tmp/test_todo.md << 'EOF'
# GTD Todo List

## Inbox
- [ ] Review security audit report @computer
  Need to analyze findings and create action items.
- [ ] Schedule dentist appointment @calls Due 12/25

## Next Actions
- [ ] Update project documentation @computer
- [x] Fix critical security vulnerabilities @computer
  All path traversal issues resolved.

## Projects  
- [ ] Complete Q4 planning @computer Scheduled for 12/20
  - Review budget
  - Set goals for next quarter
EOF

# Test markdown to ICS conversion
mkdir -p /tmp/test_ics
gleam run -- /tmp/test_todo.md --to-ics /tmp/test_ics
ls /tmp/test_ics/  # Should show .ics files (5 files expected)

# Test ICS to markdown conversion
gleam run -- --from-ics /tmp/test_ics /tmp/test_output.md
head -10 /tmp/test_output.md  # Should show converted markdown

# Test environment variable validation (should show error)
gleam run --  # Should fail with env var error

# Cleanup
rm -rf /tmp/test_todo.md /tmp/test_ics/ /tmp/test_output.md
```

### 4. Security Validation
```bash
# Test path traversal protection (primary validation)
sh -c 'GRUNDLE_TODO="../../etc/passwd" GRUNDLE_VTODO="/tmp" gleam run 2>&1' | grep -q "Path contains directory traversal components" && echo "✅ Path validation working" || echo "❌ Path validation failed"

# Test restricted system directory protection  
sh -c 'GRUNDLE_TODO="/etc/passwd" GRUNDLE_VTODO="/tmp" gleam run 2>&1' | grep -q "Path points to restricted system directory" && echo "✅ System directory protection working" || echo "❌ System directory protection failed"

# Verify file parsing fails gracefully on invalid paths (secondary protection)
gleam run -- "../../etc/passwd" --to-ics /tmp/test 2>&1 | grep -q "✗ Failed to parse markdown file" && echo "✅ File parsing protection working" || echo "❌ File parsing protection failed"

# Test normal operation still works
echo "- [ ] Test task @computer" > /tmp/valid_test.md
gleam run -- /tmp/valid_test.md --to-ics /tmp/valid_test_ics && echo "✅ Normal operation working" || echo "❌ Normal operation failed"
rm -rf /tmp/valid_test.md /tmp/valid_test_ics
```

## 📁 PROJECT STRUCTURE

```
src/                    # Main Gleam source code
test/                   # Test files and specifications  
docs/                   # Additional documentation
README.md              # Complete literate program specification
Makefile               # Standard build targets
flake.nix              # Nix development environment
```

## 🔧 DEVELOPMENT WORKFLOW

### Literate Programming Process
1. **Document First**: Add feature specification to README.md
2. **Test Specification**: Create test cases in appropriate test/*_spec.md file  
3. **Implementation**: Write code with specification traceability comments
4. **Verification**: Run complete pre-commit sequence
5. **Integration**: Ensure cross-references between docs, tests, code remain valid

### Code Organization Principles
- **Psychological Order vs Logical Order**: Present ideas in human-comprehensible order
- **Web of Ideas**: Cross-reference between specification → test → implementation
- **Incremental Development**: Build complex solutions step-by-step with explanation
- **Multiple Perspectives**: Show code from architectural, implementation, and usage angles

### Working Example: Context Extraction Feature
```
User Story (README.md §3.2) → 
Test Spec (test/markdown_parser_test_spec.md#context-extraction) → 
Implementation (src/context.gleam with traceability comments) →
Verification (functional tests pass) →
Documentation Update (if behavior differs from spec)
``` 

## 🎯 PROMPT OPTIMIZATION

When working with Claude on this project:

- **Be Specific**: Reference exact spec sections, test files, and user stories
- **Provide Context**: Mention which phase of literate programming workflow you're in
- **Link Requirements**: Connect requests to specific README.md sections or test specs
- **Security First**: Always consider security implications of changes
- **Test Coverage**: Ensure new features have corresponding test specifications

## 🚨 COMPLIANCE VERIFICATION FOR REVIEWERS

**Before accepting any code review, run these verification commands:**

### Quick Compliance Check
```bash
# This should return matches - if empty, codebase is non-compliant
grep -r "@spec:" src/ && echo "✅ @spec: patterns found" || echo "❌ CRITICAL: No @spec: patterns found"
grep -r "@implements:" src/ && echo "✅ @implements: patterns found" || echo "❌ CRITICAL: No @implements: patterns found"

# Count public functions vs traceability comments
echo "Public functions vs traceability comments:"
echo "pub fn count: $(grep -r "^pub fn" src/ | wc -l)"
echo "@spec: count: $(grep -r "@spec:" src/ | wc -l)"  
echo "@implements: count: $(grep -r "@implements:" src/ | wc -l)"
echo "All counts should be equal for full compliance"
```

### Detailed Compliance Report
```bash
# Run full traceability verification from section 1.5 above
# This will show per-file compliance status
```

**❌ COMMON ASSESSMENT ERRORS TO AVOID:**
1. **Assuming comments = compliance** - Basic comments don't meet traceability requirements
2. **Pattern matching on partial compliance** - One compliant file doesn't mean all are compliant  
3. **Overweighting other factors** - Good security/tests don't substitute for documentation traceability
4. **Visual scanning bias** - Always use grep/search tools for verification
5. **Confirmation bias** - Verify systematically, don't assume patterns continue

## 📚 KNOWLEDGE BASE

### Domain Expertise Required
- **GTD Methodology**: Contexts, projects, next actions, inbox processing
- **CalDAV Standards**: VTODO format, RFC compliance, timezone handling
- **Gleam Language**: Pattern matching, result types, pipe operators
- **Security Patterns**: Path validation, input sanitization, error handling

### External References  
- README.md: Complete program specification and user stories
- Test specifications: Detailed behavioral requirements
- Gleam documentation: Language reference and stdlib
- CalDAV RFC: VTODO format requirements

---

**Remember**: This is literate programming. Every piece of code should tell part of the larger story documented in the specification. A reader should be able to trace from any function back to the user requirement it serves.
