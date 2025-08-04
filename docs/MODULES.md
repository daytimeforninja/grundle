# Module Documentation

## TodoItem: Core Data Structure

```gleam
/// Represents a single todo item that can be converted between formats.
/// 
/// This is the canonical representation that bridges markdown and VTODO formats.
/// All conversions flow through this type to ensure consistency.
pub type TodoItem {
  TodoItem(
    /// Unique identifier for the task, stable across conversions.
    /// Generated as SHA256 hash of section:summary, ensuring same content = same UID
    uid: String,
    
    /// Clean task description without context or date information.
    /// Context and dates are stored in separate fields for proper handling.
    summary: String,
    
    /// Task completion status. Maps to checkbox state in markdown and STATUS in VTODO.
    completed: Bool,
    
    /// GTD context like @home, @computer, @errands.
    /// Stored with @ prefix, maps to LOCATION field in VTODO (without @).
    context: Option(String),
    
    /// Additional notes and sub-items associated with the task.
    /// Each string represents one indented note line from markdown.
    notes: List(String),
    
    /// GTD section like "Next Actions", "Projects", "Waiting For".
    /// Maps to CATEGORIES field in VTODO. Defaults to "Inbox" if unspecified.
    section: String,
    
    /// Optional due date for the task. Parsed from "Due MM/DD" patterns.
    /// Stored as Date type, formatted as DUE;VALUE=DATE in VTODO.
    due_date: Option(Date),
    
    /// Optional start/scheduled date. Parsed from "Scheduled for MM/DD" patterns.
    /// Maps to DTSTART;VALUE=DATE in VTODO.
    start_date: Option(Date),
    
    /// Task creation timestamp. Set when first parsed from markdown.
    /// Maps to CREATED field in VTODO.
    created_at: DateTime,
    
    /// Last modification timestamp. Updated on each conversion.
    /// Maps to LAST-MODIFIED field in VTODO.
    modified_at: DateTime,
  )
}
```

### UID Generation Strategy

```gleam
/// Generate stable UID for a todo item based on its semantic content.
/// 
/// Uses SHA256 hash of "section:summary" to ensure:
/// - Same content always produces same UID
/// - Different content produces different UIDs  
/// - UIDs remain stable across format conversions
/// 
/// Format: {12-char-hex}@todo-md-sync
/// Example: "Next Actions:Build out mx2" → "a84cb35cde77@todo-md-sync"
pub fn generate_uid(summary: String, section: String) -> String
```

## MarkdownParser: todo.md → List(TodoItem)

```gleam
/// Parse GTD-style todo.md files into structured TodoItem list.
/// 
/// Handles the complete GTD markdown syntax including:
/// - Section headers (## Next Actions)
/// - Checkbox tasks (- [ ] Task description @context)  
/// - Sub-notes (  - Additional info)
/// - Date extraction (Due 7/25, Scheduled for 12/1)
/// - Context parsing (@home, @computer, etc.)
pub fn parse_file(path: String) -> Result(List(TodoItem), ParseError)

/// Parse markdown content string into TodoItem list.
/// Core parsing logic separated from file I/O for easier testing.
pub fn parse_content(content: String) -> List(TodoItem)
```

### Parsing State Machine

The parser maintains state as it processes lines:

```gleam
type ParseState {
  ParseState(
    current_section: Option(String),    // Current ## Section context
    current_item: Option(TodoItem),     // Item being built (for note accumulation)
    completed_items: List(TodoItem),    // Finished items
  )
}
```

### Line Processing Rules

1. **Section Headers**: `## Next Actions` → Update current_section
2. **Task Lines**: `- [ ] Task @context` → Create new TodoItem, set as current_item  
3. **Note Lines**: `  - Note text` → Append to current_item.notes
4. **Other Lines**: Ignore (comments, blank lines, etc.)

### Date Extraction Patterns

```gleam
/// Extract due dates from patterns like "Task description - Due 7/25"
/// Returns (clean_summary, due_date_option)
fn extract_due_date(summary: String) -> #(String, Option(Date))

/// Extract start dates from patterns like "Task - Scheduled for 12/1"  
/// Returns (clean_summary, start_date_option)
fn extract_start_date(summary: String) -> #(String, Option(Date))

/// Parse MM/DD date strings with intelligent year inference
/// If parsed date is in past and month < current month, assume next year
fn parse_date_string(date_str: String) -> Option(Date)
```

## VTodoGenerator: TodoItem → iCalendar String

```gleam
/// Convert TodoItem to standards-compliant iCalendar VTODO format.
/// 
/// Generates RFC 5545 compliant iCalendar with proper:
/// - Text escaping for special characters
/// - UTC timestamp formatting  
/// - Field mappings to VTODO properties
pub fn item_to_vtodo(item: TodoItem) -> String

/// Write TodoItem as .ics file to specified directory.
/// Filename format: {uid-prefix}.ics
pub fn write_ics_file(item: TodoItem, directory: String) -> Result(Nil, WriteError)
```

### Field Mapping Specification

| TodoItem Field | VTODO Property | Transformation |
|----------------|----------------|----------------|
| uid | UID | Direct mapping |
| summary | SUMMARY | Text escaped |  
| completed | STATUS | Bool → COMPLETED/NEEDS-ACTION |
| context | LOCATION | Remove @ prefix, escape text |
| section | CATEGORIES | Direct mapping, escaped |
| notes | DESCRIPTION | Join with \n, escape text |
| due_date | DUE;VALUE=DATE | Date → YYYYMMDD |
| start_date | DTSTART;VALUE=DATE | Date → YYYYMMDD |
| created_at | CREATED | DateTime → YYYYMMDDTHHMMSSZ |
| modified_at | LAST-MODIFIED | DateTime → YYYYMMDDTHHMMSSZ |

### Text Escaping Rules

iCalendar requires specific character escaping:

```gleam
/// Escape text for iCalendar format according to RFC 5545
/// - Backslash → \\\\
/// - Comma → \\,  
/// - Semicolon → \\;
/// - Newline → \\n
fn escape_text(text: String) -> String
```

## VTodoParser: iCalendar String → TodoItem

```gleam
/// Parse iCalendar VTODO content back into TodoItem.
/// Handles reverse conversion for CalDAV sync workflow.
pub fn parse_ics_file(path: String) -> Result(TodoItem, ParseError)

/// Parse iCalendar content string into TodoItem.
/// Core parsing separated from file I/O for testing.
pub fn parse_ics_content(content: String) -> Result(TodoItem, ParseError)

/// Parse entire directory of .ics files into TodoItem list.
/// Used for bulk conversion from CalDAV sync directory.
pub fn parse_ics_directory(directory: String) -> Result(List(TodoItem), ParseError)
```

### Property Extraction Strategy

1. **Split by Lines**: Parse iCalendar line by line
2. **Extract Properties**: Split on first `:` to get key:value pairs
3. **Handle Parameters**: Process property parameters like `DUE;VALUE=DATE:20240725`
4. **Reverse Mappings**: Apply inverse of VTodoGenerator field mappings
5. **Text Unescaping**: Reverse the text escaping process

### Date/DateTime Parsing

```gleam
/// Parse iCalendar DATE format (YYYYMMDD) to Gleam Date
fn parse_ics_date(date_str: String) -> Option(Date)

/// Parse iCalendar DATETIME format (YYYYMMDDTHHMMSSZ) to Gleam DateTime  
fn parse_ics_datetime(datetime_str: String) -> Option(DateTime)

/// Unescape iCalendar text format
/// Reverse of escape_text() function
fn unescape_text(text: String) -> String
```

## MarkdownWriter: List(TodoItem) → String

```gleam
/// Generate GTD-style todo.md content from TodoItem list.
/// 
/// Reconstructs original markdown format with:
/// - Canonical section ordering
/// - Proper checkbox syntax
/// - Context restoration  
/// - Date formatting
/// - Sub-note indentation
pub fn write_items_to_file(items: List(TodoItem), path: String) -> Result(Nil, WriteError)

/// Generate markdown content string from TodoItem list.
/// Core generation logic separated from file I/O.
pub fn generate_content(items: List(TodoItem)) -> String
```

### Section Organization

```gleam
/// Canonical GTD section order for consistent output
const section_order = [
  "Inbox",
  "Next Actions", 
  "Projects",
  "Waiting For",
  "Someday/Maybe",
  "Completed"
]
```

### Item Formatting Rules

```gleam
/// Format single TodoItem as markdown line(s)
/// - Checkbox: [x] for completed, [ ] for pending
/// - Summary: Clean task description
/// - Context: Appended with space (@home, @computer)
/// - Dates: Appended as "- Due MM/DD" or "- Scheduled for MM/DD"
/// - Notes: Indented with "  - " prefix
fn format_item(item: TodoItem) -> String
```

## CLI: Command-Line Interface

```gleam
/// Main CLI entry point with command parsing and execution
pub fn main() -> Nil

/// Parse command-line arguments into Command type
fn parse_args(args: List(String)) -> Result(Command, ArgError)

/// Execute parsed command with proper error handling
fn run_command(command: Command) -> Result(Nil, CliError)
```

### Command Types

```gleam
pub type Command {
  /// Convert todo.md to ICS files: todo.md --to-ics output_dir/
  ToIcs(input_file: String, output_dir: String)
  
  /// Convert ICS files to todo.md: --from-ics input_dir/ output.md  
  FromIcs(input_dir: String, output_file: String)
  
  /// Show help information
  Help
}
```

### Error Types

```gleam
pub type CliError {
  FileNotFound(String)
  ParseError(String)
  WriteError(String)
  InvalidArgs(String)
}
```

## Error Handling Philosophy

All modules use Gleam's `Result(a, b)` type for explicit error handling:

```gleam
/// Conversion-specific error types
pub type ConversionError {
  FileNotFound(path: String)
  ParseError(message: String, line: Int)
  InvalidDate(date_string: String)
  WriteError(path: String, reason: String)
  InvalidFormat(expected: String, got: String)
}

/// Result type alias for cleaner signatures
pub type ConversionResult(a) = Result(a, ConversionError)
```

### Error Recovery Strategy

- **File Operations**: Fail fast with descriptive path information
- **Parsing Errors**: Continue processing, collect errors for batch reporting
- **Date Parsing**: Default to None, log warning for invalid dates
- **Text Processing**: Handle gracefully, preserve as much content as possible
- **Write Operations**: Atomic success/failure (don't create partial files)