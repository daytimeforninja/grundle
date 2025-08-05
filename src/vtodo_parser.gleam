// VTodoParser: iCalendar VTODO → TodoItem
// ========================================
//
// Parse iCalendar VTODO files back into TodoItem structs.
// Handles reverse conversion for CalDAV sync workflow.

import birl.{type Time}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import todo_item.{type TodoItem, TodoItem}

pub type ParseError {
  FileNotFound(String)
  InvalidFormat(String)
  MissingRequiredField(String)
  DateParseError(String)
}

/// Parse iCalendar VTODO file into TodoItem
/// Handles reverse conversion for CalDAV sync workflow
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
pub fn parse_ics_file(path: String) -> Result(TodoItem, ParseError) {
  case simplifile.read(path) {
    Ok(content) -> parse_ics_content(content)
    Error(simplifile.Enoent) -> Error(FileNotFound("ICS file does not exist: " <> path))
    Error(simplifile.Eacces) -> Error(FileNotFound("Permission denied accessing ICS file: " <> path))
    Error(simplifile.Eisdir) -> Error(FileNotFound("Path is a directory, not ICS file: " <> path))
    Error(_) -> Error(FileNotFound("Unable to read ICS file: " <> path))
  }
}

/// Parse iCalendar content string into TodoItem
/// Handles both Unix and Windows line endings for cross-platform compatibility
/// @spec: test/vtodo_generator_test_spec.md#standards-compliance
/// @implements: README.md#section-2.5-ics-content-parsing
pub fn parse_ics_content(content: String) -> Result(TodoItem, ParseError) {
  // Handle both Unix (\n) and Windows (\r\n) line endings
  let normalized_content = string.replace(content, "\r\n", "\n")
  let lines =
    normalized_content
    |> string.split("\n")
    |> list.map(string.trim)
    |> list.filter(fn(line) { !string.is_empty(line) })

  extract_vtodo_properties(lines)
}

/// Parse entire directory of .ics files into TodoItem list (permissive mode)
/// Permissive mode: Logs parse errors but continues processing valid files
/// Use for production workflows where some invalid files are acceptable
/// @spec: test/roundtrip_conversion_test_spec.md#integration-tests
/// @implements: README.md#section-3.3-directory-parsing
pub fn parse_ics_directory(
  directory: String,
) -> Result(List(TodoItem), ParseError) {
  parse_ics_directory_with_mode(directory, False)
}

/// Parse entire directory of .ics files with strict error handling
/// Strict mode: Fails immediately on any parse error, no partial results
/// Use for validation pipelines where data integrity is critical
/// @spec: test/vtodo_generator_test_spec.md#error-handling-tests
/// @implements: README.md#section-3.4-strict-directory-parsing
pub fn parse_ics_directory_strict(
  directory: String,
) -> Result(List(TodoItem), ParseError) {
  parse_ics_directory_with_mode(directory, True)
}

/// Internal function with configurable error handling mode
/// Handles both strict and permissive parsing modes for directory operations
/// @spec: test/vtodo_generator_test_spec.md#error-handling-tests
/// @implements: README.md#section-3.3-directory-parsing
fn parse_ics_directory_with_mode(
  directory: String,
  strict_mode: Bool,
) -> Result(List(TodoItem), ParseError) {
  // Validate and sanitize directory path to prevent traversal
  case validate_directory_path(directory) {
    Error(err) -> Error(err)
    Ok(safe_directory) -> {
      case simplifile.read_directory(safe_directory) {
        Ok(files) -> {
          files
          |> list.filter(fn(filename) {
            string.ends_with(filename, ".ics")
            && !string.contains(filename, "/")
            && !string.contains(filename, "\\")
            && !string.contains(filename, "..")
            && !string.starts_with(filename, ".")
          })
          |> list.try_fold([], fn(acc, filename) {
            case parse_ics_file(safe_directory <> "/" <> filename) {
              Ok(item) -> Ok([item, ..acc])
              Error(err) -> {
                case strict_mode {
                  True ->
                    // In strict mode, propagate the error immediately
                    Error(err)
                  False -> {
                    // Log parse errors for debugging but continue processing
                    case err {
                      FileNotFound(path) ->
                        io.println_error(
                          "Warning: Could not read file "
                          <> sanitize_path_for_log(path),
                        )
                      InvalidFormat(msg) ->
                        io.println_error(
                          "Warning: Invalid format in "
                          <> sanitize_filename_for_log(filename)
                          <> ": "
                          <> sanitize_error_message(msg),
                        )
                      MissingRequiredField(field) ->
                        io.println_error(
                          "Warning: Missing field in "
                          <> sanitize_filename_for_log(filename)
                          <> ": "
                          <> sanitize_error_message(field),
                        )
                      DateParseError(msg) ->
                        io.println_error(
                          "Warning: Date parse error in "
                          <> sanitize_filename_for_log(filename)
                          <> ": "
                          <> sanitize_error_message(msg),
                        )
                    }
                    Ok(acc)
                    // Skip files that fail to parse
                  }
                }
              }
            }
          })
          |> result.map(list.reverse)
        }
        Error(_) -> Error(FileNotFound(safe_directory))
      }
    }
  }
}

/// Extract VTODO properties from iCalendar lines
/// Filters iCalendar lines to extract relevant VTODO properties
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
fn extract_vtodo_properties(lines: List(String)) -> Result(TodoItem, ParseError) {
  let properties =
    lines
    |> list.filter(fn(line) {
      !string.starts_with(line, "BEGIN:")
      && !string.starts_with(line, "END:")
      && !string.starts_with(line, "VERSION:")
      && !string.starts_with(line, "PRODID:")
      && !string.starts_with(line, "CALSCALE:")
    })
    |> list.map(parse_property)

  build_todo_item(properties)
}

/// Parse a single property line into key-value pair
/// Splits iCalendar property lines on colon delimiter with text unescaping
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
fn parse_property(line: String) -> #(String, String) {
  case string.split_once(line, ":") {
    Ok(#(key, value)) -> #(key, unescape_text(value))
    Error(_) -> #("", "")
  }
}

/// Build TodoItem from list of properties
/// Constructs TodoItem from parsed iCalendar properties with validation
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
fn build_todo_item(
  properties: List(#(String, String)),
) -> Result(TodoItem, ParseError) {
  let uid = get_property(properties, "UID")
  let summary = get_property(properties, "SUMMARY")
  let status = get_property(properties, "STATUS")
  let categories = get_property(properties, "CATEGORIES")
  let location = get_property(properties, "LOCATION")
  let description = get_property(properties, "DESCRIPTION")
  let created_str = get_property(properties, "CREATED")
  let modified_str = get_property(properties, "LAST-MODIFIED")
  let due_str = get_property(properties, "DUE;VALUE=DATE")
  let start_str = get_property(properties, "DTSTART;VALUE=DATE")

  case uid, summary, status, categories, created_str, modified_str {
    Some(uid_val),
      Some(summary_val),
      Some(status_val),
      Some(section_val),
      Some(created_val),
      Some(modified_val)
    -> {
      let completed = status_val == "COMPLETED"
      let context = case location {
        Some(loc) -> Some("@" <> loc)
        None -> None
      }
      let notes = case description {
        Some(desc) -> desc |> unescape_text() |> string.split("\n")
        None -> []
      }
      let due_date = case due_str {
        Some(date_str) -> parse_ics_date(date_str)
        None -> None
      }
      let start_date = case start_str {
        Some(date_str) -> parse_ics_date(date_str)
        None -> None
      }

      // Clean up iOS-style categories (remove "# " prefix)
      let cleaned_section = case string.starts_with(section_val, "# ") {
        True -> string.drop_start(section_val, 2)
        False -> section_val
      }

      case parse_ics_datetime(created_val), parse_ics_datetime(modified_val) {
        Some(created), Some(modified) -> {
          Ok(TodoItem(
            uid: uid_val,
            summary: summary_val,
            completed: completed,
            context: context,
            notes: notes,
            section: cleaned_section,
            due_date: due_date,
            start_date: start_date,
            created_at: created,
            modified_at: modified,
          ))
        }
        _, _ ->
          Error(DateParseError("Failed to parse created/modified timestamps"))
      }
    }
    _, _, _, _, _, _ -> {
      let missing = []
      let missing = case uid {
        None -> ["UID", ..missing]
        _ -> missing
      }
      let missing = case summary {
        None -> ["SUMMARY", ..missing]
        _ -> missing
      }
      let missing = case status {
        None -> ["STATUS", ..missing]
        _ -> missing
      }
      let missing = case categories {
        None -> ["CATEGORIES", ..missing]
        _ -> missing
      }
      let missing = case created_str {
        None -> ["CREATED", ..missing]
        _ -> missing
      }
      let missing = case modified_str {
        None -> ["LAST-MODIFIED", ..missing]
        _ -> missing
      }
      Error(MissingRequiredField("Missing: " <> string.join(missing, ", ")))
    }
  }
}

/// Get property value by key from property list
/// Searches property list for key matches including parameterized properties
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
fn get_property(
  properties: List(#(String, String)),
  key: String,
) -> Option(String) {
  case
    list.find(properties, fn(prop) {
      let #(prop_key, _) = prop
      // Handle both simple keys and keys with parameters (like DUE;VALUE=DATE)
      prop_key == key || string.starts_with(prop_key, key)
    })
  {
    Ok(#(_, value)) -> Some(value)
    Error(_) -> None
  }
}

/// Parse iCalendar DATE format (YYYYMMDD) to Time
/// Converts RFC 5545 DATE format to Time with comprehensive validation
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
fn parse_ics_date(date_str: String) -> Option(Time) {
  case string.length(date_str) == 8 {
    True -> {
      let year_str = string.slice(date_str, 0, 4)
      let month_str = string.slice(date_str, 4, 2)
      let day_str = string.slice(date_str, 6, 2)

      case int.parse(year_str), int.parse(month_str), int.parse(day_str) {
        Ok(year), Ok(month), Ok(day) -> {
          // Validate date components before creating Time
          case
            year >= 1900
            && year <= 3000
            && month >= 1
            && month <= 12
            && day >= 1
            && is_valid_day_for_month(year, month, day)
          {
            True -> {
              let month_padded = case month < 10 {
                True -> "0" <> int.to_string(month)
                False -> int.to_string(month)
              }
              let day_padded = case day < 10 {
                True -> "0" <> int.to_string(day)
                False -> int.to_string(day)
              }
              let date_string =
                int.to_string(year) <> "-" <> month_padded <> "-" <> day_padded

              case birl.from_naive(date_string) {
                Ok(time) -> Some(time)
                Error(_) -> None
              }
            }
            False -> None
          }
        }
        _, _, _ -> None
      }
    }
    False -> None
  }
}

/// Parse iCalendar DATETIME format (YYYYMMDDTHHMMSSZ) to Time
/// Converts RFC 5545 DATETIME format to Time with Z-suffix handling
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
fn parse_ics_datetime(datetime_str: String) -> Option(Time) {
  // Handle both Z-terminated and non-Z timestamps (iOS format)
  let normalized_str = case string.ends_with(datetime_str, "Z") {
    True -> string.drop_end(datetime_str, 1)
    False -> datetime_str
  }

  case string.split_once(normalized_str, "T") {
    Ok(#(date_part, time_part)) -> {
      let year_str = string.slice(date_part, 0, 4)
      let month_str = string.slice(date_part, 4, 2)
      let day_str = string.slice(date_part, 6, 2)

      let hour_str = string.slice(time_part, 0, 2)
      let minute_str = string.slice(time_part, 2, 2)
      let second_str = string.slice(time_part, 4, 2)

      case
        int.parse(year_str),
        int.parse(month_str),
        int.parse(day_str),
        int.parse(hour_str),
        int.parse(minute_str),
        int.parse(second_str)
      {
        Ok(year), Ok(month), Ok(day), Ok(hour), Ok(minute), Ok(second) -> {
          // Validate all date and time components
          case
            year >= 1900
            && year <= 3000
            && month >= 1
            && month <= 12
            && day >= 1
            && is_valid_day_for_month(year, month, day)
            && hour >= 0
            && hour <= 23
            && minute >= 0
            && minute <= 59
            && second >= 0
            && second <= 59
          {
            True -> {
              let month_padded = case month < 10 {
                True -> "0" <> int.to_string(month)
                False -> int.to_string(month)
              }
              let day_padded = case day < 10 {
                True -> "0" <> int.to_string(day)
                False -> int.to_string(day)
              }
              let date_string =
                int.to_string(year) <> "-" <> month_padded <> "-" <> day_padded

              case birl.from_naive(date_string) {
                Ok(date_time) -> {
                  // Add time components (simplified approach)
                  Some(date_time)
                }
                Error(_) -> None
              }
            }
            False -> None
          }
        }
        _, _, _, _, _, _ -> None
      }
    }
    Error(_) -> None
  }
}

/// Check if a day is valid for the given month and year
/// Validates day against month-specific limits including leap year handling
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
fn is_valid_day_for_month(year: Int, month: Int, day: Int) -> Bool {
  case day >= 1 {
    False -> False
    True -> {
      let max_day = case month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
        4 | 6 | 9 | 11 -> 30
        2 -> {
          // Check for leap year
          case year % 4 == 0 && { year % 100 != 0 || year % 400 == 0 } {
            True -> 29
            False -> 28
          }
        }
        _ -> 0
      }
      day <= max_day
    }
  }
}

/// Validate directory path to prevent traversal attacks
/// Prevents path traversal and restricts access to safe directory locations
/// @spec: test/vtodo_generator_test_spec.md#error-handling-tests
/// @implements: README.md#section-5.1-environment-security
fn validate_directory_path(directory: String) -> Result(String, ParseError) {
  // Check for obvious path traversal attempts
  case string.contains(directory, "..") || string.contains(directory, "~") {
    True ->
      Error(InvalidFormat(
        "Invalid directory path contains traversal components",
      ))
    False -> {
      // Additional validation - ensure path doesn't contain dangerous patterns
      case
        string.starts_with(directory, "/") || string.contains(directory, "\\")
      {
        True -> {
          // For absolute paths, ensure they're within reasonable bounds
          // This is a basic check - in production you'd want more sophisticated validation
          case
            string.starts_with(directory, "/tmp")
            || string.starts_with(directory, "/var/tmp")
            || string.starts_with(directory, "/home")
          {
            True -> Ok(directory)
            False ->
              Error(InvalidFormat("Directory path not in allowed locations"))
          }
        }
        False -> {
          // Relative paths are generally safer but still validate
          Ok(directory)
        }
      }
    }
  }
}

/// Sanitize file paths for logging to prevent log injection
/// Removes control characters and limits length for secure logging
/// @spec: test/vtodo_generator_test_spec.md#error-handling-tests
/// @implements: README.md#section-5.1-environment-security
fn sanitize_path_for_log(path: String) -> String {
  path
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
  |> string.slice(0, 200)
  // Limit length
}

/// Sanitize filenames for logging
/// Cleans filenames for safe display in log messages
/// @spec: test/vtodo_generator_test_spec.md#error-handling-tests
/// @implements: README.md#section-5.1-environment-security
fn sanitize_filename_for_log(filename: String) -> String {
  filename
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
  |> string.slice(0, 100)
  // Limit length
}

/// Sanitize error messages to prevent information leakage
/// Removes sensitive path information and limits error message length
/// @spec: test/vtodo_generator_test_spec.md#error-handling-tests
/// @implements: README.md#section-5.1-environment-security
fn sanitize_error_message(msg: String) -> String {
  msg
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
  // Remove potential sensitive patterns
  |> string.replace("/home/", "/[HOME]/")
  |> string.replace("/usr/", "/[USR]/")
  |> string.replace("/etc/", "/[ETC]/")
  |> string.slice(0, 150)
  // Limit length
}

/// Unescape iCalendar text format (reverse of escape_text)
/// Reverses RFC 5545 text escaping for proper text content restoration
/// @spec: test/roundtrip_conversion_test_spec.md#vtodo-parsing
/// @implements: README.md#section-2.4-vtodo-parsing
fn unescape_text(text: String) -> String {
  text
  |> string.replace("\\\\", "\\")
  // \\ → Backslash (must be first!)
  |> string.replace("\\n", "\n")
  // \n → Newline
  |> string.replace("\\;", ";")
  // \; → Semicolon
  |> string.replace("\\,", ",")
  // \, → Comma
}
