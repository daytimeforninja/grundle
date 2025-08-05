# Todo.md ↔ VTODO Converter: A Literate Program in Gleam

*Converting GTD-style markdown todos to CalDAV-compatible VTODO format*

## Philosophy and Purpose

This program solves a simple but important problem: bridging the gap between plain-text GTD (Getting Things Done) todo management and CalDAV synchronization across devices. 

**Core Principle**: Keep it simple. Convert between formats, let specialized tools handle their domains:
- Your text editor handles `todo.md` 
- `vdirsyncer` handles CalDAV synchronization
- This converter handles the format translation

## The Problem Domain

### Input: GTD-Style Markdown
```markdown
# GTD Todo List

## Next Actions
- [ ] Review project documentation @computer
- [ ] Call dentist for appointment @phone
- [ ] Buy groceries @errands

## Waiting For  
- [ ] Response from client about proposal @waiting
  - Sent proposal on Monday

## Someday/Maybe
- [ ] Learn Spanish @personal
```

### Output: iCalendar VTODO Format
```ics
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:a84cb35cde77@todo-md-sync
SUMMARY:Review project documentation
STATUS:NEEDS-ACTION
CATEGORIES:Next Actions
LOCATION:computer
END:VTODO
END:VCALENDAR
```

## Data Architecture

### Core Data Structure: TodoItem

The `TodoItem` type represents the canonical form of a task, bridging both markdown and VTODO representations:

```gleam
pub type TodoItem {
  TodoItem(
    uid: String,              // Stable identifier across conversions
    summary: String,          // Task title/description  
    completed: Bool,          // Completion status
    context: Option(String),  // GTD context (@home, @computer, etc)
    notes: List(String),      // Sub-notes and additional details
    section: String,          // GTD section (Inbox, Next Actions, etc)
    due_date: Option(Date),   // Optional due date
    start_date: Option(Date), // Optional start/scheduled date
    created_at: DateTime,     // Creation timestamp
    modified_at: DateTime,    // Last modification timestamp
  )
}
```

### Key Design Decisions

1. **Stable UIDs**: Generated from content hash to ensure the same task gets the same UID across conversions
2. **Contexts as LOCATION**: GTD contexts (@home, @computer) map to iCalendar LOCATION field
3. **Sections as CATEGORIES**: GTD sections (Next Actions, Projects) map to CATEGORIES field
4. **Notes as DESCRIPTION**: Sub-notes become multi-line DESCRIPTION content
5. **Date Intelligence**: MM/DD dates are parsed with smart year inference

## Module Architecture

### 1. MarkdownParser
**Purpose**: Parse GTD-style todo.md files into TodoItem structs

**Input Processing**:
- Section headers: `## Next Actions` → `section: "Next Actions"`
- Task lines: `- [ ] Task @context` → completed, summary, context extraction
- Sub-notes: `  - Additional info` → notes accumulation
- Date patterns: `Due 7/25` → due_date extraction

**Edge Cases Handled**:
- Nested sections and subsections
- Tasks without contexts
- Multi-line notes with varying indentation
- Date parsing across year boundaries
- Malformed checkbox syntax

### 2. VTodoGenerator  
**Purpose**: Convert TodoItem structs to standards-compliant iCalendar VTODO

**Output Standards**:
- RFC 5545 compliant iCalendar format
- Proper text escaping for commas, semicolons, newlines
- UTC timestamps in iCalendar format
- Unique filenames based on UID hash

**Field Mappings**:
```
TodoItem.summary      → SUMMARY (cleaned of context)
TodoItem.completed    → STATUS (COMPLETED | NEEDS-ACTION)  
TodoItem.context      → LOCATION (without @ prefix)
TodoItem.section      → CATEGORIES
TodoItem.notes        → DESCRIPTION (newline-joined)
TodoItem.due_date     → DUE;VALUE=DATE
TodoItem.start_date   → DTSTART;VALUE=DATE
```

### 3. VTodoParser
**Purpose**: Parse iCalendar VTODO files back into TodoItem structs

**Parsing Strategy**:
- Property extraction from iCalendar format
- Reverse field mappings from VTodoGenerator
- Date/datetime parsing with format detection
- Text unescaping for special characters

### 4. MarkdownWriter
**Purpose**: Generate GTD-style todo.md from TodoItem structs

**Output Format**:
- Consistent section ordering (Inbox, Next Actions, Projects, Waiting For, Someday/Maybe)
- Proper checkbox syntax: `- [x]` for completed, `- [ ]` for pending
- Context restoration: append @context to summary
- Date formatting: convert back to MM/DD format
- Sub-note indentation: two-space indent with dash prefix

### 5. CLI Interface
**Purpose**: Command-line interface for conversion operations

**Commands**:
```bash
# Convert todo.md to ICS files
grundle todo.md --to-ics output_dir/

# Convert ICS files back to todo.md  
grundle --from-ics input_dir/ output.md
```

## Data Flow and Transformations

### Forward Conversion (Markdown → VTODO)
```
todo.md
  ↓ MarkdownParser.parse_file()
List(TodoItem) 
  ↓ List.map(VTodoGenerator.to_vtodo)
List(String) [iCalendar content]
  ↓ VTodoGenerator.write_ics_files()
Multiple .ics files
```

### Reverse Conversion (VTODO → Markdown)
```
Directory of .ics files
  ↓ VTodoParser.parse_directory()
List(TodoItem)
  ↓ MarkdownWriter.generate_content()
String [markdown content]
  ↓ File.write()
todo.md
```

### Roundtrip Integrity
A properly functioning converter should satisfy:
```
original_todo.md 
  → to_ics → from_ics → 
reconstructed_todo.md

Where: semantic_equivalence(original, reconstructed) = True
```

## Expected Behavior Specifications

### UID Generation
- **Requirement**: Same task content must generate identical UID across conversions
- **Implementation**: SHA256 hash of `"#{section}:#{summary}"` 
- **Format**: `{12-char-hex}@todo-md-sync`
- **Example**: `"Next Actions:Review project documentation"` → `"a84cb35cde77@todo-md-sync"`

### Date Parsing Intelligence
- **MM/DD Format**: `"7/25"` → Date with smart year inference
- **Year Boundary Logic**: If parsed date is in past and month < current month, assume next year
- **Edge Cases**: Invalid dates (2/30) return None, malformed strings return None

### Context Extraction
- **Pattern**: `@word` at end of summary
- **Storage**: Context stored separately from summary
- **VTODO Mapping**: Context becomes LOCATION field (without @ prefix)
- **Reconstruction**: Context appended back to summary in markdown

### Section Organization
- **Canonical Order**: Inbox, Next Actions, Projects, Waiting For, Someday/Maybe, Completed
- **Preservation**: Section assignments maintained through CATEGORIES field
- **Default**: Items without explicit section assigned to "Inbox"

## Test Scenarios and Edge Cases

### Markdown Parsing Tests
1. **Basic Task Parsing**
   - `- [ ] Simple task` → TodoItem with completed=false
   - `- [x] Done task` → TodoItem with completed=true

2. **Context Extraction**
   - `- [ ] Task @home` → context=Some("@home"), summary="Task"
   - `- [ ] Task` → context=None, summary="Task"

3. **Date Parsing**
   - `- [ ] Task due 7/25` → due_date=Some(Date(2024, 7, 25))
   - `- [ ] Task scheduled for 12/1` → start_date=Some(Date(2024, 12, 1))

4. **Sub-notes**
   ```markdown
   - [ ] Main task
     - Note one
     - Note two
   ```
   → notes=["Note one", "Note two"]

5. **Section Headers**
   - `## Next Actions` followed by tasks → section="Next Actions"
   - Tasks before any header → section="Inbox"

### VTODO Generation Tests
1. **Basic VTODO Structure**
   - Valid iCalendar format with required fields
   - Proper BEGIN/END wrapping
   - UTC timestamp formatting

2. **Text Escaping**
   - Summary with comma: `"Task, urgent"` → `"Task\, urgent"`
   - Summary with semicolon: `"Task; notes"` → `"Task\; notes"`
   - Notes with newlines preserved as `\n`

3. **Date Formatting**
   - Due date: Date(2024, 7, 25) → `"DUE;VALUE=DATE:20240725"`
   - Start date: Date(2024, 12, 1) → `"DTSTART;VALUE=DATE:20241201"`

### Roundtrip Conversion Tests
1. **Semantic Preservation**
   - Task completion status maintained
   - Contexts preserved exactly
   - Due/start dates maintained
   - Sub-notes preserved in order

2. **Section Organization**
   - All sections maintained
   - Section order normalized to canonical order
   - Items remain in correct sections

3. **UID Stability**
   - Same content generates same UID
   - UIDs remain stable across multiple conversions

## Integration with vdirsyncer

### Typical Workflow
```bash
# 1. Convert local todo.md to ICS files
grundle todo.md --to-ics ~/.calendars/tasks/

# 2. Sync with CalDAV server  
vdirsyncer sync

# 3. Convert updated ICS files back to todo.md
grundle --from-ics ~/.calendars/tasks/ todo.md
```

### File Organization
- **Local Collection**: `~/.calendars/tasks/` (or configured vdirsyncer path)
- **File Naming**: `{uid-prefix}.ics` (e.g., `a84cb35cde77.ics`)
- **Atomic Operations**: Each task = one .ics file for proper CalDAV sync

## Data Protection and Safety

**Automatic Backups**: Before overwriting any `todo.md` file, grundle automatically creates timestamped backups in `~/.cache/grundle/`:

```bash
~/.cache/grundle/
├── home_Documents_todo.md.backup.2024-08-04T15-30-45Z
├── home_Documents_todo.md.backup.2024-08-04T14-25-12Z
└── ... (up to 5 most recent backups)
```

**Duplicate Prevention**: When converting to ICS format, grundle cleans the output directory of existing `.ics` files to prevent duplicate entries during sync.

**Recovery**: If your `todo.md` gets corrupted or overwritten, restore from the most recent backup:
```bash
cp ~/.cache/grundle/home_Documents_todo.md.backup.2024-08-04T15-30-45Z ~/Documents/todo.md
```

## Error Handling Philosophy

Gleam's `Result(a, b)` type enables explicit error handling:

```gleam
pub type ConversionError {
  FileNotFound(String)
  ParseError(String)  
  InvalidDate(String)
  WriteError(String)
}

pub type Result(a) = Result(a, ConversionError)
```

**Error Recovery Strategy**:
- **Parsing Errors**: Skip malformed items, continue processing
- **File Errors**: Fail fast with descriptive messages
- **Date Errors**: Default to None, log warning
- **Write Errors**: Atomic failure (all or nothing)
- **Backup Failures**: Prevent todo.md modification to avoid data loss

## Implementation Sections

### Section 1: CLI Interface Components

#### Section 1.0: CLI Interface {#section-1.0-cli-interface}
Main entry point handling command-line arguments, environment variables, and usage display. Orchestrates all conversion operations.

#### Section 1.1: Help System {#section-1.1-help-system}  
Comprehensive usage information display including commands, examples, environment variables, and vdirsyncer workflow integration.

#### Section 1.1: Markdown Parsing {#section-1.1-markdown-parsing}
Core markdown file parsing with GTD-style task extraction, section header processing, and TodoItem construction.

#### Section 1.2: Markdown Generation {#section-1.2-markdown-generation}
Reconstruction of GTD-style markdown from TodoItem structures with canonical section ordering and proper formatting.

### Section 2: Content Processing

#### Section 2.1: Content Parsing {#section-2.1-content-parsing}
String-based markdown content processing including line-by-line parsing state management and TodoItem accumulation.

#### Section 2.2: VTODO Generation {#section-2.2-vtodo-generation}
Standards-compliant iCalendar VTODO format generation with RFC 5545 compliance and proper text escaping.

#### Section 2.3: Content Generation {#section-2.3-content-generation}
Markdown content string generation from TodoItem lists with section grouping and formatting.

#### Section 2.4: VTODO Parsing {#section-2.4-vtodo-parsing}
iCalendar VTODO file parsing back into TodoItem structures with property extraction and field mapping.

#### Section 2.5: ICS Content Parsing {#section-2.5-ics-content-parsing}
Raw iCalendar content string processing with line ending normalization and property parsing.

### Section 3: File Operations

#### Section 3.1: ICS File Generation {#section-3.1-ics-file-generation}
Individual TodoItem to .ics file conversion with filename generation and directory management.

#### Section 3.1: Markdown to ICS Conversion {#section-3.1-markdown-to-ics-conversion}
Complete workflow from markdown file to directory of ICS files with error handling and progress reporting.

#### Section 3.2: Batch ICS Generation {#section-3.2-batch-ics-generation}
Multiple TodoItem batch processing to ICS files with directory cleanup and atomic operations.

#### Section 3.2: ICS to Markdown Conversion {#section-3.2-ics-to-markdown-conversion}
Complete workflow from ICS directory to markdown file with TodoItem consolidation and file writing.

#### Section 3.3: Directory Parsing {#section-3.3-directory-parsing}
ICS directory scanning and batch TodoItem extraction with error recovery and validation.

#### Section 3.4: Strict Directory Parsing {#section-3.4-strict-directory-parsing}
Rigorous ICS directory parsing with fail-fast error handling for validation pipelines.

### Section 4: Data Management

#### Section 4.1: Bidirectional Sync {#section-4.1-bidirectional-sync}
Timestamp-based sync direction determination with newest-wins strategy for CalDAV workflow.

#### Section 4.1: UID Generation {#section-4.1-uid-generation}
Stable unique identifier generation using content hashing for cross-conversion consistency.

#### Section 4.2: Timestamp Comparison {#section-4.2-timestamp-comparison}
File modification time comparison for sync direction determination with atomic operations.

#### Section 4.2: TodoItem Construction {#section-4.2-todoitem-construction}
Factory function for TodoItem creation with proper field initialization and timestamp management.

#### Section 4.3: ICS Timestamp Detection {#section-4.3-ics-timestamp-detection}
ICS directory scanning for newest modification time determination in sync operations.

#### Section 4.3: Timestamp Updates {#section-4.3-timestamp-updates}
TodoItem modification timestamp updates for change tracking during conversions.

#### Section 4.4: Data Validation {#section-4.4-data-validation}
TodoItem field validation ensuring data integrity before format conversions with error reporting.

#### Section 4.5: Equivalence Checking {#section-4.5-equivalence-checking}
Semantic equivalence testing for TodoItem comparison in roundtrip validation scenarios.

### Section 5: Security

#### Section 5.1: Environment Security {#section-5.1-environment-security}
Environment variable path validation preventing directory traversal and system directory access.

#### Section 5.2: Path Security Validation {#section-5.2-path-security-validation}
Individual path security checking with tilde expansion and traversal attack prevention.

---

*This document serves as both specification and test plan. Implementation should follow these documented behaviors exactly.*
## Installation

### Using Nix Flakes (Recommended)
```bash
# Install directly from repository
nix profile install github:your-username/grundle

# Or run without installing
nix run github:your-username/grundle -- --help
```

### Using Legacy Nix
```bash
nix-env -i -f https://github.com/your-username/grundle/archive/main.tar.gz
```

### Building with Make
```bash
git clone https://github.com/your-username/grundle.git
cd grundle
make build
```

### Development
```bash
# Enter development shell
nix develop

# Or using legacy Nix
nix-shell
```

### Building from Source
```bash
git clone https://github.com/your-username/grundle.git
cd grundle
nix build
./result/bin/grundle --help
```
