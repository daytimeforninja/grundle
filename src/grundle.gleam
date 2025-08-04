// grundle: Main Module
// ====================
// 
// This is the main entry point for grundle.
// It orchestrates the conversion between GTD-style markdown and VTODO format.

import gleam/io
import gleam/list
import gleam/int
import argv
import markdown_parser
import vtodo_generator
import vtodo_parser
import markdown_writer

pub fn main() {
  case argv.load().arguments {
    [] -> print_usage()
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
      io.println("✓ Parsed " <> int.to_string(list.length(todo_items)) <> " todo items")
      
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
      io.println("✓ Parsed " <> int.to_string(list.length(todo_items)) <> " todo items")
      
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
        vtodo_parser.FileNotFound(path) -> io.println_error("  File not found: " <> path)
        vtodo_parser.InvalidFormat(msg) -> io.println_error("  Invalid format: " <> msg)
        vtodo_parser.MissingRequiredField(field) -> io.println_error("  Missing field: " <> field)
        vtodo_parser.DateParseError(msg) -> io.println_error("  Date parse error: " <> msg)
      }
    }
  }
}

fn print_usage() -> Nil {
  io.println("
grundle

Convert between todo.md format and iCalendar VTODO format for CalDAV sync.

Usage:
  grundle <todo.md> --to-ics <output_dir>
  grundle --from-ics <input_dir> <output.md>

Examples:
  # Convert todo.md to ICS files for vdirsyncer
  grundle todo.md --to-ics ~/.calendars/tasks/
  
  # Convert ICS files back to todo.md after CalDAV sync
  grundle --from-ics ~/.calendars/tasks/ todo.md

Workflow with vdirsyncer:
  1. grundle todo.md --to-ics ~/.calendars/tasks/
  2. vdirsyncer sync
  3. grundle --from-ics ~/.calendars/tasks/ todo.md

The converter preserves:
  - Task completion status
  - GTD contexts (@home, @computer, etc.)  
  - Due dates and scheduled dates
  - Sub-notes under tasks
  - Section organization (Inbox, Next Actions, etc.)
")
}