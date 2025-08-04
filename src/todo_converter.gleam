// Todo.md ↔ VTODO Converter: Main Module
// ========================================
// 
// This is the main entry point for the todo converter application.
// It orchestrates the conversion between GTD-style markdown and VTODO format.

import gleam/io
import argv

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
  io.println("✓ Feature not yet implemented - coming soon!")
  // TODO: Implement markdown parsing and VTODO generation
}

fn convert_from_ics(input_dir: String, output_file: String) -> Nil {
  io.println("Converting ICS files in " <> input_dir <> " → " <> output_file)
  io.println("✓ Feature not yet implemented - coming soon!")
  // TODO: Implement VTODO parsing and markdown generation  
}

fn print_usage() -> Nil {
  io.println("
Todo.md ↔ VTODO Converter

Convert between todo.md format and iCalendar VTODO format for CalDAV sync.

Usage:
  todo-converter <todo.md> --to-ics <output_dir>
  todo-converter --from-ics <input_dir> <output.md>

Examples:
  # Convert todo.md to ICS files for vdirsyncer
  todo-converter todo.md --to-ics ~/.calendars/tasks/
  
  # Convert ICS files back to todo.md after CalDAV sync
  todo-converter --from-ics ~/.calendars/tasks/ todo.md

Workflow with vdirsyncer:
  1. todo-converter todo.md --to-ics ~/.calendars/tasks/
  2. vdirsyncer sync
  3. todo-converter --from-ics ~/.calendars/tasks/ todo.md

The converter preserves:
  - Task completion status
  - GTD contexts (@home, @computer, etc.)  
  - Due dates and scheduled dates
  - Sub-notes under tasks
  - Section organization (Inbox, Next Actions, etc.)
")
}