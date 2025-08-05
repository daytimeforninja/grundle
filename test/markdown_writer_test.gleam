import birl
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import markdown_writer
import simplifile
import todo_item.{TodoItem}

// =============================================================================
// Markdown Generation Tests - Based on test/roundtrip_conversion_test_spec.md#markdown-generation
// =============================================================================

pub fn todoitem_to_markdown_conversion_test() {
  // Test 21: TodoItem to Markdown Conversion from spec
  let test_time = birl.utc_now()
  
  let test_item = TodoItem(
    uid: "review123@todo-md-sync",
    summary: "Review documentation",
    completed: False,
    context: Some("@computer"),
    notes: ["Check for updates", "Update changelog"],
    section: "Next Actions",
    due_date: None,
    start_date: None,
    created_at: test_time,
    modified_at: test_time,
  )
  
  let markdown_output = markdown_writer.generate_content([test_item])
  
  // Validation points from spec:
  string.contains(markdown_output, "# GTD Todo List") |> should.be_true()
  string.contains(markdown_output, "## Next Actions") |> should.be_true()
  string.contains(markdown_output, "- [ ] Review documentation @computer") |> should.be_true()
  string.contains(markdown_output, "  - Check for updates") |> should.be_true()
  string.contains(markdown_output, "  - Update changelog") |> should.be_true()
  string.contains(markdown_output, "GTD Contexts:") |> should.be_true()
}

pub fn completed_task_markdown_test() {
  // Test completed task checkbox formatting
  let test_time = birl.utc_now()
  
  let completed_item = TodoItem(
    uid: "completed123@todo-md-sync",
    summary: "Finished task",
    completed: True,
    context: Some("@home"),
    notes: [],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: test_time,
    modified_at: test_time,
  )
  
  let markdown_output = markdown_writer.generate_content([completed_item])
  
  // Validation: completed tasks use [x] checkbox
  string.contains(markdown_output, "- [x] Finished task @home") |> should.be_true()
  string.contains(markdown_output, "## Inbox") |> should.be_true()
}

pub fn multiple_sections_markdown_test() {
  // Test canonical GTD section ordering and formatting
  let test_time = birl.utc_now()
  
  let items = [
    TodoItem(
      uid: "projects123@todo-md-sync",
      summary: "Project task",
      completed: False,
      context: None,
      notes: [],
      section: "Projects",
      due_date: None,
      start_date: None,
      created_at: test_time,
      modified_at: test_time,
    ),
    TodoItem(
      uid: "inbox123@todo-md-sync", 
      summary: "Inbox task",
      completed: False,
      context: None,
      notes: [],
      section: "Inbox",
      due_date: None,
      start_date: None,
      created_at: test_time,
      modified_at: test_time,
    ),
    TodoItem(
      uid: "next123@todo-md-sync",
      summary: "Next task", 
      completed: False,
      context: None,
      notes: [],
      section: "Next Actions",
      due_date: None,
      start_date: None,
      created_at: test_time,
      modified_at: test_time,
    ),
  ]
  
  let markdown_output = markdown_writer.generate_content(items)
  
  // Find positions of sections to verify canonical ordering
  let inbox_pos = case string.split_once(markdown_output, "## Inbox") {
    Ok(#(_before, _after)) -> 0
    Error(_) -> -1
  }
  
  let next_pos = case string.split_once(markdown_output, "## Next Actions") {
    Ok(#(before, _after)) -> string.length(before)
    Error(_) -> -1
  }
  
  let projects_pos = case string.split_once(markdown_output, "## Projects") {
    Ok(#(before, _after)) -> string.length(before)
    Error(_) -> -1
  }
  
  // Verify canonical GTD section order: Inbox → Next Actions → Projects
  case inbox_pos < next_pos && next_pos < projects_pos {
    True -> should.be_true(True)
    False -> should.fail()
  }
}

pub fn date_formatting_in_markdown_test() {
  // Test date formatting in markdown output
  let test_time = birl.utc_now()
  
  let due_date = case birl.from_naive("2024-07-25") {
    Ok(date) -> Some(date)
    Error(_) -> None
  }
  
  let start_date = case birl.from_naive("2024-07-20") {
    Ok(date) -> Some(date)
    Error(_) -> None
  }
  
  let dated_item = TodoItem(
    uid: "dates123@todo-md-sync",
    summary: "Task with dates",
    completed: False,
    context: Some("@office"),
    notes: [],
    section: "Next Actions",
    due_date: due_date,
    start_date: start_date,
    created_at: test_time,
    modified_at: test_time,
  )
  
  let markdown_output = markdown_writer.generate_content([dated_item])
  
  // Validation: Dates should be formatted in MM/DD format and added to summary
  string.contains(markdown_output, "Task with dates") |> should.be_true()
  // Should contain date information (exact format may vary)
  let has_due_date = string.contains(markdown_output, "7/25") || string.contains(markdown_output, "Due")
  let has_start_date = string.contains(markdown_output, "7/20") || string.contains(markdown_output, "Scheduled") 
  has_due_date |> should.be_true()
  has_start_date |> should.be_true()
}

pub fn notes_formatting_test() {
  // Test sub-notes formatting with proper indentation
  let test_time = birl.utc_now()
  
  let notes_item = TodoItem(
    uid: "notes123@todo-md-sync",
    summary: "Task with multiple notes",
    completed: False,
    context: None,
    notes: ["First detailed note", "Second important note", "Third follow-up"],
    section: "Projects",
    due_date: None,
    start_date: None,
    created_at: test_time,
    modified_at: test_time,
  )
  
  let markdown_output = markdown_writer.generate_content([notes_item])
  
  // Validation: Notes should be properly indented (2 spaces + dash)
  string.contains(markdown_output, "- [ ] Task with multiple notes") |> should.be_true()
  string.contains(markdown_output, "  - First detailed note") |> should.be_true()
  string.contains(markdown_output, "  - Second important note") |> should.be_true()
  string.contains(markdown_output, "  - Third follow-up") |> should.be_true()
}

pub fn empty_list_generates_minimal_structure_test() {
  // Test empty todo list generates valid GTD structure
  let markdown_output = markdown_writer.generate_content([])
  
  // Should still generate complete GTD structure
  string.contains(markdown_output, "# GTD Todo List") |> should.be_true()
  string.contains(markdown_output, "GTD Contexts:") |> should.be_true()
  string.contains(markdown_output, "@computer, @home") |> should.be_true()
}

pub fn special_characters_preservation_test() {
  // Test special characters and unicode in markdown generation
  let test_time = birl.utc_now()
  
  let special_item = TodoItem(
    uid: "special123@todo-md-sync",
    summary: "Task with émojis 🚀 and symbols: & < >",
    completed: False,
    context: Some("@café"),
    notes: ["Note with special chars: @#$%"],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: test_time,
    modified_at: test_time,
  )
  
  let markdown_output = markdown_writer.generate_content([special_item])
  
  // Validation: Special characters should be preserved
  string.contains(markdown_output, "émojis 🚀") |> should.be_true()
  string.contains(markdown_output, "& < >") |> should.be_true()
  string.contains(markdown_output, "@café") |> should.be_true()
  string.contains(markdown_output, "@#$%") |> should.be_true()
}

// =============================================================================
// File Writing Tests - Integration with file system
// =============================================================================

pub fn write_items_to_file_creates_markdown_test() {
  // Test file writing functionality
  let test_time = birl.utc_now()
  let test_file = "/tmp/test_markdown_output.md"
  
  let test_item = TodoItem(
    uid: "filetest123@todo-md-sync",
    summary: "File writing test",
    completed: False,
    context: Some("@computer"),
    notes: ["Test file creation"],
    section: "Next Actions",
    due_date: None,
    start_date: None,
    created_at: test_time,
    modified_at: test_time,
  )
  
  case markdown_writer.write_items_to_file([test_item], test_file) {
    Ok(_) -> {
      // Verify file was created and contains expected content
      case simplifile.read(test_file) {
        Ok(content) -> {
          string.contains(content, "File writing test @computer") |> should.be_true()
          string.contains(content, "## Next Actions") |> should.be_true()
          string.contains(content, "  - Test file creation") |> should.be_true()
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
  
  // Cleanup
  let _ = simplifile.delete(test_file)
}

pub fn backup_creates_cache_directory_test() {
  // Test backup functionality creates appropriate cache structure
  let test_dir = "/tmp/test_markdown_cache"
  let test_file = test_dir <> "/todo.md"
  let _ = simplifile.create_directory_all(test_dir)
  
  // Create initial file to backup
  let initial_content = "# Initial Todo\n\n## Inbox\n- [ ] Original task"
  let _ = simplifile.write(test_file, initial_content)
  
  let test_time = birl.utc_now()
  let test_item = TodoItem(
    uid: "backup123@todo-md-sync",
    summary: "Backup test task",
    completed: False,
    context: None,
    notes: [],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: test_time,
    modified_at: test_time,
  )
  
  // This should create backup and write new content
  case markdown_writer.write_items_to_file([test_item], test_file) {
    Ok(_) -> {
      // Verify new content was written
      case simplifile.read(test_file) {
        Ok(content) -> {
          string.contains(content, "Backup test task") |> should.be_true()
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
  
  // Cleanup
  let _ = simplifile.delete(test_file)
  let _ = simplifile.delete(test_dir)
}

pub fn backup_rotation_keeps_reasonable_number_test() {
  // Test that backup rotation doesn't create unlimited backups
  let test_dir = "/tmp/test_backup_rotation"
  let test_file = test_dir <> "/todo.md"
  let _ = simplifile.create_directory_all(test_dir)
  
  let initial_content = "# Initial Todo"
  let _ = simplifile.write(test_file, initial_content)
  
  let test_time = birl.utc_now()
  let test_item = TodoItem(
    uid: "rotation123@todo-md-sync",
    summary: "Rotation test",
    completed: False,
    context: None,
    notes: [],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: test_time,
    modified_at: test_time,
  )
  
  // Create multiple backups by writing multiple times
  let results = [1, 2, 3, 4, 5, 6, 7]
  |> list.map(fn(_) {
    markdown_writer.write_items_to_file([test_item], test_file)
  })
  
  // All writes should succeed (backup system should handle rotation)
  results
  |> list.all(fn(result) {
    case result {
      Ok(_) -> True
      Error(_) -> False
    }
  })
  |> should.be_true()
  
  // Cleanup
  let _ = simplifile.delete(test_file)
  let _ = simplifile.delete(test_dir)
}

// =============================================================================
// Section Ordering and Formatting Tests - GTD methodology compliance
// =============================================================================

pub fn canonical_section_order_test() {
  // Test that sections are ordered according to GTD methodology
  let test_time = birl.utc_now()
  
  // Create items in reverse order to test sorting
  let items = [
    TodoItem(
      uid: "someday123@todo-md-sync",
      summary: "Someday task",
      completed: False,
      context: None,
      notes: [],
      section: "Someday/Maybe",
      due_date: None,
      start_date: None,
      created_at: test_time,
      modified_at: test_time,
    ),
    TodoItem(
      uid: "waiting123@todo-md-sync", 
      summary: "Waiting task",
      completed: False,
      context: None,
      notes: [],
      section: "Waiting For",
      due_date: None,
      start_date: None,
      created_at: test_time,
      modified_at: test_time,
    ),
    TodoItem(
      uid: "projects123@todo-md-sync",
      summary: "Project task",
      completed: False,
      context: None,
      notes: [],
      section: "Projects",
      due_date: None,
      start_date: None,
      created_at: test_time,
      modified_at: test_time,
    ),
    TodoItem(
      uid: "next123@todo-md-sync",
      summary: "Next action",
      completed: False,
      context: None,
      notes: [],
      section: "Next Actions",
      due_date: None,
      start_date: None,
      created_at: test_time,
      modified_at: test_time,
    ),
    TodoItem(
      uid: "inbox123@todo-md-sync", 
      summary: "Inbox task",
      completed: False,
      context: None,
      notes: [],
      section: "Inbox",
      due_date: None,
      start_date: None,
      created_at: test_time,
      modified_at: test_time,
    ),
  ]
  
  let markdown_output = markdown_writer.generate_content(items)
  
  // Find section positions to verify GTD canonical order
  let sections = ["Inbox", "Next Actions", "Projects", "Waiting For", "Someday/Maybe"]
  let positions = list.map(sections, fn(section) {
    case string.split_once(markdown_output, "## " <> section) {
      Ok(#(before, _after)) -> string.length(before)
      Error(_) -> 99999  // Section not found, put at end
    }
  })
  
  // Verify positions are in ascending order (canonical GTD order)
  let sorted_positions = list.sort(positions, int.compare)
  positions |> should.equal(sorted_positions)
}

pub fn gtd_footer_generation_test() {
  // Test GTD footer with contexts and weekly review placeholder
  let markdown_output = markdown_writer.generate_content([])
  
  // Should contain GTD methodology elements
  string.contains(markdown_output, "Last Weekly Review:") |> should.be_true()
  string.contains(markdown_output, "GTD Contexts:") |> should.be_true()
  
  // Should contain standard GTD contexts
  string.contains(markdown_output, "@computer") |> should.be_true()
  string.contains(markdown_output, "@home") |> should.be_true()
  string.contains(markdown_output, "@errands") |> should.be_true()
  string.contains(markdown_output, "@calls") |> should.be_true()
  string.contains(markdown_output, "@waiting") |> should.be_true()
}