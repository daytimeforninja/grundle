// MarkdownParser: GTD Markdown → TodoItem
// ==========================================
//
// Parse GTD-style todo.md files into structured TodoItem list.
// Handles section headers, checkbox tasks, contexts, dates, and sub-notes.

import birl.{type Time}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/string
import simplifile
import todo_item.{type TodoItem, TodoItem}

pub type ParseError {
  FileNotFound(String)
  FileReadError(String)
  InvalidContent(String)
}

pub type ParseState {
  ParseState(
    current_section: String,
    current_item: Option(TodoItem),
    completed_items: List(TodoItem),
  )
}

/// Parse GTD-style todo.md file into TodoItem list
/// Handles GTD principle: contexts should be flexible user-defined strings
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-1.1-markdown-parsing
pub fn parse_file(path: String) -> Result(List(TodoItem), ParseError) {
  case simplifile.read(path) {
    Ok(content) -> Ok(parse_content(content))
    Error(simplifile.Enoent) -> Error(FileNotFound("File does not exist: " <> path))
    Error(simplifile.Eacces) -> Error(FileReadError("Permission denied: " <> path))  
    Error(simplifile.Eisdir) -> Error(FileReadError("Path is a directory: " <> path))
    Error(_) -> Error(FileReadError("Unable to read file: " <> path))
  }
}

/// Parse markdown content string into TodoItem list
/// Implements GTD methodology for section headers, contexts, dates, and sub-notes
/// @spec: test/markdown_parser_test_spec.md#complex-real-world-examples
/// @implements: README.md#section-2.1-content-parsing
pub fn parse_content(content: String) -> List(TodoItem) {
  // Validate input size to prevent resource exhaustion
  let content_length = string.length(content)
  case content_length > 10_000_000 {  // 10MB limit
    True -> {
      io.println_error(
        "Warning: Input content is very large (" <> int.to_string(content_length) <> " characters). Processing may be slow or fail.",
      )
    }
    False -> Nil
  }

  let lines = string.split(content, "\n")
  
  // Limit line count to prevent memory issues
  let line_count = list.length(lines)
  case line_count > 100_000 {  // 100k lines limit
    True -> {
      io.println_error(
        "Warning: Input has many lines (" <> int.to_string(line_count) <> "). Processing first 100,000 lines only.",
      )
      let limited_lines = list.take(lines, 100_000)
      parse_lines(limited_lines)
    }
    False -> parse_lines(lines)
  }
}

/// Internal function to parse a list of lines into TodoItems
/// Separated for better resource limit handling
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn parse_lines(lines: List(String)) -> List(TodoItem) {
  let initial_state =
    ParseState(
      current_section: "Inbox",
      current_item: None,
      completed_items: [],
    )

  let final_state = list.fold(lines, initial_state, process_line)

  // Add any remaining current_item to completed list (with proper note reversal)
  let final_state_with_item = add_current_item_to_completed(final_state)
  let items = final_state_with_item.completed_items |> list.reverse()
  
  // Warn if we have an unusually large number of tasks
  let item_count = list.length(items)
  case item_count > 10_000 {
    True -> {
      io.println_error(
        "Warning: Processed " <> int.to_string(item_count) <> " tasks. Large numbers of tasks may impact performance.",
      )
    }
    False -> Nil
  }
  
  items
}

/// Process a single line and update parse state
/// Core parsing logic that handles section headers, tasks, and notes
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn process_line(state: ParseState, line: String) -> ParseState {
  let trimmed_line = string.trim(line)

  // Check line types and process accordingly
  case is_section_header(trimmed_line) {
    True -> {
      let new_section = extract_section_name(trimmed_line)
      let state_with_item = add_current_item_to_completed(state)
      ParseState(..state_with_item, current_section: new_section)
    }
    False ->
      case is_task_line(trimmed_line) {
        True -> {
          let state_with_item = add_current_item_to_completed(state)
          case parse_task_line(trimmed_line, state_with_item.current_section) {
            Some(new_item) ->
              ParseState(..state_with_item, current_item: Some(new_item))
            None -> state_with_item
          }
        }
        False ->
          case is_note_line(line) {
            True -> {
              case state.current_item {
                Some(item) -> {
                  // Limit note count and length to prevent resource exhaustion
                  case list.length(item.notes) >= 100 {
                    True -> {
                      // Log warning and skip additional notes
                      io.println_error(
                        "Warning: Maximum note limit (100) reached for task, skipping additional notes",
                      )
                      state
                    }
                    False -> {
                      let note_text = extract_note_text(line)
                      // Limit individual note length
                      let truncated_note = case
                        string.length(note_text) > 1000
                      {
                        True -> {
                          io.println_error(
                            "Warning: Note truncated from " <> int.to_string(string.length(note_text)) <> " to 1000 characters in task: " <> string.slice(item.summary, 0, 50) <> "..."
                          )
                          string.slice(note_text, 0, 1000) <> "... (truncated)"
                        }
                        False -> note_text
                      }
                      let updated_item =
                        TodoItem(..item, notes: [truncated_note, ..item.notes])
                      ParseState(..state, current_item: Some(updated_item))
                    }
                  }
                }
                None -> state
              }
            }
            False -> state
            // Ignore other lines
          }
      }
  }
}

/// Check if line is a section header (## Section Name)
/// Identifies GTD section boundaries for task organization
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn is_section_header(line: String) -> Bool {
  string.starts_with(line, "##")
}

/// Extract section name from header line
/// Parses section titles for TodoItem categorization
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn extract_section_name(line: String) -> String {
  line
  |> string.drop_start(2)
  |> string.trim()
}

/// Check if line is a task line (- [ ] or - [x])
/// Uses regex to identify valid GTD checkbox syntax
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn is_task_line(line: String) -> Bool {
  let task_pattern = "^-\\s+\\[([ x])\\]\\s+.+"
  case regexp.from_string(task_pattern) {
    Ok(re) -> regexp.check(re, line)
    Error(_) -> False
  }
}

/// Check if line is a note line (exactly 2 spaces + dash)
/// Identifies properly indented sub-notes, ignores deeper indentation
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn is_note_line(line: String) -> Bool {
  string.starts_with(line, "  - ")
}

/// Extract note text from indented line
/// Cleans indentation and dash prefix from sub-notes
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn extract_note_text(line: String) -> String {
  line
  |> string.trim()
  |> string.drop_start(1)
  |> string.trim()
}

/// Parse task line into TodoItem
/// Converts checkbox syntax to TodoItem with completion status and content parsing
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn parse_task_line(line: String, section: String) -> Option(TodoItem) {
  let task_pattern = "^-\\s+\\[([ x])\\]\\s+(.+)$"
  case regexp.from_string(task_pattern) {
    Ok(re) -> {
      case regexp.scan(re, line) {
        [regexp.Match(_, [Some(checkbox), Some(content)])] -> {
          let completed = checkbox == "x"
          let #(summary, context, due_date, start_date) =
            parse_task_content(content)

          Some(todo_item.new(
            summary,
            section,
            completed,
            context,
            [],
            due_date,
            start_date,
          ))
        }
        _ -> None
      }
    }
    Error(_) -> None
  }
}

/// Parse task content to extract summary, context, and dates
/// Coordinates context extraction, date parsing, and summary cleaning
/// @spec: test/markdown_parser_test_spec.md#complex-real-world-examples
/// @implements: README.md#section-2.1-content-parsing
fn parse_task_content(
  content: String,
) -> #(String, Option(String), Option(Time), Option(Time)) {
  let #(summary_with_dates, context) = extract_context(content)
  
  // Extract both dates independently from the original text
  let #(_, start_date) = extract_start_date(summary_with_dates)
  let #(_, due_date) = extract_due_date(summary_with_dates)
  
  // Clean summary by removing both date patterns
  let summary_after_start = case extract_start_date(summary_with_dates) {
    #(clean, _) -> clean
  }
  let clean_summary = case extract_due_date(summary_after_start) {
    #(clean, _) -> clean
  }

  #(clean_summary, context, due_date, start_date)
}

/// Extract context (@word) from end of content
/// Implements GTD context extraction with regex pattern matching
/// @spec: test/markdown_parser_test_spec.md#complex-real-world-examples
/// @implements: README.md#section-2.1-content-parsing
fn extract_context(content: String) -> #(String, Option(String)) {
  let context_pattern = "^(.+?)\\s+(@\\w+)\\s*$"
  case regexp.from_string(context_pattern) {
    Ok(re) -> {
      case regexp.scan(re, content) {
        [regexp.Match(_, [Some(summary), Some(context)])] -> #(
          string.trim(summary),
          Some(context),
        )
        _ -> #(content, None)
      }
    }
    Error(_) -> #(content, None)
  }
}

/// Extract due date from "Due MM/DD" patterns
/// Parses due date patterns and removes them from summary text
/// @spec: test/markdown_parser_test_spec.md#complex-real-world-examples
/// @implements: README.md#section-2.1-content-parsing
fn extract_due_date(content: String) -> #(String, Option(Time)) {
  let due_pattern = "^(.+?)\\s*-?\\s*[Dd]ue\\s+(\\d{1,2}/\\d{1,2})"
  case regexp.from_string(due_pattern) {
    Ok(re) -> {
      case regexp.scan(re, content) {
        [regexp.Match(_, [Some(summary), Some(date_str)])] -> {
          let parsed_date = parse_date_string(date_str)
          #(string.trim(summary), parsed_date)
        }
        _ -> #(content, None)
      }
    }
    Error(_) -> #(content, None)
  }
}

/// Extract start date from "Scheduled for MM/DD" patterns
/// Parses scheduling patterns and removes them from summary text
/// @spec: test/markdown_parser_test_spec.md#complex-real-world-examples
/// @implements: README.md#section-2.1-content-parsing
fn extract_start_date(content: String) -> #(String, Option(Time)) {
  let start_pattern =
    "^(.+?)\\s*-?\\s*[Ss]cheduled\\s+for\\s+(\\d{1,2}/\\d{1,2})"
  case regexp.from_string(start_pattern) {
    Ok(re) -> {
      case regexp.scan(re, content) {
        [regexp.Match(_, [Some(summary), Some(date_str)])] -> {
          let parsed_date = parse_date_string(date_str)
          #(string.trim(summary), parsed_date)
        }
        _ -> #(content, None)
      }
    }
    Error(_) -> #(content, None)
  }
}

/// Check if a day is valid for the given month and year
/// Handles leap years and month-specific day limits for date validation
/// @spec: test/markdown_parser_test_spec.md#complex-real-world-examples
/// @implements: README.md#section-2.1-content-parsing
fn is_valid_day(year: Int, month: Int, day: Int) -> Bool {
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

/// Parse MM/DD date strings into Time objects with smart year inference
/// Handles date validation, leap years, and year boundary edge cases
/// @spec: test/markdown_parser_test_spec.md#complex-real-world-examples
/// @implements: README.md#section-2.1-content-parsing
fn parse_date_string(date_str: String) -> Option(Time) {
  case string.split(date_str, "/") {
    [month_str, day_str] -> {
      case int.parse(month_str), int.parse(day_str) {
        Ok(month), Ok(day) if month >= 1 && month <= 12 -> {
          // Smart year inference to handle year boundaries
          let current_time = birl.utc_now()
          let current_day = birl.get_day(current_time)
          let current_year = current_day.year
          let current_month = current_day.month
          
          // If date is more than 6 months in the past, assume next year
          // If date is more than 6 months in the future, assume last year
          let inferred_year = case month {
            // Date is in past months - check if it's too far back
            m if m < current_month -> {
              case current_month - m > 6 {
                True -> current_year + 1  // Assume next year
                False -> current_year     // Same year
              }
            }
            // Date is in future months - check if it's too far ahead  
            m if m > current_month -> {
              case m - current_month > 6 {
                True -> current_year - 1  // Assume last year
                False -> current_year     // Same year
              }
            }
            // Same month - use current year
            _ -> current_year
          }

          case is_valid_day(inferred_year, month, day) {
            False -> None
            True -> {
              // Create ISO date string
              let month_padded = case month < 10 {
                True -> "0" <> int.to_string(month)
                False -> int.to_string(month)
              }
              let day_padded = case day < 10 {
                True -> "0" <> int.to_string(day)
                False -> int.to_string(day)
              }

              let date_string =
                int.to_string(inferred_year)
                <> "-"
                <> month_padded
                <> "-"
                <> day_padded

              case birl.from_naive(date_string) {
                Ok(time) -> Some(time)
                Error(_) -> None
              }
            }
          }
        }
        _, _ -> None
      }
    }
    _ -> None
  }
}

/// Add current item to completed list if it exists
/// Manages parse state transitions and note list reversal for proper order
/// @spec: test/markdown_parser_test_spec.md#basic-task-parsing
/// @implements: README.md#section-2.1-content-parsing
fn add_current_item_to_completed(state: ParseState) -> ParseState {
  case state.current_item {
    Some(item) -> {
      // Reverse notes since we prepended them during parsing
      let item_with_correct_notes =
        TodoItem(..item, notes: list.reverse(item.notes))
      ParseState(
        current_section: state.current_section,
        current_item: None,
        completed_items: [item_with_correct_notes, ..state.completed_items],
      )
    }
    None -> state
  }
}
