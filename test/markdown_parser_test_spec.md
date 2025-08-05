# MarkdownParser Test Specification

## Test Philosophy

These tests serve as both specification and validation. Each test case documents the exact expected behavior with concrete input/output examples.

## Basic Task Parsing Tests {#basic-task-parsing}

### Test 1: Simple Uncompleted Task
**Input:**
```markdown
- [ ] Simple task
```

**Expected Output:**
```gleam
TodoItem(
  uid: "inbox:simple task" |> generate_uid_hash(), // Stable hash of content
  summary: "Simple task",
  completed: False,
  context: None,
  notes: [],
  section: "Inbox", // Default section
  due_date: None,
  start_date: None,
  created_at: test_timestamp,
  modified_at: test_timestamp,
)
```

### Test 2: Completed Task
**Input:**
```markdown
- [x] Completed task
```

**Expected Output:**
```gleam
TodoItem(
  uid: "inbox:completed task" |> generate_uid_hash(),
  summary: "Completed task", 
  completed: True, // ← Key difference
  context: None,
  notes: [],
  section: "Inbox",
  due_date: None,
  start_date: None,
  created_at: test_timestamp,
  modified_at: test_timestamp,
)
```

### Test 3: Task with Context
**Input:**
```markdown
- [ ] Build out mx2 @computer
```

**Expected Output:**
```gleam
TodoItem(
  uid: "inbox:build out mx2" |> generate_uid_hash(),
  summary: "Build out mx2", // Context removed from summary
  completed: False,
  context: Some("@computer"), // Context extracted
  notes: [],
  section: "Inbox",
  due_date: None,
  start_date: None,
  created_at: test_timestamp,
  modified_at: test_timestamp,
)
```

## Section Header Tests

### Test 4: Section Assignment
**Input:**
```markdown
## Next Actions
- [ ] Task in section
```

**Expected Output:**
```gleam
TodoItem(
  uid: "next actions:task in section" |> generate_uid_hash(),
  summary: "Task in section",
  completed: False,
  context: None,
  notes: [],
  section: "Next Actions", // ← Section from header
  due_date: None,
  start_date: None,
  created_at: test_timestamp,
  modified_at: test_timestamp,
)
```

### Test 5: Multiple Sections
**Input:**
```markdown
## Next Actions
- [ ] First task

## Projects  
- [ ] Second task
```

**Expected Output:**
```gleam
[
  TodoItem(
    uid: "next actions:first task" |> generate_uid_hash(),
    summary: "First task",
    section: "Next Actions",
    // ... other fields default
  ),
  TodoItem(
    uid: "projects:second task" |> generate_uid_hash(), 
    summary: "Second task",
    section: "Projects", // ← Different section
    // ... other fields default
  ),
]
```

## Sub-Notes Tests

### Test 6: Task with Single Note
**Input:**
```markdown
- [ ] Main task
  - Additional note
```

**Expected Output:**
```gleam
TodoItem(
  uid: "inbox:main task" |> generate_uid_hash(),
  summary: "Main task",
  completed: False,
  context: None,
  notes: ["Additional note"], // ← Note extracted
  section: "Inbox",
  due_date: None,
  start_date: None,
  created_at: test_timestamp,
  modified_at: test_timestamp,
)
```

### Test 7: Task with Multiple Notes
**Input:**
```markdown
- [ ] Complex task
  - First note  
  - Second note
  - Third note
```

**Expected Output:**
```gleam
TodoItem(
  uid: "inbox:complex task" |> generate_uid_hash(),
  summary: "Complex task",
  notes: ["First note", "Second note", "Third note"], // ← All notes preserved in order
  // ... other fields default
)
```

### Test 8: Mixed Indentation Notes
**Input:**
```markdown
- [ ] Task with notes
  - Standard note
    - Deeply indented (should be ignored or flattened)
  - Another standard note
```

**Expected Behavior:** Only properly indented notes (2 spaces + dash) are captured. Deeper indentation is either ignored or flattened to standard note format.

**Expected Output:**
```gleam
TodoItem(
  notes: ["Standard note", "Another standard note"],
  // Deep indentation ignored/flattened
)
```

## Date Parsing Tests

### Test 9: Due Date Extraction
**Input:**
```markdown
- [ ] Important task due 7/25
```

**Expected Output:**
```gleam
TodoItem(
  uid: "inbox:important task" |> generate_uid_hash(),
  summary: "Important task", // "due 7/25" removed from summary
  due_date: Some(Date(2024, 7, 25)), // ← Due date extracted and parsed
  // ... other fields default
)
```

### Test 10: Start Date Extraction
**Input:**
```markdown
- [ ] Scheduled task - Scheduled for 12/1
```

**Expected Output:**
```gleam
TodoItem(
  summary: "Scheduled task", // Date info removed
  start_date: Some(Date(2024, 12, 1)), // ← Start date extracted
  // ... other fields default
)
```

### Test 11: Both Dates Present
**Input:**
```markdown
- [ ] Full task - Scheduled for 11/15, Due 11/30
```

**Expected Output:**
```gleam
TodoItem(
  summary: "Full task", // Both date patterns removed
  start_date: Some(Date(2024, 11, 15)),
  due_date: Some(Date(2024, 11, 30)),
  // ... other fields default
)
```

### Test 12: Year Boundary Intelligence
**Test Date: July 1, 2024**

**Input:**
```markdown
- [ ] Task due 6/15
- [ ] Task due 8/15  
```

**Expected Output:**
```gleam
[
  TodoItem(
    summary: "Task", 
    due_date: Some(Date(2025, 6, 15)), // ← Next year (6 < 7, date in past)
  ),
  TodoItem(
    summary: "Task",
    due_date: Some(Date(2024, 8, 15)), // ← This year (8 > 7, date in future)
  ),
]
```

## Complex Real-World Examples {#complex-real-world-examples}

### Test 13: Full GTD Document
**Input:**
```markdown
# GTD Todo List

## Inbox
- [ ] Process inbox @computer

## Next Actions
- [ ] Build out mx2 @computer
- [x] Fix grout in shower @home
- [ ] Important meeting due 7/25 @office
  - Prepare agenda
  - Book conference room

## Projects
### Home Maintenance
- [ ] Window cleaning project @calls
  - Called three companies
  - Waiting for quotes

## Waiting For
- [ ] Lawyer response (IN PROGRESS) @waiting

## Someday/Maybe
- [ ] Learn new language @anywhere
```

**Expected Output:**
```gleam
[
  // Inbox item
  TodoItem(
    summary: "Process inbox",
    context: Some("@computer"), 
    section: "Inbox",
    completed: False,
    // ...
  ),
  
  // Next Actions items
  TodoItem(
    summary: "Build out mx2",
    context: Some("@computer"),
    section: "Next Actions", 
    completed: False,
    // ...
  ),
  TodoItem(
    summary: "Fix grout in shower",
    context: Some("@home"),
    section: "Next Actions",
    completed: True, // ← Completed task
    // ...
  ),
  TodoItem(
    summary: "Important meeting",
    context: Some("@office"),
    section: "Next Actions",
    due_date: Some(Date(2024, 7, 25)), // ← Due date extracted
    notes: ["Prepare agenda", "Book conference room"], // ← Sub-notes
    // ...
  ),
  
  // Projects items (note: subsection header ignored, tasks go to Projects)
  TodoItem(
    summary: "Window cleaning project",
    context: Some("@calls"),
    section: "Projects",
    notes: ["Called three companies", "Waiting for quotes"],
    // ...
  ),
  
  // Waiting For items
  TodoItem(
    summary: "Lawyer response (IN PROGRESS)",
    context: Some("@waiting"),
    section: "Waiting For",
    // ...
  ),
  
  // Someday/Maybe items
  TodoItem(
    summary: "Learn new language", 
    context: Some("@anywhere"),
    section: "Someday/Maybe",
    // ...
  ),
]
```

## Edge Cases and Error Handling

### Test 14: Malformed Checkbox Syntax
**Input:**
```markdown
- [] Missing space in checkbox
- [ ] Correct syntax
- [X] Capital X (should work)
- [✓] Unicode checkmark (should be treated as completed)
```

**Expected Behavior:**
- Line 1: Ignored (malformed)
- Line 2: Parsed correctly as incomplete
- Line 3: Parsed as completed
- Line 4: Implementation-dependent (may treat as completed or ignore)

### Test 15: Context Extraction Edge Cases
**Input:**
```markdown
- [ ] Task with @context in middle @computer
- [ ] Task with multiple @home @computer @contexts
- [ ] Task with @context-with-dashes
- [ ] Task with @123numeric
- [ ] No context task
```

**Expected Behavior:**
- Line 1: Context = "@computer" (last @word wins)
- Line 2: Context = "@contexts" (last valid @word) 
- Line 3: Context = "@context-with-dashes" (dashes allowed)
- Line 4: Context = "@123numeric" (numbers allowed)
- Line 5: Context = None

### Test 16: Date Parsing Edge Cases
**Input:**
```markdown
- [ ] Task due 2/30 (invalid date)
- [ ] Task due 13/15 (invalid month)
- [ ] Task due tomorrow (non-numeric)
- [ ] Task due 7/25/2024 (with year - unsupported format)
```

**Expected Behavior:**
- All invalid dates should result in `due_date: None`
- Tasks should still be parsed with clean summaries
- No parsing failures for invalid dates

### Test 17: Unicode and Special Characters
**Input:**
```markdown
- [ ] Task with émojis 🚀 and special chars: @home
- [ ] Task, with; commas & semicolons @computer
- [ ] Task "with quotes" and 'apostrophes' @office
```

**Expected Output:**
```gleam
[
  TodoItem(
    summary: "Task with émojis 🚀 and special chars:",
    context: Some("@home"),
    // ... Unicode preserved
  ),
  TodoItem(
    summary: "Task, with; commas & semicolons", 
    context: Some("@computer"),
    // ... Special chars preserved
  ),
  TodoItem(
    summary: "Task \"with quotes\" and 'apostrophes'",
    context: Some("@office"), 
    // ... Quotes preserved
  ),
]
```

## Performance and Memory Tests

### Test 18: Large Document Handling
**Input:** 1000+ todo items across multiple sections

**Expected Behavior:**
- Parser should handle large documents efficiently
- Memory usage should be reasonable (streaming/incremental parsing preferred)
- Processing time should scale linearly with document size

### Test 19: Deeply Nested Notes
**Input:** Task with 100+ sub-notes

**Expected Behavior:**
- All notes should be captured in order
- No stack overflow or memory issues
- Performance should remain acceptable

## UID Generation Tests

### Test 20: UID Stability
**Input:** Same task content parsed multiple times

**Expected Behavior:**
```gleam
let task1 = parse_content("- [ ] Same task @home")
let task2 = parse_content("- [ ] Same task @home") 

assert task1.uid == task2.uid // UID must be stable
```

### Test 21: UID Uniqueness  
**Input:** Different task content

**Expected Behavior:**
```gleam
let task1 = parse_content("- [ ] First task @home")
let task2 = parse_content("- [ ] Second task @home")

assert task1.uid != task2.uid // Different content = different UID
```

### Test 22: UID Format Validation {#uid-generation-tests}
**Expected Format:** `{12-hex-chars}@todo-md-sync`

**Test:**
```gleam
let task = parse_content("- [ ] Test task")
assert String.length(task.uid) == 12 + 1 + 13 // hash + @ + domain
assert String.ends_with(task.uid, "@todo-md-sync")
assert String.match(task.uid, "^[0-9a-f]{12}@todo-md-sync$")
```

## TodoItem Creation Tests {#todoitem-creation}

### Test 23: TodoItem Factory Function
**Purpose:** Test the TodoItem creation and initialization process

**Test Cases:**
```gleam
// Test basic TodoItem creation
let item = todo_item.new(
  "Test task",      // summary
  "Next Actions",   // section
  False,           // completed
  Some("@home"),   // context
  ["Note 1"],      // notes
  None,            // due_date
  None,            // start_date
)

// Verify proper initialization
assert item.summary == "Test task"
assert item.section == "Next Actions"
assert item.completed == False
assert item.context == Some("@home")
assert item.notes == ["Note 1"]
assert String.ends_with(item.uid, "@todo-md-sync")
assert item.created_at != None
assert item.modified_at != None
```

### Test 24: UID Stability Across Creation
**Purpose:** Ensure same content produces same UID

**Test:**
```gleam
let item1 = todo_item.new("Same task", "Inbox", False, None, [], None, None)
let item2 = todo_item.new("Same task", "Inbox", False, None, [], None, None)

assert item1.uid == item2.uid  // Same content = same UID
```

---

*These test specifications define the exact expected behavior of the MarkdownParser module. Implementation must pass all these tests to be considered correct.*