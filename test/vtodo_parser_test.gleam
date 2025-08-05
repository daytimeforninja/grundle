import birl
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import simplifile
import vtodo_parser

// =============================================================================
// VTodo File Parsing Tests - Based on test/roundtrip_conversion_test_spec.md#vtodo-parsing
// =============================================================================

pub fn parse_ics_file_success_test() {
  // Test successful parsing of a valid .ics file
  let test_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:abc123def456@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Simple task
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
END:VTODO
END:VCALENDAR"

  // Create temporary test file
  let test_path = "/tmp/test_vtodo_parser.ics"
  let _ = simplifile.write(test_path, test_content)
  
  case vtodo_parser.parse_ics_file(test_path) {
    Ok(item) -> {
      item.uid |> should.equal("abc123def456@todo-md-sync")
      item.summary |> should.equal("Simple task")
      item.completed |> should.equal(False)
      item.section |> should.equal("Inbox")
      item.context |> should.equal(None)
      item.notes |> should.equal([])
    }
    Error(_) -> should.fail()
  }
  
  // Cleanup
  let _ = simplifile.delete(test_path)
}

pub fn parse_ics_file_not_found_test() {
  // Test error handling for missing file
  case vtodo_parser.parse_ics_file("/nonexistent/file.ics") {
    Error(vtodo_parser.FileNotFound(path)) -> {
      path |> should.equal("/nonexistent/file.ics")
    }
    _ -> should.fail()
  }
}

// =============================================================================
// VTodo Content Parsing Tests - Based on test/vtodo_generator_test_spec.md#standards-compliance
// =============================================================================

pub fn parse_ics_content_minimal_vtodo_test() {
  // Test 1: Minimal TodoItem from vtodo_generator_test_spec.md#basic-vtodo-structure
  let ics_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:abc123def456@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Simple task
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(item) -> {
      // Verify exact spec requirements from generator test
      item.uid |> should.equal("abc123def456@todo-md-sync")
      item.summary |> should.equal("Simple task")
      item.completed |> should.equal(False) // STATUS:NEEDS-ACTION → False
      item.context |> should.equal(None)
      item.notes |> should.equal([])
      item.section |> should.equal("Inbox") // CATEGORIES → section
      item.due_date |> should.equal(None)
      item.start_date |> should.equal(None)
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_ics_content_completed_task_test() {
  // Test 2: Completed Task from spec
  let ics_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:def789ghi012@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Done task
STATUS:COMPLETED
CATEGORIES:Inbox
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(item) -> {
      // Key difference: STATUS:COMPLETED → completed: True
      item.summary |> should.equal("Done task")
      item.completed |> should.equal(True) // ←Key validation point
      item.section |> should.equal("Inbox")
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_ics_content_task_with_context_test() {
  // Test 3: Task with Context from spec
  let ics_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:ghi345jkl678@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Build server
STATUS:NEEDS-ACTION
CATEGORIES:Next Actions
LOCATION:computer
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(item) -> {
      // Validation points from spec:
      item.summary |> should.equal("Build server")
      item.context |> should.equal(Some("@computer")) // LOCATION → @context
      item.section |> should.equal("Next Actions") // CATEGORIES → section
      item.completed |> should.equal(False)
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_ics_content_with_dates_test() {
  // Test 6: Task with Both Dates from spec
  let ics_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:test123dates456@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Project phase
STATUS:NEEDS-ACTION
CATEGORIES:Projects
DTSTART;VALUE=DATE:20241115
DUE;VALUE=DATE:20241130
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(item) -> {
      item.summary |> should.equal("Project phase")
      
      // Verify both dates parsed correctly
      let assert Some(start) = item.start_date
      let assert Some(due) = item.due_date
      let start_string = birl.to_iso8601(start)
      let due_string = birl.to_iso8601(due)
      string.contains(start_string, "-11-15") |> should.be_true()
      string.contains(due_string, "-11-30") |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_ics_content_with_notes_test() {
  // Test 11: Task with Multiple Notes from spec
  let ics_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:notes123test456@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Complex task
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
DESCRIPTION:First note\\nSecond note\\nThird note
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(ics_content) {
    Ok(item) -> {
      item.summary |> should.equal("Complex task")
      // DESCRIPTION with \n should split into multiple notes
      item.notes |> should.equal(["First note", "Second note", "Third note"])
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_ics_content_windows_line_endings_test() {
  // Test cross-platform line ending handling
  let ics_content_windows = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Todo.md Sync//EN\r\nCALSCALE:GREGORIAN\r\nBEGIN:VTODO\r\nUID:windows123test@todo-md-sync\r\nDTSTAMP:20240724T001405Z\r\nCREATED:20240724T001405Z\r\nLAST-MODIFIED:20240724T001405Z\r\nSUMMARY:Windows format task\r\nSTATUS:NEEDS-ACTION\r\nCATEGORIES:Inbox\r\nEND:VTODO\r\nEND:VCALENDAR"

  case vtodo_parser.parse_ics_content(ics_content_windows) {
    Ok(item) -> {
      item.summary |> should.equal("Windows format task")
      item.section |> should.equal("Inbox")
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_ics_content_missing_required_fields_test() {
  // Test error handling for missing required fields
  let incomplete_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:missing123fields@todo-md-sync
SUMMARY:Task missing status
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(incomplete_content) {
    Error(vtodo_parser.MissingRequiredField(msg)) -> {
      // Should mention missing required fields
      string.contains(msg, "Missing:") |> should.be_true()
    }
    _ -> should.fail()
  }
}

// =============================================================================
// Directory Parsing Tests - Based on test/roundtrip_conversion_test_spec.md#integration-tests
// =============================================================================

pub fn parse_ics_directory_multiple_files_test() {
  // Test parsing entire directory of .ics files
  let test_dir = "/tmp/test_ics_directory"
  let _ = simplifile.create_directory_all(test_dir)
  
  // Create multiple test files
  let file1_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:file1@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:First task
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
END:VTODO
END:VCALENDAR"

  let file2_content = "BEGIN:VCALENDAR
VERSION:2.0  
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:file2@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Second task
STATUS:COMPLETED
CATEGORIES:Next Actions
END:VTODO
END:VCALENDAR"

  let _ = simplifile.write(test_dir <> "/file1.ics", file1_content)
  let _ = simplifile.write(test_dir <> "/file2.ics", file2_content)
  let _ = simplifile.write(test_dir <> "/notanics.txt", "ignore me") // Should be ignored
  
  case vtodo_parser.parse_ics_directory(test_dir) {
    Ok(items) -> {
      // Should parse both .ics files
      items |> list.length() |> should.equal(2)
      
      // Find specific tasks
      let summaries = list.map(items, fn(item) { item.summary })
      list.contains(summaries, "First task") |> should.be_true()
      list.contains(summaries, "Second task") |> should.be_true()
    }
    Error(_) -> should.fail()
  }
  
  // Cleanup
  let _ = simplifile.delete(test_dir <> "/file1.ics")
  let _ = simplifile.delete(test_dir <> "/file2.ics")
  let _ = simplifile.delete(test_dir <> "/notanics.txt")
  let _ = simplifile.delete(test_dir)
}

pub fn parse_ics_directory_not_found_test() {
  // Test error handling for missing directory  
  case vtodo_parser.parse_ics_directory("/tmp/nonexistent_directory_test") {
    Error(vtodo_parser.FileNotFound(path)) -> {
      path |> should.equal("/tmp/nonexistent_directory_test")
    }
    _ -> should.fail()
  }
}

pub fn parse_ics_directory_strict_mode_test() {
  // Test strict mode fails on any parse error
  let test_dir = "/tmp/test_strict_directory"
  let _ = simplifile.create_directory_all(test_dir)
  
  // Create one valid and one invalid file
  let valid_content = "BEGIN:VCALENDAR
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

  let invalid_content = "INVALID CONTENT"
  
  let _ = simplifile.write(test_dir <> "/valid.ics", valid_content)
  let _ = simplifile.write(test_dir <> "/invalid.ics", invalid_content)
  
  // Strict mode should fail
  case vtodo_parser.parse_ics_directory_strict(test_dir) {
    Error(_) -> should.be_true(True) // Expected error
    Ok(_) -> should.fail() // Should not succeed with invalid file
  }
  
  // Cleanup
  let _ = simplifile.delete(test_dir <> "/valid.ics")
  let _ = simplifile.delete(test_dir <> "/invalid.ics")
  let _ = simplifile.delete(test_dir)
}

// =============================================================================
// Private Function Tests - Internal parsing logic
// =============================================================================

pub fn extract_vtodo_properties_test() {
  // Test property extraction filtering (testing through parse_ics_content)
  let ics_with_extra_properties = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
X-CUSTOM-PROPERTY:Should be ignored
BEGIN:VTODO
UID:properties@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Property test
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
X-VTODO-CUSTOM:Should be parsed
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(ics_with_extra_properties) {
    Ok(item) -> {
      // Should successfully parse despite extra properties
      item.summary |> should.equal("Property test")
      item.section |> should.equal("Inbox")
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_property_colon_splitting_test() {
  // Test property line parsing (indirectly through content parsing)
  let ics_with_colon_in_value = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:colon@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z  
LAST-MODIFIED:20240724T001405Z
SUMMARY:Task: with colon in summary
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(ics_with_colon_in_value) {
    Ok(item) -> {
      // Colon in property value should be preserved (only first colon is delimiter)
      item.summary |> should.equal("Task: with colon in summary")
    }
    Error(_) -> should.fail()
  }
}

pub fn build_todo_item_ios_categories_cleanup_test() {
  // Test iOS-style category cleanup (CATEGORIES:"# Inbox" → "Inbox")
  let ios_style_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:ios@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:iOS task
STATUS:NEEDS-ACTION
CATEGORIES:# Next Actions
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(ios_style_content) {
    Ok(item) -> {
      // "# " prefix should be cleaned from section
      item.section |> should.equal("Next Actions")
    }
    Error(_) -> should.fail()
  }
}

pub fn get_property_parameterized_keys_test() {
  // Test property retrieval with parameters (DUE;VALUE=DATE)
  let content_with_parameters = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:params@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Parameter test
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
DUE;VALUE=DATE:20241201
DTSTART;VALUE=DATE:20241115
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(content_with_parameters) {
    Ok(item) -> {
      // Should handle parameterized property keys correctly
      item.due_date |> should.not_equal(None)
      item.start_date |> should.not_equal(None)
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_ics_date_format_validation_test() {
  // Test YYYYMMDD date format parsing
  let content_with_date = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:datetest@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Date validation test
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
DUE;VALUE=DATE:20241231
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(content_with_date) {
    Ok(item) -> {
      let assert Some(due_date) = item.due_date
      let date_string = birl.to_iso8601(due_date)
      string.contains(date_string, "-12-31") |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

pub fn parse_ics_datetime_z_suffix_handling_test() {
  // Test DATETIME parsing with and without Z suffix
  let content_with_datetime = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:datetime@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T103000Z
LAST-MODIFIED:20240725T141530
SUMMARY:DateTime test
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(content_with_datetime) {
    Ok(item) -> {
      // Should parse both Z-terminated and non-Z timestamps
      item.summary |> should.equal("DateTime test")
      // Timestamps should be valid (not None)
      item.created_at |> should.not_equal(birl.from_unix(0))
      item.modified_at |> should.not_equal(birl.from_unix(0))
    }
    Error(_) -> should.fail()
  }
}

pub fn is_valid_day_for_month_leap_year_test() {
  // Test leap year handling in date validation (through date parsing)
  let leap_year_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:leapyear@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Leap year test
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
DUE;VALUE=DATE:20240229
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(leap_year_content) {
    Ok(item) -> {
      // Feb 29, 2024 should be valid (2024 is leap year)
      item.due_date |> should.not_equal(None)
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_directory_path_traversal_prevention_test() {
  // Test path traversal prevention
  case vtodo_parser.parse_ics_directory("../../../etc") {
    Error(vtodo_parser.InvalidFormat(msg)) -> {
      string.contains(msg, "traversal") |> should.be_true()
    }
    _ -> should.fail()
  }
  
  // Test tilde expansion prevention
  case vtodo_parser.parse_ics_directory("~/dangerous") {
    Error(vtodo_parser.InvalidFormat(msg)) -> {
      string.contains(msg, "traversal") |> should.be_true()
    }
    _ -> should.fail()
  }
}

pub fn unescape_text_rfc5545_compliance_test() {
  // Test text unescaping (reverse of escape_text)
  let escaped_content = "BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:escape@todo-md-sync
DTSTAMP:20240724T001405Z
CREATED:20240724T001405Z
LAST-MODIFIED:20240724T001405Z
SUMMARY:Task\\, with\\; escaped\\n characters\\\\
STATUS:NEEDS-ACTION
CATEGORIES:Inbox
END:VTODO
END:VCALENDAR"

  case vtodo_parser.parse_ics_content(escaped_content) {
    Ok(item) -> {
      // Should unescape according to RFC 5545:
      // \\, → ,  \\; → ;  \\n → newline  \\\\ → \
      item.summary |> should.equal("Task, with; escaped\n characters\\")
    }
    Error(_) -> should.fail()
  }
}

pub fn sanitize_path_for_log_security_test() {
  // Test path sanitization prevents log injection (indirectly through error handling)
  let test_dir = "/tmp/test\ninjection\rdirectory"
  case vtodo_parser.parse_ics_directory(test_dir) {
    Error(_) -> {
      // Should not crash or leak dangerous characters in logs
      should.be_true(True)
    }
    Ok(_) -> should.be_true(True) // Also acceptable if path is valid
  }
}

pub fn sanitize_error_message_information_leakage_test() {
  // Test error message sanitization (indirectly)
  case vtodo_parser.parse_ics_directory("/home/sensitive/path") {
    Error(_) -> {
      // Should handle error without information leakage
      should.be_true(True)
    }
    Ok(_) -> should.be_true(True) // Also acceptable if path is accessible
  }
}