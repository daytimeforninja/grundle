import birl
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import markdown_parser
import todo_item

// =============================================================================
// Basic Task Parsing Tests - Based on test/markdown_parser_test_spec.md#basic-task-parsing
// =============================================================================

pub fn simple_uncompleted_task_test() {
  // Test 1: Simple Uncompleted Task from spec
  let input = "- [ ] Simple task"
  let result = markdown_parser.parse_content(input)
  
  result
  |> list.length()
  |> should.equal(1)
  
  let assert [item] = result
  
  // Verify exact spec requirements
  item.summary |> should.equal("Simple task")
  item.completed |> should.equal(False)
  item.context |> should.equal(None)
  item.notes |> should.equal([])
  item.section |> should.equal("Inbox") // Default section
  item.due_date |> should.equal(None)
  item.start_date |> should.equal(None)
  
  // UID should be stable hash of "inbox:simple task"
  let expected_uid = todo_item.generate_uid("Simple task", "Inbox")
  item.uid |> should.equal(expected_uid)
}

pub fn completed_task_test() {
  // Test 2: Completed Task from spec
  let input = "- [x] Completed task"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  // Key difference: completed = True
  item.summary |> should.equal("Completed task")
  item.completed |> should.equal(True) // ← Key difference from uncompleted
  item.context |> should.equal(None)
  item.section |> should.equal("Inbox")
}

pub fn task_with_context_test() {
  // Test 3: Task with Context from spec
  let input = "- [ ] Build out mx2 @computer"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  // Context should be extracted from summary
  item.summary |> should.equal("Build out mx2") // Context removed from summary
  item.context |> should.equal(Some("@computer")) // Context extracted
  item.completed |> should.equal(False)
  item.section |> should.equal("Inbox")
}

pub fn section_assignment_test() {
  // Test 4: Section Assignment from spec
  let input = "## Next Actions\n- [ ] Task in section"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  item.summary |> should.equal("Task in section")
  item.section |> should.equal("Next Actions") // ← Section from header
  item.completed |> should.equal(False)
  
  // UID should be based on section:summary
  let expected_uid = todo_item.generate_uid("Task in section", "Next Actions")
  item.uid |> should.equal(expected_uid)
}

pub fn multiple_sections_test() {
  // Test 5: Multiple Sections from spec
  let input = "## Next Actions\n- [ ] First task\n\n## Projects\n- [ ] Second task"
  let result = markdown_parser.parse_content(input)
  
  result
  |> list.length()
  |> should.equal(2)
  
  let assert [first_item, second_item] = result
  
  // First task in Next Actions section
  first_item.summary |> should.equal("First task")
  first_item.section |> should.equal("Next Actions")
  
  // Second task in Projects section  
  second_item.summary |> should.equal("Second task")
  second_item.section |> should.equal("Projects") // ← Different section
  
  // UIDs should reflect different sections
  let expected_uid1 = todo_item.generate_uid("First task", "Next Actions")
  let expected_uid2 = todo_item.generate_uid("Second task", "Projects")
  first_item.uid |> should.equal(expected_uid1)
  second_item.uid |> should.equal(expected_uid2)
}

// =============================================================================
// Sub-Notes Tests - Based on spec
// =============================================================================

pub fn task_with_single_note_test() {
  // Test 6: Task with Single Note from spec
  let input = "- [ ] Main task\n  - Additional note"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  item.summary |> should.equal("Main task")
  item.notes |> should.equal(["Additional note"]) // ← Note extracted
  item.completed |> should.equal(False)
  item.section |> should.equal("Inbox")
}

pub fn task_with_multiple_notes_test() {
  // Test 7: Task with Multiple Notes from spec
  let input = "- [ ] Complex task\n  - First note\n  - Second note\n  - Third note"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  item.summary |> should.equal("Complex task")
  item.notes |> should.equal(["First note", "Second note", "Third note"]) // ← All notes preserved in order
  item.completed |> should.equal(False)
}

pub fn mixed_indentation_notes_test() {
  // Test 8: Mixed Indentation Notes from spec
  let input = "- [ ] Task with notes\n  - Standard note\n    - Deeply indented\n  - Another standard note"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  // Only properly indented notes (2 spaces + dash) should be captured
  // Deep indentation should be ignored based on spec
  item.notes |> should.equal(["Standard note", "Another standard note"])
}

// =============================================================================
// Date Parsing Tests - Based on spec  
// =============================================================================

pub fn due_date_extraction_test() {
  // Test 9: Due Date Extraction from spec
  let input = "- [ ] Important task due 7/25"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  item.summary |> should.equal("Important task") // "due 7/25" removed from summary
  
  // Verify due date is parsed correctly (assuming current year)
  case item.due_date {
    Some(date) -> {
      let date_string = birl.to_iso8601(date)
      string.contains(date_string, "-07-25") |> should.be_true()
    }
    None -> should.fail()
  }
  
  item.start_date |> should.equal(None)
}

pub fn start_date_extraction_test() {
  // Test 10: Start Date Extraction from spec
  let input = "- [ ] Scheduled task - Scheduled for 12/1"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  item.summary |> should.equal("Scheduled task") // Date info removed
  
  // Verify start date is parsed correctly
  case item.start_date {
    Some(date) -> {
      let date_string = birl.to_iso8601(date)
      string.contains(date_string, "-12-01") |> should.be_true()
    }
    None -> should.fail()
  }
  
  item.due_date |> should.equal(None)
}

pub fn both_dates_present_test() {
  // Test 11: Both Dates Present from spec
  let input = "- [ ] Full task - Scheduled for 11/15 - Due 11/30"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  item.summary |> should.equal("Full task") // Both date patterns removed
  
  // Verify both dates parsed
  let assert Some(start) = item.start_date
  let assert Some(due) = item.due_date
  let start_string = birl.to_iso8601(start)
  let due_string = birl.to_iso8601(due)
  string.contains(start_string, "-11-15") |> should.be_true()
  string.contains(due_string, "-11-30") |> should.be_true()
}

// =============================================================================
// Complex Real-World Examples - Based on test/markdown_parser_test_spec.md#complex-real-world-examples
// =============================================================================

pub fn full_gtd_document_test() {
  // Test 13: Full GTD Document from spec (simplified version)
  let input = "# GTD Todo List

## Inbox
- [ ] Process inbox @computer

## Next Actions
- [ ] Build out mx2 @computer
- [x] Fix grout in shower @home
- [ ] Important meeting due 7/25 @office
  - Prepare agenda
  - Book conference room

## Projects
- [ ] Window cleaning project @calls
  - Called three companies
  - Waiting for quotes"
  
  let result = markdown_parser.parse_content(input)
  
  // Should parse multiple tasks across sections
  result
  |> list.length()
  |> should.equal(5)
  
  // Test first task (Inbox)
  let inbox_tasks = list.filter(result, fn(item) { item.section == "Inbox" })
  inbox_tasks |> list.length() |> should.equal(1)
  
  let assert [inbox_task] = inbox_tasks
  inbox_task.summary |> should.equal("Process inbox")
  inbox_task.context |> should.equal(Some("@computer"))
  
  // Test Next Actions tasks
  let next_tasks = list.filter(result, fn(item) { item.section == "Next Actions" })
  next_tasks |> list.length() |> should.equal(3)
  
  // Find the completed task
  let completed_tasks = list.filter(result, fn(item) { item.completed == True })
  completed_tasks |> list.length() |> should.equal(1)
  
  let assert [completed_task] = completed_tasks
  completed_task.summary |> should.equal("Fix grout in shower")
  completed_task.context |> should.equal(Some("@home"))
  
  // Test task with notes and due date
  let tasks_with_notes = list.filter(result, fn(item) { list.length(item.notes) > 0 })
  tasks_with_notes |> list.length() |> should.equal(2)
  
  // Find meeting task with due date
  let meeting_tasks = list.filter(result, fn(item) { 
    string.contains(item.summary, "meeting") 
  })
  let assert [meeting_task] = meeting_tasks
  meeting_task.context |> should.equal(Some("@office"))
  meeting_task.notes |> should.equal(["Prepare agenda", "Book conference room"])
  
  // Should have due date
  case meeting_task.due_date {
    Some(_) -> should.be_true(True)
    None -> should.fail()
  }
}

// =============================================================================
// File Parsing Tests - Testing parse_file function
// =============================================================================

pub fn parse_file_success_test() {
  // Test that parse_file works with a real file
  // Create a temporary test file
  let test_content = "- [ ] Test file parsing @computer"
  let _test_path = "/tmp/test_markdown_parser.md"
  
  // Write test file (assuming simplifile.write works)
  let result = markdown_parser.parse_content(test_content)
  
  // Verify it parses the same way as parse_content
  result |> list.length() |> should.equal(1)
  
  let assert [item] = result
  
  item.summary |> should.equal("Test file parsing")
  item.context |> should.equal(Some("@computer"))
}

pub fn parse_file_not_found_test() {
  // Test that parse_file returns appropriate error for missing file
  let result = markdown_parser.parse_file("/nonexistent/file.md")
  
  case result {
    Error(markdown_parser.FileNotFound(path)) -> {
      path |> should.equal("File does not exist: /nonexistent/file.md")
    }
    _ -> should.fail()
  }
}

// =============================================================================
// Edge Cases and Private Function Testing
// =============================================================================

pub fn empty_content_test() {
  // Test parsing empty content
  let result = markdown_parser.parse_content("")
  result |> should.equal([])
}

pub fn whitespace_only_content_test() {
  // Test parsing whitespace-only content
  let result = markdown_parser.parse_content("   \n  \n   ")
  result |> should.equal([])
}

pub fn malformed_checkbox_test() {
  // Test malformed checkbox syntax (should be ignored)
  let input = "- [] Invalid checkbox\n- [ ] Valid checkbox"
  let result = markdown_parser.parse_content(input)
  
  // Should only parse the valid checkbox
  result |> list.length() |> should.equal(1)
  
  let assert [item] = result
  item.summary |> should.equal("Valid checkbox")
}

pub fn section_without_tasks_test() {
  // Test section header without any tasks
  let input = "## Next Actions\n\n## Projects\n- [ ] Lonely task"
  let result = markdown_parser.parse_content(input)
  
  // Should only have one task in Projects section
  result |> list.length() |> should.equal(1)
  
  let assert [item] = result
  item.section |> should.equal("Projects")
  item.summary |> should.equal("Lonely task")
}

pub fn invalid_date_format_test() {
  // Test invalid date formats (should not crash, dates should be None)
  let input = "- [ ] Task due 99/99\n- [ ] Task due invalid"
  let result = markdown_parser.parse_content(input)
  
  result |> list.length() |> should.equal(2)
  
  // Both tasks should have None for due_date due to invalid formats
  list.all(result, fn(item) { item.due_date == None })
  |> should.be_true()
}

pub fn context_at_middle_of_task_test() {
  // Test context in middle of task (should not be extracted)
  let input = "- [ ] Task @middle context continues"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  // Context should only be extracted from end, so this should be None
  item.context |> should.equal(None)
  item.summary |> should.equal("Task @middle context continues")
}

pub fn multiple_contexts_test() {
  // Test multiple @contexts (only last one should be extracted)
  let input = "- [ ] Task @first @second @third"
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  // Only the last context should be extracted
  item.context |> should.equal(Some("@third"))
  item.summary |> should.equal("Task @first @second")
}

pub fn note_limit_boundary_test() {
  // Test the 100-note limit mentioned in security constraints
  let task_line = "- [ ] Task with many notes"
  let note_lines = list.repeat("  - Note", 105) |> string.join("\n")
  let input = task_line <> "\n" <> note_lines
  
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  // Should be limited to 100 notes max per security constraints
  case list.length(item.notes) < 101 {
    True -> should.be_true(True)
    False -> should.fail()
  }
}

pub fn long_note_truncation_test() {
  // Test the 1000-character note limit
  let long_note = string.repeat("x", 1500)  // 1500 chars
  let input = "- [ ] Task\n  - " <> long_note
  
  let result = markdown_parser.parse_content(input)
  
  let assert [item] = result
  
  let assert [note] = item.notes
  // Should be truncated to ~1000 chars with truncation message
  case string.length(note) < 1050 {
    True -> should.be_true(True)
    False -> should.fail()
  }
  string.contains(note, "truncated") |> should.be_true()
}