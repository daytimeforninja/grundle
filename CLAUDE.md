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

### Known Issues
All previously identified critical and important issues have been resolved:
- ✅ Hard-coded year issue - now uses dynamic year detection
- ✅ Directory creation - properly implemented with `simplifile.create_directory_all()`
- ✅ Date validation - correctly validates days per month including leap years
- ✅ Path traversal protection - explicit checks for `..` in filenames
- ✅ Error handling - follows proper Gleam patterns

### Project Structure
- `src/` - Main Gleam source code
- `test/` - Test files and specifications
- `docs/` - Additional documentation
- `README.md` - Complete literate program specification
- Uses Nix for development environment
- Makefile provides standard build targets

### Before Committing
Always run:
```bash
gleam format
gleam check  
gleam test
```

All three must pass before code can be considered ready for commit.