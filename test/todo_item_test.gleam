import birl
import gleam/option.{None, Some}
import gleam/regexp
import gleam/string
import gleeunit/should
import todo_item.{TodoItem}

// =============================================================================
// UID Generation Tests - Based on test/markdown_parser_test_spec.md#uid-generation-tests
// =============================================================================

pub fn uid_format_validation_test() {
  // Test 22: UID Format Validation from spec
  // Expected Format: {12-hex-chars}@todo-md-sync
  
  let uid = todo_item.generate_uid("Test task", "Inbox")
  
  // Verify total length: 12 hex + 1 @ + 12 "todo-md-sync" = 25
  string.length(uid)
  |> should.equal(25)
  
  // Verify ends with domain
  string.ends_with(uid, "@todo-md-sync")
  |> should.be_true()
  
  // Verify hex format: exactly 12 hex chars followed by @todo-md-sync
  case regexp.from_string("^[0-9a-f]{12}@todo-md-sync$") {
    Ok(re) -> {
      regexp.check(re, uid)
      |> should.be_true()
    }
    Error(_) -> should.fail()
  }
}

pub fn uid_stability_across_generation_test() {
  // From spec: "same content produces same UID"
  let uid1 = todo_item.generate_uid("Test task", "Inbox")
  let uid2 = todo_item.generate_uid("Test task", "Inbox")
  
  uid1
  |> should.equal(uid2)
  
  // Different content produces different UIDs
  let uid3 = todo_item.generate_uid("Different task", "Inbox")
  let uid4 = todo_item.generate_uid("Test task", "Next Actions")
  
  uid1 |> should.not_equal(uid3)
  uid1 |> should.not_equal(uid4)
}

pub fn uid_hash_based_on_section_and_summary_test() {
  // Verify UID is based on "section:summary" as per README.md spec
  let uid_inbox = todo_item.generate_uid("Same task", "Inbox")
  let uid_next = todo_item.generate_uid("Same task", "Next Actions")
  
  // Same summary, different section = different UID
  uid_inbox
  |> should.not_equal(uid_next)
  
  // Verify stability within same section:summary combination
  let uid_inbox_2 = todo_item.generate_uid("Same task", "Inbox")
  uid_inbox
  |> should.equal(uid_inbox_2)
}

// =============================================================================
// TodoItem Creation Tests - Based on test/markdown_parser_test_spec.md#todoitem-creation
// =============================================================================

pub fn todoitem_factory_function_test() {
  // Test 23: TodoItem Factory Function from spec
  let item = todo_item.new(
    "Test task",      // summary  
    "Next Actions",   // section
    False,           // completed
    Some("@home"),   // context
    ["Note 1"],      // notes
    None,            // due_date
    None,            // start_date
  )
  
  // Verify proper initialization as per spec
  item.summary |> should.equal("Test task")
  item.section |> should.equal("Next Actions") 
  item.completed |> should.equal(False)
  item.context |> should.equal(Some("@home"))
  item.notes |> should.equal(["Note 1"])
  
  // Verify UID format
  string.ends_with(item.uid, "@todo-md-sync")
  |> should.be_true()
  
  // Verify timestamps are set (not None/zero)
  item.created_at |> should.not_equal(birl.from_unix(0))
  item.modified_at |> should.not_equal(birl.from_unix(0))
}

pub fn uid_stability_across_creation_test() {
  // Test 24: UID Stability Across Creation from spec
  let item1 = todo_item.new("Same task", "Inbox", False, None, [], None, None)
  let item2 = todo_item.new("Same task", "Inbox", False, None, [], None, None)
  
  // Same content = same UID (as specified)
  item1.uid
  |> should.equal(item2.uid)
}

pub fn todoitem_creation_with_all_fields_test() {
  // Extended test: Create TodoItem with all possible fields populated
  let test_date = case birl.from_naive("2024-07-25") {
    Ok(date) -> Some(date)
    Error(_) -> None
  }
  
  let item = todo_item.new(
    "Complex task with all fields",
    "Projects", 
    True,
    Some("@computer"),
    ["Note 1", "Note 2", "Note 3"],
    test_date,    // due_date
    test_date,    // start_date
  )
  
  // Verify all fields properly set
  item.summary |> should.equal("Complex task with all fields")
  item.section |> should.equal("Projects")
  item.completed |> should.equal(True)
  item.context |> should.equal(Some("@computer"))
  item.notes |> should.equal(["Note 1", "Note 2", "Note 3"])
  item.due_date |> should.equal(test_date)
  item.start_date |> should.equal(test_date)
  
  // UID should be generated from summary and section
  let expected_uid = todo_item.generate_uid("Complex task with all fields", "Projects")
  item.uid |> should.equal(expected_uid)
}

// =============================================================================
// Timestamp Management Tests - Based on test/roundtrip_conversion_test_spec.md#timestamp-management
// =============================================================================

pub fn timestamp_preservation_through_touch_test() {
  // Based on "Modified timestamp updated on conversion" requirement
  let original = todo_item.new("Original task", "Inbox", False, None, [], None, None)
  
  // Record original timestamps
  let original_created = original.created_at
  let original_modified = original.modified_at
  
  // Touch the item (simulating conversion process)
  let touched = todo_item.touch(original)
  
  // Created timestamp should be preserved exactly
  touched.created_at
  |> should.equal(original_created)
  
  // Modified timestamp should be updated
  touched.modified_at
  |> should.not_equal(original_modified)
  
  // All other fields should remain identical
  touched.uid |> should.equal(original.uid)
  touched.summary |> should.equal(original.summary)
  touched.completed |> should.equal(original.completed)
  touched.context |> should.equal(original.context)
  touched.notes |> should.equal(original.notes)
  touched.section |> should.equal(original.section)
  touched.due_date |> should.equal(original.due_date)
  touched.start_date |> should.equal(original.start_date)
}

pub fn timestamp_consistency_test() {
  // Verify UTC timezone handling is consistent
  let item = todo_item.new("Timestamp test", "Inbox", False, None, [], None, None)
  
  // For new items, created_at and modified_at should be same
  item.created_at
  |> should.equal(item.modified_at)
  
  // Both should be recent (not ancient timestamps)
  let now = birl.utc_now()
  let created_unix = birl.to_unix(item.created_at)
  let now_unix = birl.to_unix(now)
  
  // Should be within 60 seconds of now (generous for test timing)
  let time_diff = now_unix - created_unix
  case time_diff >= 0 && time_diff <= 60 {
    True -> should.be_true(True)
    False -> should.fail()
  }
}

// =============================================================================
// Data Validation Tests - Based on test/vtodo_generator_test_spec.md#empty-nil-fields-handling  
// =============================================================================

pub fn validate_rejects_empty_summary_test() {
  let invalid_item = TodoItem(
    uid: "test@todo-md-sync",
    summary: "   ",  // Empty when trimmed
    completed: False,
    context: None,
    notes: [],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: birl.utc_now(),
    modified_at: birl.utc_now()
  )
  
  case todo_item.validate(invalid_item) {
    Error(todo_item.InvalidSummary(msg)) -> {
      msg |> should.equal("Summary cannot be empty")
    }
    _ -> should.fail()
  }
}

pub fn validate_rejects_empty_section_test() {
  let invalid_item = TodoItem(
    uid: "test@todo-md-sync",
    summary: "Valid summary",
    completed: False,
    context: None,
    notes: [],
    section: "",  // Empty section
    due_date: None,
    start_date: None,
    created_at: birl.utc_now(),
    modified_at: birl.utc_now()
  )
  
  case todo_item.validate(invalid_item) {
    Error(todo_item.InvalidSection(msg)) -> {
      msg |> should.equal("Section cannot be empty")
    }
    _ -> should.fail()
  }
}

pub fn validate_accepts_valid_item_test() {
  let valid_item = todo_item.new(
    "Valid task with proper fields",
    "Next Actions",
    False,
    Some("@home"),
    ["Valid note"],
    None,
    None
  )
  
  case todo_item.validate(valid_item) {
    Ok(validated_item) -> {
      validated_item |> should.equal(valid_item)
    }
    Error(_) -> should.fail()
  }
}

// =============================================================================
// Semantic Equivalence Tests - Based on test/roundtrip_conversion_test_spec.md#semantic-equivalence-definition
// =============================================================================

pub fn semantic_equivalence_identical_content_test() {
  // From spec: "Two TodoItems are semantically equivalent if they have identical:
  // - Task completion status, Core task description (summary), Context assignment,
  //   Due and start dates, Sub-notes content (order preserved), Section assignment"
  
  let item1 = todo_item.new(
    "Equivalent task",
    "Next Actions", 
    False,
    Some("@computer"),
    ["Note A", "Note B"],
    None,
    None
  )
  
  let item2 = todo_item.new(
    "Equivalent task",
    "Next Actions",
    False, 
    Some("@computer"),
    ["Note A", "Note B"],
    None,
    None
  )
  
  todo_item.equivalent(item1, item2)
  |> should.be_true()
}

pub fn semantic_equivalence_ignores_timestamps_and_uid_test() {
  // UIDs and timestamps should NOT affect semantic equivalence
  let now = birl.utc_now()
  let earlier = case birl.from_naive("2023-01-01T00:00:00Z") {
    Ok(time) -> time
    Error(_) -> now
  }
  
  let item1 = TodoItem(
    uid: "uid1@todo-md-sync",        // Different UID
    summary: "Same semantic content",
    completed: False,
    context: Some("@home"),
    notes: ["Same note"],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: now,                 // Different timestamps
    modified_at: now
  )
  
  let item2 = TodoItem(
    uid: "uid2@todo-md-sync",        // Different UID
    summary: "Same semantic content",
    completed: False,
    context: Some("@home"),
    notes: ["Same note"],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: earlier,             // Different timestamps
    modified_at: earlier
  )
  
  // Should be equivalent despite different UIDs and timestamps
  todo_item.equivalent(item1, item2)
  |> should.be_true()
}

pub fn semantic_equivalence_different_summary_test() {
  let item1 = todo_item.new("Task A", "Inbox", False, None, [], None, None)
  let item2 = todo_item.new("Task B", "Inbox", False, None, [], None, None)
  
  todo_item.equivalent(item1, item2)
  |> should.be_false()
}

pub fn semantic_equivalence_different_completion_test() {
  let item1 = todo_item.new("Same task", "Inbox", False, None, [], None, None)
  let item2 = todo_item.new("Same task", "Inbox", True, None, [], None, None)
  
  todo_item.equivalent(item1, item2)
  |> should.be_false()  
}

pub fn semantic_equivalence_different_context_test() {
  let item1 = todo_item.new("Same task", "Inbox", False, Some("@home"), [], None, None)
  let item2 = todo_item.new("Same task", "Inbox", False, Some("@computer"), [], None, None)
  
  todo_item.equivalent(item1, item2)
  |> should.be_false()
}

pub fn semantic_equivalence_different_section_test() {
  let item1 = todo_item.new("Same task", "Inbox", False, None, [], None, None)
  let item2 = todo_item.new("Same task", "Next Actions", False, None, [], None, None)
  
  todo_item.equivalent(item1, item2)
  |> should.be_false()
}

pub fn semantic_equivalence_different_notes_test() {
  let item1 = todo_item.new("Same task", "Inbox", False, None, ["Note A"], None, None)
  let item2 = todo_item.new("Same task", "Inbox", False, None, ["Note B"], None, None)
  
  todo_item.equivalent(item1, item2)
  |> should.be_false()
}

pub fn semantic_equivalence_note_order_matters_test() {
  // From spec: "Sub-notes content (order preserved)"
  let item1 = todo_item.new("Same task", "Inbox", False, None, ["Note A", "Note B"], None, None)
  let item2 = todo_item.new("Same task", "Inbox", False, None, ["Note B", "Note A"], None, None)
  
  todo_item.equivalent(item1, item2)
  |> should.be_false()
}