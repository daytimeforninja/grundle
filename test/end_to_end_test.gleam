import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import markdown_parser
import markdown_writer
import simplifile
import todo_item
import vtodo_generator
import vtodo_parser

// =============================================================================
// Complete Roundtrip Tests - Based on test/roundtrip_conversion_test_spec.md
// =============================================================================

pub fn simple_task_roundtrip_test() {
  // Test 1: Simple Task Roundtrip from spec
  let input_markdown = "- [ ] Simple task"
  
  // Step 1: Markdown → TodoItem
  let todo_items = markdown_parser.parse_content(input_markdown)
  todo_items |> list.length() |> should.equal(1)
  let assert [original_item] = todo_items
  
  // Step 2: TodoItem → VTODO
  let ics_content = vtodo_generator.item_to_vtodo(original_item)
  
  // Step 3: VTODO → TodoItem  
  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(parsed_item) -> {
      // Step 4: TodoItem → Markdown
      let reconstructed_markdown = markdown_writer.generate_content([parsed_item])
      
      // Validation: Essential semantic properties preserved
      parsed_item.summary |> should.equal(original_item.summary)
      parsed_item.completed |> should.equal(original_item.completed)
      parsed_item.context |> should.equal(original_item.context)
      parsed_item.section |> should.equal(original_item.section)
      
      // UID should be stable across roundtrip
      parsed_item.uid |> should.equal(original_item.uid)
      
      // Final markdown should contain the task
      string.contains(reconstructed_markdown, "Simple task") |> should.be_true()
      string.contains(reconstructed_markdown, "- [ ]") |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

pub fn completed_task_roundtrip_test() {
  // Test 2: Completed Task Roundtrip from spec
  let input_markdown = "- [x] Completed task"
  
  let todo_items = markdown_parser.parse_content(input_markdown)
  let assert [original_item] = todo_items
  
  // Full roundtrip
  let ics_content = vtodo_generator.item_to_vtodo(original_item)
  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(parsed_item) -> {
      // Key validation: completion status preserved
      parsed_item.completed |> should.equal(True)
      original_item.completed |> should.equal(True)
      
      let reconstructed = markdown_writer.generate_content([parsed_item])
      string.contains(reconstructed, "- [x]") |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

pub fn task_with_context_roundtrip_test() {
  // Test 3: Task with Context Roundtrip from spec
  let input_markdown = "- [ ] Build server @computer"
  
  let todo_items = markdown_parser.parse_content(input_markdown)
  let assert [original_item] = todo_items
  
  let ics_content = vtodo_generator.item_to_vtodo(original_item)
  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(parsed_item) -> {
      // Context should roundtrip through LOCATION field
      parsed_item.context |> should.equal(Some("@computer"))
      parsed_item.summary |> should.equal("Build server")
      
      let reconstructed = markdown_writer.generate_content([parsed_item])
      string.contains(reconstructed, "Build server @computer") |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

pub fn multiple_sections_roundtrip_test() {
  // Test 4: Multiple Sections Roundtrip from spec
  let input_markdown = "## Next Actions
- [ ] First task @home

## Projects
- [ ] Second task @computer

## Waiting For
- [ ] Third task @waiting"

  let todo_items = markdown_parser.parse_content(input_markdown)
  todo_items |> list.length() |> should.equal(3)
  
  // Convert all to ICS and back
  let roundtrip_items = 
    todo_items
    |> list.map(fn(item) {
      let ics = vtodo_generator.item_to_vtodo(item)
      let assert Ok(parsed) = vtodo_parser.parse_ics_content(ics)
      parsed
    })
  
  // All sections should be preserved
  let sections = list.map(roundtrip_items, fn(item) { item.section })
  list.contains(sections, "Next Actions") |> should.be_true()
  list.contains(sections, "Projects") |> should.be_true()
  list.contains(sections, "Waiting For") |> should.be_true()
  
  // All contexts should be preserved
  let contexts = list.filter_map(roundtrip_items, fn(item) { 
    case item.context {
      Some(ctx) -> Ok(ctx)
      None -> Error(Nil)
    }
  })
  list.contains(contexts, "@home") |> should.be_true()
  list.contains(contexts, "@computer") |> should.be_true()
  list.contains(contexts, "@waiting") |> should.be_true()
}

pub fn due_date_roundtrip_test() {
  // Test 6: Due Date Roundtrip from spec
  let input_markdown = "- [ ] Important deadline due 7/25"
  
  let todo_items = markdown_parser.parse_content(input_markdown)
  let assert [original_item] = todo_items
  
  let ics_content = vtodo_generator.item_to_vtodo(original_item)
  // Verify DUE field in VTODO
  string.contains(ics_content, "DUE;VALUE=DATE:") |> should.be_true()
  
  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(parsed_item) -> {
      // Due date should be preserved
      parsed_item.due_date |> should.not_equal(None)
      
      let reconstructed = markdown_writer.generate_content([parsed_item])
      // Should contain due date in some format
      let has_date = string.contains(reconstructed, "7/25")
      let has_due = string.contains(reconstructed, "Due")
      case has_date || has_due {
        True -> should.be_true(True)  
        False -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

pub fn task_with_notes_roundtrip_test() {
  // Test 9: Task with Notes Roundtrip from spec
  let input_markdown = "- [ ] Complex task
  - First note
  - Second note
  - Third note"
  
  let todo_items = markdown_parser.parse_content(input_markdown)
  let assert [original_item] = todo_items
  
  let ics_content = vtodo_generator.item_to_vtodo(original_item)
  // Verify DESCRIPTION field exists
  string.contains(ics_content, "DESCRIPTION:") |> should.be_true()
  
  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(parsed_item) -> {
      // All notes should be preserved in order
      parsed_item.notes |> should.equal(["First note", "Second note", "Third note"])
      
      let reconstructed = markdown_writer.generate_content([parsed_item])
      string.contains(reconstructed, "First note") |> should.be_true()
      string.contains(reconstructed, "Second note") |> should.be_true()
      string.contains(reconstructed, "Third note") |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

// =============================================================================
// Complex Document Roundtrip Tests
// =============================================================================

pub fn full_gtd_document_roundtrip_test() {
  // Test 11: Full GTD Document Roundtrip from spec
  let complex_markdown = "# GTD Todo List

## Inbox
- [ ] Process later @computer

## Next Actions
- [ ] Build mx2 server @computer
- [x] Fix bathroom grout @home
- [ ] Meeting prep due 7/25 @office
  - Prepare agenda
  - Book room

## Projects
- [ ] Website redesign @computer
  - Research frameworks
  - Create mockups

## Waiting For
- [ ] Lawyer response @waiting

## Someday/Maybe
- [ ] Learn French @anywhere"

  let original_items = markdown_parser.parse_content(complex_markdown)
  original_items |> list.length() |> should.equal(7)
  
  // Complete roundtrip for all items
  let roundtrip_items = 
    original_items
    |> list.map(fn(item) {
      let ics = vtodo_generator.item_to_vtodo(item)  
      let assert Ok(parsed) = vtodo_parser.parse_ics_content(ics)
      parsed
    })
  
  // Comprehensive validation from spec:
  roundtrip_items |> list.length() |> should.equal(7)
  
  // Check completion status preservation  
  let completed_tasks = list.filter(roundtrip_items, fn(item) { item.completed })
  completed_tasks |> list.length() |> should.equal(1)
  let assert [completed_task] = completed_tasks
  completed_task.summary |> should.equal("Fix bathroom grout")
  
  // Check contexts maintained
  let contexts = list.filter_map(roundtrip_items, fn(item) { 
    case item.context {
      Some(ctx) -> Ok(ctx)
      None -> Error(Nil)
    }
  })
  list.contains(contexts, "@computer") |> should.be_true()
  list.contains(contexts, "@home") |> should.be_true()
  list.contains(contexts, "@office") |> should.be_true()
  list.contains(contexts, "@waiting") |> should.be_true()
  list.contains(contexts, "@anywhere") |> should.be_true()
  
  // Check sub-notes preservation
  let items_with_notes = list.filter(roundtrip_items, fn(item) { 
    list.length(item.notes) > 0 
  })
  items_with_notes |> list.length() |> should.equal(2)
  
  // Check sections maintained
  let sections = list.map(roundtrip_items, fn(item) { item.section })
  list.contains(sections, "Inbox") |> should.be_true()
  list.contains(sections, "Next Actions") |> should.be_true()
  list.contains(sections, "Projects") |> should.be_true()
  list.contains(sections, "Waiting For") |> should.be_true()
  list.contains(sections, "Someday/Maybe") |> should.be_true()
}

pub fn unicode_and_special_characters_roundtrip_test() {
  // Test 12: Unicode and Special Characters Roundtrip from spec
  let unicode_markdown = "- [ ] Task with émojis 🚀 and chars: @café
- [ ] Task, with; special & symbols @computer"
  
  let original_items = markdown_parser.parse_content(unicode_markdown)
  original_items |> list.length() |> should.equal(2)
  
  let roundtrip_items =
    original_items
    |> list.map(fn(item) {
      let ics = vtodo_generator.item_to_vtodo(item)
      let assert Ok(parsed) = vtodo_parser.parse_ics_content(ics)
      parsed
    })
  
  // Unicode and emoji preservation validation
  let summaries = list.map(roundtrip_items, fn(item) { item.summary })
  list.any(summaries, fn(s) { string.contains(s, "émojis 🚀") }) |> should.be_true()
  list.any(summaries, fn(s) { string.contains(s, "special & symbols") }) |> should.be_true()
  
  // Special context preservation (@café)
  let contexts = list.filter_map(roundtrip_items, fn(item) { 
    case item.context {
      Some(ctx) -> Ok(ctx)
      None -> Error(Nil)
    }
  })
  list.contains(contexts, "@café") |> should.be_true()
  list.contains(contexts, "@computer") |> should.be_true()
}

// =============================================================================
// UID Stability Tests
// =============================================================================

pub fn uid_stability_across_roundtrips_test() {
  // Test 15: UID Stability from spec
  let input_markdown = "- [ ] Stable UID test @home"
  
  let original_items = markdown_parser.parse_content(input_markdown)
  let assert [original_item] = original_items
  let original_uid = original_item.uid
  
  // Perform multiple roundtrips
  let after_roundtrip_1 = {
    let ics = vtodo_generator.item_to_vtodo(original_item)
    let assert Ok(parsed) = vtodo_parser.parse_ics_content(ics)
    parsed
  }
  
  let after_roundtrip_2 = {
    let ics = vtodo_generator.item_to_vtodo(after_roundtrip_1)
    let assert Ok(parsed) = vtodo_parser.parse_ics_content(ics)
    parsed
  }
  
  let after_roundtrip_3 = {
    let ics = vtodo_generator.item_to_vtodo(after_roundtrip_2)
    let assert Ok(parsed) = vtodo_parser.parse_ics_content(ics)
    parsed
  }
  
  // UID should remain identical across all roundtrips
  after_roundtrip_1.uid |> should.equal(original_uid)
  after_roundtrip_2.uid |> should.equal(original_uid)
  after_roundtrip_3.uid |> should.equal(original_uid)
}

// =============================================================================
// File System Integration Tests - Based on test/roundtrip_conversion_test_spec.md#integration-tests
// =============================================================================

pub fn file_system_roundtrip_test() {
  // Test 18: vdirsyncer Workflow Simulation from spec
  let test_markdown = "# GTD Todo List

## Next Actions
- [ ] Test file system roundtrip @computer
- [ ] Verify CalDAV compatibility @home

## Projects  
- [ ] Complete integration testing @computer
  - Write comprehensive tests
  - Validate all edge cases"

  // Step 1: Start with todo.md
  let test_todo_file = "/tmp/test_roundtrip.md"
  let test_ics_dir = "/tmp/test_ics_roundtrip"
  let output_markdown_file = "/tmp/test_output_roundtrip.md"
  
  let _ = simplifile.write(test_todo_file, test_markdown)
  let _ = simplifile.create_directory_all(test_ics_dir)
  
  // Step 2: Convert to .ics files in directory
  case markdown_parser.parse_file(test_todo_file) {
    Ok(todo_items) -> {
      case vtodo_generator.write_ics_files(todo_items, test_ics_dir) {
        Ok(_) -> {
          // Step 3: Verify .ics files were created
          case simplifile.read_directory(test_ics_dir) {
            Ok(files) -> {
              let ics_files = list.filter(files, fn(f) { string.ends_with(f, ".ics") })
              ics_files |> list.length() |> should.equal(3) // 3 tasks
              
              // Step 4: Convert back to todo.md
              case vtodo_parser.parse_ics_directory(test_ics_dir) {
                Ok(parsed_items) -> {
                  case markdown_writer.write_items_to_file(parsed_items, output_markdown_file) {
                    Ok(_) -> {
                      // Step 5: Compare semantic content
                      case simplifile.read(output_markdown_file) {
                        Ok(output_content) -> {
                          // Validate key content is preserved
                          string.contains(output_content, "Test file system roundtrip") |> should.be_true()
                          string.contains(output_content, "Verify CalDAV compatibility") |> should.be_true()
                          string.contains(output_content, "Complete integration testing") |> should.be_true()
                          string.contains(output_content, "@computer") |> should.be_true()
                          string.contains(output_content, "@home") |> should.be_true()
                          string.contains(output_content, "Write comprehensive tests") |> should.be_true()
                        }
                        Error(_) -> should.fail()
                      }
                    }
                    Error(_) -> should.fail()
                  }
                }
                Error(_) -> should.fail()
              }
            }
            Error(_) -> should.fail()
          }
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
  
  // Cleanup
  let _ = simplifile.delete(test_todo_file)
  let _ = simplifile.delete(output_markdown_file)
  let _ = cleanup_directory(test_ics_dir)
}

pub fn multiple_roundtrip_cycles_test() {
  // Test 19: Multiple Roundtrip Cycles from spec
  let original_markdown = "- [ ] Cycle stability test @computer
- [x] Completed cycle test @home  
- [ ] Complex cycle with notes @office
  - Note one
  - Note two"

  let original_items = markdown_parser.parse_content(original_markdown)
  
  // Perform 5 complete roundtrip cycles
  let final_items = perform_roundtrip_cycles(original_items, 5)
  
  // Validate no progressive data loss
  final_items |> list.length() |> should.equal(3)
  
  // Check specific semantic equivalence
  let summaries = list.map(final_items, fn(item) { item.summary })
  list.contains(summaries, "Cycle stability test") |> should.be_true()
  list.contains(summaries, "Completed cycle test") |> should.be_true()
  list.contains(summaries, "Complex cycle with notes") |> should.be_true()
  
  // Check completion status maintained
  let completed_items = list.filter(final_items, fn(item) { item.completed })
  completed_items |> list.length() |> should.equal(1)
  
  // Check notes preserved
  let items_with_notes = list.filter(final_items, fn(item) { 
    list.length(item.notes) > 0 
  })
  items_with_notes |> list.length() |> should.equal(1)
  let assert [item_with_notes] = items_with_notes
  item_with_notes.notes |> should.equal(["Note one", "Note two"])
}

// =============================================================================
// Error Handling and Edge Cases
// =============================================================================

pub fn invalid_ics_recovery_test() {
  // Test error recovery during roundtrip with partially invalid data
  let test_dir = "/tmp/test_mixed_ics"
  let _ = simplifile.create_directory_all(test_dir)
  
  // Create one valid and one invalid .ics file
  let valid_ics = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:valid@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Valid task
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
END:VTODO
END:VCALENDAR"

  let invalid_ics = "INVALID ICS CONTENT"
  
  let _ = simplifile.write(test_dir <> "/valid.ics", valid_ics)
  let _ = simplifile.write(test_dir <> "/invalid.ics", invalid_ics)
  
  // Parse directory in permissive mode (default)
  case vtodo_parser.parse_ics_directory(test_dir) {
    Ok(items) -> {
      // Should successfully parse valid files, skip invalid ones
      items |> list.length() |> should.equal(1)
      let assert [item] = items
      item.summary |> should.equal("Valid task")
    }
    Error(_) -> should.fail()
  }
  
  // Cleanup
  let _ = cleanup_directory(test_dir)
}

pub fn empty_content_roundtrip_test() {
  // Test roundtrip with empty/minimal content
  let empty_markdown = ""
  let minimal_markdown = "## Inbox"
  
  // Empty content should produce empty list
  let empty_items = markdown_parser.parse_content(empty_markdown)
  empty_items |> should.equal([])
  
  // Minimal content should also produce empty list (no tasks)
  let minimal_items = markdown_parser.parse_content(minimal_markdown)  
  minimal_items |> should.equal([])
  
  // Converting empty list to markdown should produce valid structure
  let reconstructed = markdown_writer.generate_content([])
  string.contains(reconstructed, "GTD Todo List") |> should.be_true()
}

// =============================================================================
// Helper Functions
// =============================================================================

fn perform_roundtrip_cycles(items: List(todo_item.TodoItem), cycles: Int) -> List(todo_item.TodoItem) {
  case cycles <= 0 {
    True -> items
    False -> {
      let roundtrip_items = 
        items
        |> list.map(fn(item) {
          let ics = vtodo_generator.item_to_vtodo(item)
          let assert Ok(parsed) = vtodo_parser.parse_ics_content(ics)
          parsed
        })
      perform_roundtrip_cycles(roundtrip_items, cycles - 1)
    }
  }
}

fn cleanup_directory(dir: String) -> Nil {
  case simplifile.read_directory(dir) {
    Ok(files) -> {
      list.each(files, fn(file) {
        let _ = simplifile.delete(dir <> "/" <> file)
        Nil
      })
      let _ = simplifile.delete(dir)
      Nil
    }
    Error(_) -> Nil
  }
}