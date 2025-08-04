// VTodoGenerator: TodoItem → iCalendar VTODO
// ============================================
//
// Convert TodoItem structs to standards-compliant iCalendar VTODO format.
// Handles RFC 5545 compliance, text escaping, and proper field mappings.

import birl.{type Time}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile
import todo_item.{type TodoItem}

pub type WriteError {
  DirectoryNotFound(String)
  WriteFailure(String, String)
  InvalidItem(String)
}

/// Convert TodoItem to standards-compliant iCalendar VTODO format
pub fn item_to_vtodo(item: TodoItem) -> String {
  let timestamp = format_datetime(birl.utc_now())
  let created = format_datetime(item.created_at)
  let modified = format_datetime(item.modified_at)
  let status = case item.completed {
    True -> "COMPLETED"
    False -> "NEEDS-ACTION"
  }

  let lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Todo.md Sync//EN",
    "CALSCALE:GREGORIAN",
    "BEGIN:VTODO",
    "UID:" <> item.uid,
    "DTSTAMP:" <> timestamp,
    "CREATED:" <> created,
    "LAST-MODIFIED:" <> modified,
    "SUMMARY:" <> escape_text(item.summary),
    "STATUS:" <> status,
    "CATEGORIES:" <> escape_text(item.section),
  ]

  let lines_with_location = case item.context {
    Some(context) -> {
      let location = context |> string.drop_start(1) |> escape_text
      // Remove @ prefix
      list.append(lines, ["LOCATION:" <> location])
    }
    None -> lines
  }

  let lines_with_due = case item.due_date {
    Some(date) -> {
      let due_str = "DUE;VALUE=DATE:" <> format_date(date)
      list.append(lines_with_location, [due_str])
    }
    None -> lines_with_location
  }

  let lines_with_start = case item.start_date {
    Some(date) -> {
      let start_str = "DTSTART;VALUE=DATE:" <> format_date(date)
      list.append(lines_with_due, [start_str])
    }
    None -> lines_with_due
  }

  let lines_with_description = case item.notes {
    [] -> lines_with_start
    notes -> {
      let description =
        notes
        |> string.join("\\n")
        |> escape_text()
      list.append(lines_with_start, ["DESCRIPTION:" <> description])
    }
  }

  let final_lines =
    list.append(lines_with_description, ["END:VTODO", "END:VCALENDAR"])

  string.join(final_lines, "\r\n")
}

/// Write TodoItem as .ics file to specified directory
pub fn write_ics_file(
  item: TodoItem,
  directory: String,
) -> Result(Nil, WriteError) {
  case todo_item.validate(item) {
    Error(_) -> Error(InvalidItem("TodoItem validation failed"))
    Ok(valid_item) -> {
      let filename = get_filename_from_uid(valid_item.uid)
      let safe_filename = sanitize_filename(filename)
      let filepath = directory <> "/" <> safe_filename <> ".ics"
      let content = item_to_vtodo(valid_item)

      case simplifile.write(filepath, content) {
        Ok(_) -> Ok(Nil)
        Error(_) -> Error(WriteFailure(filepath, "Failed to write ICS file"))
      }
    }
  }
}

/// Write multiple TodoItems as .ics files to directory
/// Cleans existing .ics files first to prevent duplicates
pub fn write_ics_files(
  items: List(TodoItem),
  directory: String,
) -> Result(Nil, WriteError) {
  case ensure_directory_exists(directory) {
    Error(err) -> Error(err)
    Ok(_) -> {
      // Clean existing .ics files first to prevent duplicates
      case clean_ics_directory(directory) {
        Error(err) -> Error(err)
        Ok(_) -> {
          items
          |> list.try_each(fn(item) { write_ics_file(item, directory) })
          |> result.replace(Nil)
        }
      }
    }
  }
}

/// Get filename prefix from UID (first 12 characters before @)
fn get_filename_from_uid(uid: String) -> String {
  case string.split(uid, "@") {
    [prefix, ..] -> prefix
    [] -> uid
  }
}

/// Clean all existing .ics files from directory to prevent duplicates
fn clean_ics_directory(directory: String) -> Result(Nil, WriteError) {
  case simplifile.read_directory(directory) {
    Ok(files) -> {
      files
      |> list.filter(fn(file) { string.ends_with(file, ".ics") })
      |> list.try_each(fn(file) {
        let filepath = directory <> "/" <> file
        case simplifile.delete(filepath) {
          Ok(_) -> Ok(Nil)
          Error(_) ->
            Error(WriteFailure(filepath, "Failed to delete existing ICS file"))
        }
      })
      |> result.replace(Nil)
    }
    Error(_) -> Ok(Nil)
    // Directory doesn't exist yet or is empty, nothing to clean
  }
}

/// Ensure directory exists, creating it if necessary
fn ensure_directory_exists(directory: String) -> Result(Nil, WriteError) {
  case simplifile.create_directory_all(directory) {
    Ok(_) -> Ok(Nil)
    Error(simplifile.Eexist) -> Ok(Nil)
    // Directory already exists
    Error(_) -> Error(DirectoryNotFound(directory))
  }
}

/// Escape text for iCalendar format according to RFC 5545
fn escape_text(text: String) -> String {
  text
  |> string.replace("\\", "\\\\")
  // Backslash → \\
  |> string.replace(",", "\\,")
  // Comma → \,
  |> string.replace(";", "\\;")
  // Semicolon → \;
  |> string.replace("\n", "\\n")
  // Newline → \n
}

/// Format Time as iCalendar DATETIME (YYYYMMDDTHHMMSSZ)
fn format_datetime(time: Time) -> String {
  // Convert to ISO8601 and then to iCalendar format
  let iso = birl.to_iso8601(time)

  // Remove milliseconds (everything after the dot before Z)
  let without_millis = case string.split(iso, ".") {
    [datetime, _rest] -> datetime <> "Z"
    _ -> iso
  }

  without_millis
  |> string.replace("-", "")
  |> string.replace(":", "")
}

/// Format Time as iCalendar DATE (YYYYMMDD)
/// Sanitize filename to prevent directory traversal
fn sanitize_filename(filename: String) -> String {
  filename
  // Remove directory separators and dangerous characters
  |> string.replace("/", "_")
  |> string.replace("\\", "_")
  |> string.replace("..", "dotdot")
  |> string.replace(":", "_")
  |> string.replace("*", "_")
  |> string.replace("?", "_")
  |> string.replace("\"", "_")
  |> string.replace("<", "_")
  |> string.replace(">", "_")
  |> string.replace("|", "_")
  |> string.replace("\n", "_")
  |> string.replace("\r", "_")
  |> string.replace("\t", "_")
  // Ensure not empty and doesn't start with dangerous patterns
  |> fn(name) {
    case name {
      "" -> "default_task"
      name -> {
        case string.starts_with(name, ".") {
          True -> "task_" <> name
          False -> name
        }
      }
    }
  }
  // Limit length
  |> string.slice(0, 100)
}

fn format_date(time: Time) -> String {
  // Convert to ISO date and remove hyphens
  birl.to_iso8601(time)
  |> string.split("T")
  |> list.first()
  |> result.unwrap(get_current_date_fallback())
  |> string.replace("-", "")
}

/// Get current date as fallback instead of hardcoded year
fn get_current_date_fallback() -> String {
  birl.utc_now()
  |> birl.to_iso8601()
  |> string.split("T")
  |> list.first()
  |> result.unwrap("2024-01-01")
}
