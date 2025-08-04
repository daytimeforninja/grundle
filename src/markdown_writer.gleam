// MarkdownWriter: List(TodoItem) → GTD Markdown
// ===============================================
//
// Generate GTD-style todo.md content from TodoItem list.
// Reconstructs original markdown format with canonical ordering.

import birl.{type Time}
import envoy
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import todo_item.{type TodoItem}

pub type WriteError {
  WriteFailure(String, String)
}

/// Canonical GTD section order for consistent output
const section_order = [
  "Inbox", "Next Actions", "Projects", "Waiting For", "Someday/Maybe",
  "Completed",
]

/// Write TodoItems to markdown file with automatic backup
pub fn write_items_to_file(
  items: List(TodoItem),
  path: String,
) -> Result(Nil, WriteError) {
  // Create backup if file exists
  case backup_existing_file(path) {
    Error(err) -> Error(err)
    Ok(_) -> {
      let content = generate_content(items)
      case simplifile.write(path, content) {
        Ok(_) -> Ok(Nil)
        Error(_) -> Error(WriteFailure(path, "Failed to write markdown file"))
      }
    }
  }
}

/// Generate markdown content string from TodoItem list
pub fn generate_content(items: List(TodoItem)) -> String {
  let sections_dict = group_items_by_section(items)
  let header = "# GTD Todo List\n\n"
  let sections_content = generate_sections(sections_dict)
  let footer = generate_footer()

  header <> sections_content <> footer
}

/// Group TodoItems by section
fn group_items_by_section(items: List(TodoItem)) -> Dict(String, List(TodoItem)) {
  list.fold(items, dict.new(), fn(acc, item) {
    dict.upsert(acc, item.section, fn(existing) {
      case existing {
        Some(items_list) -> [item, ..items_list]
        None -> [item]
      }
    })
  })
}

/// Generate sections content in canonical order
fn generate_sections(sections_dict: Dict(String, List(TodoItem))) -> String {
  // First, generate canonical sections
  let canonical_sections =
    section_order
    |> list.map(fn(section) {
      case dict.get(sections_dict, section) {
        Ok(items) -> format_section(section, items)
        Error(_) -> ""
      }
    })
    |> list.filter(fn(content) { content != "" })

  // Then, add any additional sections not in canonical order
  let all_sections = dict.keys(sections_dict)
  let extra_sections =
    list.filter(all_sections, fn(section) {
      !list.contains(section_order, section)
    })

  let extra_content =
    extra_sections
    |> list.map(fn(section) {
      case dict.get(sections_dict, section) {
        Ok(items) -> format_section(section, items)
        Error(_) -> ""
      }
    })
    |> list.filter(fn(content) { content != "" })

  list.append(canonical_sections, extra_content)
  |> string.join("\n")
}

/// Format a single section with its items
fn format_section(section: String, items: List(TodoItem)) -> String {
  let header = "## " <> section <> "\n"
  let formatted_items =
    items
    |> list.reverse()
    // Reverse since we prepended during grouping
    |> list.map(format_item)
    |> string.join("\n")

  header <> formatted_items <> "\n\n"
}

/// Format single TodoItem as markdown lines
fn format_item(item: TodoItem) -> String {
  let checkbox = case item.completed {
    True -> "[x]"
    False -> "[ ]"
  }

  let summary_with_dates =
    add_dates_to_summary(item.summary, item.due_date, item.start_date)

  let summary_with_context = case item.context {
    Some(context) -> summary_with_dates <> " " <> context
    None -> summary_with_dates
  }

  let main_line = "- " <> checkbox <> " " <> summary_with_context

  case item.notes {
    [] -> main_line
    notes -> {
      let note_lines =
        notes
        |> list.map(fn(note) { "  - " <> note })
        |> string.join("\n")
      main_line <> "\n" <> note_lines
    }
  }
}

/// Add date information to summary
fn add_dates_to_summary(
  summary: String,
  due_date: Option(Time),
  start_date: Option(Time),
) -> String {
  let with_due = case due_date {
    Some(date) -> summary <> " - Due " <> format_date_for_markdown(date)
    None -> summary
  }

  case start_date {
    Some(date) ->
      with_due <> " - Scheduled for " <> format_date_for_markdown(date)
    None -> with_due
  }
}

/// Format Time as MM/DD for markdown
fn format_date_for_markdown(time: Time) -> String {
  // Convert to ISO8601 and extract date parts
  let iso_date = birl.to_iso8601(time)
  case string.split_once(iso_date, "T") {
    Ok(#(date_part, _)) -> {
      case string.split(date_part, "-") {
        [_year, month_str, day_str] -> {
          // Remove leading zeros and format as MM/DD
          let month = case int.parse(month_str) {
            Ok(m) -> int.to_string(m)
            Error(_) -> month_str
          }
          let day = case int.parse(day_str) {
            Ok(d) -> int.to_string(d)
            Error(_) -> day_str
          }
          month <> "/" <> day
        }
        _ -> "1/1"
        // fallback
      }
    }
    Error(_) -> "1/1"
    // fallback
  }
}

/// Create timestamped backup of existing file in ~/.cache/grundle
fn backup_existing_file(path: String) -> Result(Nil, WriteError) {
  case simplifile.is_file(path) {
    Ok(True) -> {
      // Ensure cache directory exists
      case ensure_cache_directory() {
        Error(err) -> Error(err)
        Ok(cache_dir) -> {
          // Clean up old backups first to maintain 5-backup limit
          case cleanup_old_backups(path, cache_dir) {
            Error(err) -> Error(err)
            Ok(_) -> {
              // Create new backup with timestamp and safe filename
              let timestamp =
                birl.utc_now()
                |> birl.to_iso8601()
                |> string.replace(":", "-")
                |> string.replace(".", "-")
              let safe_filename = sanitize_filename_for_backup(path)
              let backup_path =
                cache_dir <> "/" <> safe_filename <> ".backup." <> timestamp
              case simplifile.copy_file(at: path, to: backup_path) {
                Ok(_) -> Ok(Nil)
                Error(_) ->
                  Error(WriteFailure(backup_path, "Failed to create backup"))
              }
            }
          }
        }
      }
    }
    _ -> Ok(Nil)
    // File doesn't exist or error checking, skip backup
  }
}

/// Keep only the 5 most recent backups in cache directory
fn cleanup_old_backups(
  original_path: String,
  cache_dir: String,
) -> Result(Nil, WriteError) {
  case simplifile.read_directory(cache_dir) {
    Ok(files) -> {
      // Create safe filename pattern to match backups for this file
      let safe_filename =
        original_path
        |> string.replace("/", "_")
        |> string.replace("~", "home")
      let backup_pattern = safe_filename <> ".backup."

      let backup_files =
        files
        |> list.filter(fn(file) { string.starts_with(file, backup_pattern) })
        |> list.sort(string.compare)
        |> list.reverse()
      // Most recent first

      // Remove oldest backups if we have more than 4 (keeping 5 total)
      case list.drop(backup_files, 4) {
        [] -> Ok(Nil)
        // 4 or fewer backups, nothing to clean
        old_backups -> {
          old_backups
          |> list.try_each(fn(backup_file) {
            let backup_path = cache_dir <> "/" <> backup_file
            case simplifile.delete(backup_path) {
              Ok(_) -> Ok(Nil)
              Error(_) ->
                Error(WriteFailure(backup_path, "Failed to delete old backup"))
            }
          })
          |> result.replace(Nil)
        }
      }
    }
    Error(_) -> Ok(Nil)
    // Cache directory doesn't exist, nothing to clean
  }
}

/// Ensure ~/.cache/grundle directory exists and return its path
fn ensure_cache_directory() -> Result(String, WriteError) {
  // Try to get HOME environment variable, fallback to current directory
  let home_dir = case envoy.get("HOME") {
    Ok(home) -> home
    Error(_) -> "."
  }

  let cache_dir = home_dir <> "/.cache/grundle"

  // Create cache directory if it doesn't exist
  case simplifile.create_directory_all(cache_dir) {
    Ok(_) -> Ok(cache_dir)
    Error(_) ->
      Error(WriteFailure(cache_dir, "Failed to create cache directory"))
  }
}

/// Sanitize filename for backup to prevent path traversal
fn sanitize_filename_for_backup(path: String) -> String {
  path
  // Remove directory separators and path components
  |> string.replace("/", "_")
  |> string.replace("\\", "_")
  |> string.replace("..", "dotdot")
  |> string.replace("~", "home")
  // Remove other potentially dangerous characters
  |> string.replace(":", "_")
  |> string.replace("*", "_")
  |> string.replace("?", "_")
  |> string.replace("\"", "_")
  |> string.replace("<", "_")
  |> string.replace(">", "_")
  |> string.replace("|", "_")
  // Ensure filename isn't empty and doesn't start with dangerous patterns
  |> fn(filename) {
    case filename {
      "" -> "unknown_file"
      filename -> {
        case string.starts_with(filename, ".") {
          True -> "hidden_" <> filename
          False -> filename
        }
      }
    }
  }
  // Truncate if too long to prevent filesystem issues
  |> string.slice(0, 200)
}

/// Generate footer with GTD context reference
fn generate_footer() -> String {
  "---\n*Last Weekly Review: [To be filled]*\n*GTD Contexts: @computer, @home, @errands, @calls, @anywhere, @waiting, @shopping, @yurt*\n"
}
