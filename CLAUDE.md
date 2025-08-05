# Claude Development Notes for Grundle

## Project Overview
Grundle is a literate programming project that converts GTD-style markdown todos to CalDAV-compatible VTODO format. This is a Gleam project with comprehensive documentation-driven development.

## Development Workflow

### Literate Programming Approach
This project follows a literate programming style where:
1. **Documentation comes first** - The README.md contains the complete specification
2. **Tests are derived from specs** - Test cases are written based on documented behavior
3. **Implementation follows tests** - Code is written to pass the specification-based tests
4. **Specs drive development** - All features must be documented before implementation

### Standard Commands
Run these commands when completing tasks:

```bash
# Type checking (always run first)
gleam check

# Code formatting (run before committing)
gleam format

# Run test suite
gleam test

# Build project
make build
# or
gleam build

# Run with arguments
make run ARGS="todo.md --to-ics output/"
```

### Test-Driven Development
When adding features:
1. Review the specification in README.md and docs/
2. Write test cases based on documented behavior
3. Check existing test spec files in test/ directory
4. Implement code to pass the tests
5. Update documentation if behavior changes

### Key Test Spec Files
- `test/markdown_parser_test_spec.md` - Markdown parsing specifications
- `test/roundtrip_conversion_test_spec.md` - Roundtrip integrity specs  
- `test/vtodo_generator_test_spec.md` - VTODO generation specs

### Security Status (v0.4.1)
All security vulnerabilities have been comprehensively addressed:

**CRITICAL (Fixed):**
- ✅ Path traversal in backup system - comprehensive filename sanitization
- ✅ Unvalidated file paths - added strict path validation with allowlist approach
- ✅ Tilde expansion vulnerability - added secure home directory expansion

**HIGH (Fixed):**
- ✅ Race conditions in sync - atomic file operations (timestamp buffer removed)
- ✅ Date validation gaps - comprehensive validation in all parsers (Feb 31st, etc.)
- ✅ Resource exhaustion - limits on note count (100) and length (1000 chars)

**MEDIUM (Fixed):**
- ✅ Silent error handling - configurable strict/permissive modes
- ✅ Directory traversal in ICS operations - filename sanitization for UIDs
- ✅ Information leakage - sanitized error messages and logging
- ✅ Sync failure with tilde paths - path expansion now works correctly

**LOW (Fixed):**
- ✅ Environment variable validation - path safety checks with tilde expansion
- ✅ Hardcoded fallback dates - dynamic date generation
- ✅ Input length limits - comprehensive bounds checking

**Security Level: PRODUCTION READY** - All vulnerabilities patched with defense-in-depth approach.

### Recent Bug Fixes (v0.4.1)
- **Fixed sync failure**: Tilde expansion (`~/path`) now works correctly in environment variables
- **Improved timestamp handling**: Removed 1-second buffer that could prevent edge-case syncs

### Project Structure
- `src/` - Main Gleam source code
- `test/` - Test files and specifications
- `docs/` - Additional documentation
- `README.md` - Complete literate program specification
- Uses Nix for development environment
- Makefile provides standard build targets

### Before Committing
Always run the complete build verification sequence:

#### 1. Standard Checks
```bash
gleam format
gleam check  
gleam test
```

#### 2. Build Verification  
```bash
make build
make binary
make test-binary
./dist/grundle --help
```

#### 3. Functional Testing
```bash
# Create test data
cat > /tmp/test_todo.md << 'EOF'
# GTD Todo List

## Inbox
- [ ] Review security audit report @computer
  Need to analyze the findings and create action items.
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

# Test with binary (alternative method)
./dist/grundle /tmp/test_todo.md --to-ics /tmp/test_ics  # Should show help (binary has different behavior)

# Cleanup
rm -rf /tmp/test_todo.md /tmp/test_ics/ /tmp/test_output.md
```

#### 4. Security Validation
```bash
# Test path traversal protection via environment variables (most reliable test)
echo "Testing security fixes..."
GRUNDLE_TODO="../../etc/passwd" GRUNDLE_VTODO="/tmp" gleam run -- 2>&1 | grep -q "Path contains directory traversal components" && echo "✅ Path validation working" || echo "❌ Path validation failed"

# Test restricted system directory protection
GRUNDLE_TODO="/etc/passwd" GRUNDLE_VTODO="/tmp" gleam run -- 2>&1 | grep -q "Path points to restricted system directory" && echo "✅ System directory protection working" || echo "❌ System directory protection failed"

# Verify file parsing fails gracefully on invalid paths (secondary protection)
gleam run -- "../../etc/passwd" --to-ics /tmp/test 2>&1 | grep -q "Failed to parse markdown file" && echo "✅ File parsing protection working" || echo "❌ File parsing protection failed"

# Test normal operation still works
echo "- [ ] Test task @computer" > /tmp/valid_test.md
gleam run -- /tmp/valid_test.md --to-ics /tmp/valid_test_ics && echo "✅ Normal operation working" || echo "❌ Normal operation failed"
rm -rf /tmp/valid_test.md /tmp/valid_test_ics
```

**All steps must pass before code can be considered ready for commit.** This ensures compilation correctness, runtime functionality, and security protections are working properly.