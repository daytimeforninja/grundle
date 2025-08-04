// grundle: Main Module
// ====================
// 
// This is the main entry point for grundle.
// It orchestrates the conversion between GTD-style markdown and VTODO format.

import argv
import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/string
import markdown_parser
import markdown_writer
import simplifile
import vtodo_generator
import vtodo_parser

pub fn main() {
  case argv.load().arguments {
    [] -> {
      case envoy.get("GRUNDLE_TODO"), envoy.get("GRUNDLE_VTODO") {
        Ok(todo_path), Ok(ics_dir) -> {
          bidirectional_sync(todo_path, ics_dir)
        }
        _, _ -> {
          io.println_error(
            "Error: GRUNDLE_TODO and GRUNDLE_VTODO environment variables must be set",
          )
          print_usage()
        }
      }
    }
    ["--help"] -> print_usage()
    ["-h"] -> print_usage()

    // Convert todo.md to ICS files
    [input_file, "--to-ics", output_dir] -> {
      convert_to_ics(input_file, output_dir)
    }

    // Convert ICS files to todo.md
    ["--from-ics", input_dir, output_file] -> {
      convert_from_ics(input_dir, output_file)
    }

    _ -> {
      io.println_error("Error: Invalid arguments")
      print_usage()
    }
  }
}

fn convert_to_ics(input_file: String, output_dir: String) -> Nil {
  io.println("Converting " <> input_file <> " → ICS files in " <> output_dir)

  case markdown_parser.parse_file(input_file) {
    Ok(todo_items) -> {
      io.println(
        "✓ Parsed " <> int.to_string(list.length(todo_items)) <> " todo items",
      )

      case vtodo_generator.write_ics_files(todo_items, output_dir) {
        Ok(_) -> {
          io.println("✓ Successfully wrote ICS files to " <> output_dir)
        }
        Error(vtodo_generator.WriteFailure(path, reason)) -> {
          io.println_error("✗ Failed to write " <> path <> ": " <> reason)
        }
        Error(vtodo_generator.DirectoryNotFound(dir)) -> {
          io.println_error("✗ Directory not found: " <> dir)
        }
        Error(vtodo_generator.InvalidItem(reason)) -> {
          io.println_error("✗ Invalid todo item: " <> reason)
        }
      }
    }
    Error(_) -> {
      io.println_error("✗ Failed to parse markdown file")
    }
  }
}

fn convert_from_ics(input_dir: String, output_file: String) -> Nil {
  io.println("Converting ICS files in " <> input_dir <> " → " <> output_file)

  case vtodo_parser.parse_ics_directory(input_dir) {
    Ok(todo_items) -> {
      io.println(
        "✓ Parsed " <> int.to_string(list.length(todo_items)) <> " todo items",
      )

      case markdown_writer.write_items_to_file(todo_items, output_file) {
        Ok(_) -> {
          io.println("✓ Successfully wrote markdown to " <> output_file)
        }
        Error(markdown_writer.WriteFailure(path, reason)) -> {
          io.println_error("✗ Failed to write " <> path <> ": " <> reason)
        }
      }
    }
    Error(err) -> {
      io.println_error("✗ Failed to parse ICS files")
      case err {
        vtodo_parser.FileNotFound(path) ->
          io.println_error("  File not found: " <> path)
        vtodo_parser.InvalidFormat(msg) ->
          io.println_error("  Invalid format: " <> msg)
        vtodo_parser.MissingRequiredField(field) ->
          io.println_error("  Missing field: " <> field)
        vtodo_parser.DateParseError(msg) ->
          io.println_error("  Date parse error: " <> msg)
      }
    }
  }
}

fn bidirectional_sync(todo_file: String, ics_dir: String) -> Nil {
  case get_sync_direction(todo_file, ics_dir) {
    ToIcs -> {
      io.println(
        "Syncing " <> todo_file <> " → " <> ics_dir <> " (markdown newer)",
      )
      convert_to_ics(todo_file, ics_dir)
    }
    FromIcs -> {
      io.println(
        "Syncing " <> ics_dir <> " → " <> todo_file <> " (ics files newer)",
      )
      convert_from_ics(ics_dir, todo_file)
    }
    NoSync -> {
      io.println("No sync needed - files are up to date")
    }
  }
}

type SyncDirection {
  ToIcs
  FromIcs
  NoSync
}

fn get_sync_direction(todo_file: String, ics_dir: String) -> SyncDirection {
  case simplifile.file_info(todo_file) {
    Ok(todo_info) -> {
      case get_newest_ics_mtime(ics_dir) {
        Ok(ics_mtime) -> {
          case int.compare(todo_info.mtime_seconds, ics_mtime) {
            order.Gt -> ToIcs
            order.Lt -> FromIcs
            order.Eq -> NoSync
            // Equal timestamps - no sync needed
          }
        }
        Error(_) -> ToIcs
      }
    }
    Error(_) -> {
      case get_newest_ics_mtime(ics_dir) {
        Ok(_) -> FromIcs
        Error(_) -> NoSync
      }
    }
  }
}

fn get_newest_ics_mtime(ics_dir: String) -> Result(Int, simplifile.FileError) {
  case simplifile.read_directory(ics_dir) {
    Ok(files) -> {
      files
      |> list.filter(fn(file) { file |> string.ends_with(".ics") })
      |> list.map(fn(file) { ics_dir <> "/" <> file })
      |> list.fold(Ok(0), fn(acc, file_path) {
        case acc {
          Ok(max_mtime) -> {
            case simplifile.file_info(file_path) {
              Ok(info) -> Ok(int.max(max_mtime, info.mtime_seconds))
              Error(err) -> Error(err)
            }
          }
          Error(err) -> Error(err)
        }
      })
    }
    Error(err) -> Error(err)
  }
}

fn print_usage() -> Nil {
  io.println(
    "
grundle

Convert between todo.md format and iCalendar VTODO format for CalDAV sync.

Usage:
  grundle                                    # Bidirectional sync (newest wins)
  grundle <todo.md> --to-ics <output_dir>   # Convert markdown to ICS
  grundle --from-ics <input_dir> <output.md> # Convert ICS to markdown

Environment variables (required for bidirectional sync):
  GRUNDLE_TODO    Path to todo.md file
  GRUNDLE_VTODO   Path to vdirsyncer calendar directory

Examples:
  # Set up environment and run bidirectional sync
  export GRUNDLE_TODO=~/Documents/todo.md
  export GRUNDLE_VTODO=~/.calendars/tasks
  grundle
  
  # Manual conversions (no env vars needed)
  grundle todo.md --to-ics ~/.calendars/tasks/
  grundle --from-ics ~/.calendars/tasks/ todo.md

Workflow with vdirsyncer:
  1. grundle                    # Sync local changes to ICS
  2. vdirsyncer sync           # Sync with CalDAV server  
  3. grundle                    # Sync server changes back to markdown

The converter preserves:
  - Task completion status
  - GTD contexts (@home, @computer, etc.)  
  - Due dates and scheduled dates
  - Sub-notes under tasks
  - Section organization (Inbox, Next Actions, etc.)
",
  )
}
