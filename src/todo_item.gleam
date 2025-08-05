// Todo Item: Core Data Structure
// ===============================
//
// This module defines the TodoItem type, which serves as the canonical 
// representation of a task that bridges both markdown and VTODO formats.
// All conversions flow through this type to ensure consistency.

import birl.{type Time}
import gleam/bit_array
import gleam/crypto
import gleam/option.{type Option}
import gleam/string

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
    /// Stored as Time type, formatted as DUE;VALUE=DATE in VTODO.
    due_date: Option(Time),
    /// Optional start/scheduled date. Parsed from "Scheduled for MM/DD" patterns.
    /// Maps to DTSTART;VALUE=DATE in VTODO.
    start_date: Option(Time),
    /// Task creation timestamp. Set when first parsed from markdown.
    /// Maps to CREATED field in VTODO.
    created_at: Time,
    /// Last modification timestamp. Updated on each conversion.
    /// Maps to LAST-MODIFIED field in VTODO.
    modified_at: Time,
  )
}

/// Error types for TodoItem operations
pub type TodoItemError {
  InvalidSummary(String)
  InvalidSection(String)
  UidGenerationError(String)
}

/// Generate stable UID for a todo item based on its semantic content
/// Uses SHA256 hash of "section:summary" to ensure UID stability across conversions
/// @spec: test/markdown_parser_test_spec.md#uid-generation-tests
/// @implements: README.md#section-4.1-uid-generation
pub fn generate_uid(summary: String, section: String) -> String {
  let content = section <> ":" <> summary
  let hash = crypto.hash(crypto.Sha256, <<content:utf8>>)
  let hex =
    hash
    |> bit_array.base16_encode()
    |> string.lowercase()
    |> string.slice(0, 12)

  hex <> "@todo-md-sync"
}

/// Create a new TodoItem with generated UID and current timestamps
/// Factory function that ensures proper initialization of all required fields
/// @spec: test/markdown_parser_test_spec.md#todoitem-creation
/// @implements: README.md#section-4.2-todoitem-construction
pub fn new(
  summary: String,
  section: String,
  completed: Bool,
  context: Option(String),
  notes: List(String),
  due_date: Option(Time),
  start_date: Option(Time),
) -> TodoItem {
  let now = birl.utc_now()
  let uid = generate_uid(summary, section)

  TodoItem(
    uid: uid,
    summary: summary,
    completed: completed,
    context: context,
    notes: notes,
    section: section,
    due_date: due_date,
    start_date: start_date,
    created_at: now,
    modified_at: now,
  )
}

/// Update the modification timestamp of a TodoItem
/// Used to track changes during conversion processes
/// @spec: test/roundtrip_conversion_test_spec.md#timestamp-management
/// @implements: README.md#section-4.3-timestamp-updates
pub fn touch(item: TodoItem) -> TodoItem {
  TodoItem(..item, modified_at: birl.utc_now())
}

/// Validate that a TodoItem has required fields properly set
/// Ensures data integrity before format conversions
/// @spec: test/vtodo_generator_test_spec.md#empty-nil-fields-handling
/// @implements: README.md#section-4.4-data-validation
pub fn validate(item: TodoItem) -> Result(TodoItem, TodoItemError) {
  case string.trim(item.summary) {
    "" -> Error(InvalidSummary("Summary cannot be empty"))
    _ ->
      case string.trim(item.section) {
        "" -> Error(InvalidSection("Section cannot be empty"))
        _ -> Ok(item)
      }
  }
}

/// Check if two TodoItems are semantically equivalent
/// Implements semantic equivalence definition for roundtrip validation
/// @spec: test/roundtrip_conversion_test_spec.md#semantic-equivalence-definition
/// @implements: README.md#section-4.5-equivalence-checking
pub fn equivalent(item1: TodoItem, item2: TodoItem) -> Bool {
  item1.summary == item2.summary
  && item1.completed == item2.completed
  && item1.context == item2.context
  && item1.notes == item2.notes
  && item1.section == item2.section
  && item1.due_date == item2.due_date
  && item1.start_date == item2.start_date
}
