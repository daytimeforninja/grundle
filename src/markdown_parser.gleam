// MarkdownParser: GTD Markdown → TodoItem
// ==========================================
//
// Parse GTD-style todo.md files into structured TodoItem list.
// Handles section headers, checkbox tasks, contexts, dates, and sub-notes.

import birl.{type Time}
import gleam/int
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
pub fn parse_file(path: String) -> Result(List(TodoItem), ParseError) {
  case simplifile.read(path) {
    Ok(content) -> Ok(parse_content(content))
    Error(_) -> Error(FileNotFound(path))
  }
}

/// Parse markdown content string into TodoItem list
pub fn parse_content(content: String) -> List(TodoItem) {
  let lines = string.split(content, "\n")
  let initial_state =
    ParseState(
      current_section: "Inbox",
      current_item: None,
      completed_items: [],
    )

  let final_state = list.fold(lines, initial_state, process_line)

  // Add any remaining current_item to completed list
  case final_state.current_item {
    Some(item) -> [item, ..final_state.completed_items]
    None -> final_state.completed_items
  }
  |> list.reverse()
}

/// Process a single line and update parse state
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
                  let note_text = extract_note_text(line)
                  let updated_item =
                    TodoItem(..item, notes: [note_text, ..item.notes])
                  ParseState(..state, current_item: Some(updated_item))
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
fn is_section_header(line: String) -> Bool {
  string.starts_with(line, "##")
}

/// Extract section name from header line
fn extract_section_name(line: String) -> String {
  line
  |> string.drop_start(2)
  |> string.trim()
}

/// Check if line is a task line (- [ ] or - [x])
fn is_task_line(line: String) -> Bool {
  let task_pattern = "^-\\s+\\[([ x])\\]\\s+.+"
  case regexp.from_string(task_pattern) {
    Ok(re) -> regexp.check(re, line)
    Error(_) -> False
  }
}

/// Check if line is a note line (starts with spaces and -)
fn is_note_line(line: String) -> Bool {
  case string.first(line) {
    Ok(" ") -> {
      let trimmed = string.trim(line)
      string.starts_with(trimmed, "-")
    }
    _ -> False
  }
}

/// Extract note text from indented line
fn extract_note_text(line: String) -> String {
  line
  |> string.trim()
  |> string.drop_start(1)
  |> string.trim()
}

/// Parse task line into TodoItem
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
fn parse_task_content(
  content: String,
) -> #(String, Option(String), Option(Time), Option(Time)) {
  let #(summary_with_dates, context) = extract_context(content)
  let #(summary_with_due, start_date) = extract_start_date(summary_with_dates)
  let #(clean_summary, due_date) = extract_due_date(summary_with_due)

  #(clean_summary, context, due_date, start_date)
}

/// Extract context (@word) from end of content
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
fn extract_due_date(content: String) -> #(String, Option(Time)) {
  let due_pattern = "^(.+?)\\s*-?\\s*[Dd]ue\\s+(\\d{1,2}/\\d{1,2})\\s*$"
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
fn extract_start_date(content: String) -> #(String, Option(Time)) {
  let start_pattern =
    "^(.+?)\\s*-?\\s*[Ss]cheduled\\s+for\\s+(\\d{1,2}/\\d{1,2})\\s*$"
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

/// Parse MM/DD date string with intelligent year inference
/// Check if a day is valid for the given month and year
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

fn parse_date_string(date_str: String) -> Option(Time) {
  case string.split(date_str, "/") {
    [month_str, day_str] -> {
      case int.parse(month_str), int.parse(day_str) {
        Ok(month), Ok(day) if month >= 1 && month <= 12 -> {
          // Extract current year from system time
          let current_time = birl.utc_now()
          let current_year = birl.get_day(current_time).year

          case is_valid_day(current_year, month, day) {
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
                int.to_string(current_year)
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
