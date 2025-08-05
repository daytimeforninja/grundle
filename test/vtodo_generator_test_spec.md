# VTodoGenerator Test Specification

## Test Philosophy

VTODO generation must produce RFC 5545 compliant iCalendar format. These tests verify exact output format, proper escaping, and CalDAV compatibility.

## Basic VTODO Structure Tests {#basic-vtodo-structure}

### Test 1: Minimal TodoItem
**Input:**
```gleam
TodoItem(
  uid: "abc123def456@todo-md-sync",
  summary: "Simple task", 
  completed: False,
  context: None,
  notes: [],
  section: "Inbox",
  due_date: None,
  start_date: None,
  created_at: DateTime(2024, 7, 24, 0, 14, 5, 0), // UTC
  modified_at: DateTime(2024, 7, 24, 0, 14, 5, 0), // UTC
)
```

**Expected iCalendar Output:**
```ics
BEGIN:VCALENDAR
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
END:VCALENDAR
```

**Validation Points:**
- ✅ Standard iCalendar wrapper (VCALENDAR/VERSION/PRODID/CALSCALE)
- ✅ VTODO component properly nested
- ✅ Required fields present (UID, DTSTAMP, SUMMARY, STATUS)
- ✅ DateTime formatted as YYYYMMDDTHHMMSSZ (UTC)
- ✅ STATUS correctly mapped from completed boolean
- ✅ CATEGORIES set from section

### Test 2: Completed Task
**Input:**
```gleam
TodoItem(
  uid: "def789ghi012@todo-md-sync",
  summary: "Done task",
  completed: True, // ← Key difference
  // ... other fields same as Test 1
)
```

**Expected Output Difference:**
```ics
STATUS:COMPLETED
```

**Validation:**
- ✅ `completed: True` → `STATUS:COMPLETED`
- ✅ `completed: False` → `STATUS:NEEDS-ACTION`

### Test 3: Task with Context
**Input:**
```gleam
TodoItem(
  uid: "ghi345jkl678@todo-md-sync",
  summary: "Build server",
  context: Some("@computer"),
  section: "Next Actions",
  // ... other fields default
)
```

**Expected Output Addition:**
```ics
SUMMARY:Build server
CATEGORIES:Next Actions
LOCATION:computer
```

**Validation Points:**
- ✅ Context maps to LOCATION field
- ✅ @ prefix removed from context for LOCATION
- ✅ Section maps to CATEGORIES field
- ✅ Summary remains clean (no context included)

## Date and DateTime Formatting Tests

### Test 4: Task with Due Date
**Input:**
```gleam
TodoItem(
  summary: "Important deadline",
  due_date: Some(Date(2024, 7, 25)),
  // ... other fields default
)
```

**Expected Output Addition:**
```ics
DUE;VALUE=DATE:20240725
```

**Validation:**
- ✅ Date formatted as YYYYMMDD
- ✅ VALUE=DATE parameter included
- ✅ No time component for date-only values

### Test 5: Task with Start Date
**Input:**
```gleam
TodoItem(
  summary: "Scheduled work",
  start_date: Some(Date(2024, 12, 1)),
  // ... other fields default
)
```

**Expected Output Addition:**
```ics
DTSTART;VALUE=DATE:20241201
```

**Validation:**
- ✅ Start date maps to DTSTART
- ✅ Same DATE format as due dates
- ✅ Proper parameter syntax

### Test 6: Task with Both Dates
**Input:**
```gleam
TodoItem(
  summary: "Project phase",
  start_date: Some(Date(2024, 11, 15)),
  due_date: Some(Date(2024, 11, 30)),
  // ... other fields default
)
```

**Expected Output Additions:**
```ics
DTSTART;VALUE=DATE:20241115
DUE;VALUE=DATE:20241130
```

**Validation:**
- ✅ Both dates present and correctly formatted
- ✅ Start date before due date (logical validation)

## Text Escaping Tests

### Test 7: Summary with Special Characters
**Input:**
```gleam
TodoItem(
  summary: "Task, with; special: chars\\and\\backslashes",
  // ... other fields default
)
```

**Expected Output:**
```ics
SUMMARY:Task\, with\; special: chars\\and\\backslashes
```

**Escaping Rules Validation:**
- ✅ Comma (`,`) → `\,`
- ✅ Semicolon (`;`) → `\;`
- ✅ Backslash (`\`) → `\\`
- ✅ Colon (`:`) remains unescaped (only in property values)

### Test 8: Summary with Newlines
**Input:**
```gleam
TodoItem(
  summary: "Multi-line\nsummary\ntext",
  // ... other fields default
)
```

**Expected Output:**
```ics
SUMMARY:Multi-line\nsummary\ntext
```

**Validation:**
- ✅ Newline (`\n`) → `\n` (literal \n sequence)
- ✅ Newlines don't break iCalendar format

### Test 9: Unicode Characters
**Input:**
```gleam
TodoItem(
  summary: "Task with émojis 🚀 and accénts",
  context: Some("@café"),
  // ... other fields default
)
```

**Expected Output:**
```ics
SUMMARY:Task with émojis 🚀 and accénts
LOCATION:café
```

**Validation:**
- ✅ UTF-8 characters preserved correctly
- ✅ Emoji characters maintained
- ✅ Accented characters in context handled properly

## Notes and Description Tests

### Test 10: Task with Single Note
**Input:**
```gleam
TodoItem(
  summary: "Main task",
  notes: ["Important detail"],
  // ... other fields default
)
```

**Expected Output Addition:**
```ics
DESCRIPTION:Important detail
```

### Test 11: Task with Multiple Notes
**Input:**
```gleam
TodoItem(
  summary: "Complex task",
  notes: ["First note", "Second note", "Third note"],
  // ... other fields default
)
```

**Expected Output Addition:**
```ics
DESCRIPTION:First note\nSecond note\nThird note
```

**Validation:**
- ✅ Multiple notes joined with `\n`
- ✅ Order preserved from input list
- ✅ Each note on separate logical line

### Test 12: Notes with Special Characters
**Input:**
```gleam
TodoItem(
  summary: "Task with complex notes",
  notes: [
    "Note with, comma",
    "Note with; semicolon", 
    "Note with\\backslash",
    "Note with\nnewline"
  ],
  // ... other fields default
)
```

**Expected Output Addition:**
```ics
DESCRIPTION:Note with\, comma\nNote with\; semicolon\nNote with\\backslash\nNote with\nnewline
```

**Validation:**
- ✅ All escaping rules applied to notes
- ✅ Note separators (`\n`) don't conflict with note content newlines
- ✅ Proper escaping maintains readability

## Complex Real-World Examples

### Test 13: Full-Featured Task
**Input:**
```gleam
TodoItem(
  uid: "full123task456@todo-md-sync",
  summary: "Complete project phase: review, test & deploy",
  completed: False,
  context: Some("@computer"),
  notes: [
    "Review code changes",
    "Run full test suite", 
    "Deploy to staging first",
    "Get approval before production"
  ],
  section: "Projects",
  due_date: Some(Date(2024, 8, 15)),
  start_date: Some(Date(2024, 8, 1)),
  created_at: DateTime(2024, 7, 24, 10, 30, 0, 0),
  modified_at: DateTime(2024, 7, 25, 14, 15, 30, 0),
)
```

**Expected Complete Output:**
```ics
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:full123task456@todo-md-sync
DTSTAMP:20240725T141530Z
CREATED:20240724T103000Z
LAST-MODIFIED:20240725T141530Z
SUMMARY:Complete project phase: review\, test & deploy
STATUS:NEEDS-ACTION
CATEGORIES:Projects
LOCATION:computer
DTSTART;VALUE=DATE:20240801
DUE;VALUE=DATE:20240815
DESCRIPTION:Review code changes\nRun full test suite\nDeploy to staging first\nGet approval before production
END:VTODO
END:VCALENDAR
```

**Comprehensive Validation:**
- ✅ All fields properly mapped and formatted
- ✅ Text escaping applied correctly
- ✅ Date formatting consistent
- ✅ Multi-line description properly handled
- ✅ Timestamps reflect different created/modified times

## File Output Tests {#file-output-tests}

### Test 14: Filename Generation
**Input UID:** `"abc123def456@todo-md-sync"`

**Expected Filename:** `abc123def456.ics`

**Validation:**
- ✅ UID prefix (before @) used as filename
- ✅ .ics extension appended
- ✅ Domain part (@todo-md-sync) removed

### Test 15: File Content Integrity
**Test Process:**
1. Generate iCalendar content for TodoItem
2. Write to file
3. Read file back
4. Verify content matches expected output exactly

**Validation:**
- ✅ No extra whitespace or line endings
- ✅ Character encoding preserved (UTF-8)
- ✅ File is valid iCalendar format

## CalDAV Compatibility Tests {#standards-compliance}

### Test 16: Standards Compliance
**Validation Criteria:**
- ✅ RFC 5545 compliant iCalendar format
- ✅ All required VTODO properties present
- ✅ Proper property parameter syntax
- ✅ Valid timestamp formats

### Test 17: Common CalDAV Client Testing
**Test with various clients:**
- ✅ Apple Calendar/Reminders import
- ✅ Google Calendar task import
- ✅ Thunderbird/Lightning compatibility
- ✅ CalDAV-sync Android app compatibility

### Test 18: vdirsyncer Integration
**Test Process:**
1. Generate .ics files from TodoItems
2. Configure vdirsyncer with test CalDAV server
3. Sync files to server
4. Verify successful sync without errors
5. Verify tasks appear correctly in CalDAV client

## Error Handling Tests {#error-handling-tests}

### Test 19: Invalid DateTime Input
**Input:**
```gleam
TodoItem(
  created_at: invalid_datetime, // Simulated invalid datetime
  // ... other fields
)
```

**Expected Behavior:**
- Should gracefully handle invalid datetime
- May use current time as fallback
- Must not produce invalid iCalendar output

### Test 20: Extremely Long Text
**Input:**
```gleam
TodoItem(
  summary: String.repeat("Very long text ", 1000), // 15,000 chars
  notes: [String.repeat("Long note ", 500)], // 5,000 chars
  // ... other fields
)
```

**Expected Behavior:**
- ✅ Handle large text without truncation (unless explicitly configured)
- ✅ Maintain proper escaping throughout
- ✅ Generate valid iCalendar despite size

### Test 21: Empty/Nil Fields Handling {#empty-nil-fields-handling}
**Input:**
```gleam
TodoItem(
  summary: "", // Empty summary
  context: None,
  notes: [],
  section: "",
  // ... other fields
)
```

**Expected Behavior:**
- ✅ Empty summary should have fallback (e.g., "Untitled")
- ✅ Missing optional fields properly omitted from output
- ✅ Still generate valid iCalendar structure

## Performance Tests {#batch-generation}

### Test 22: Batch Generation
**Input:** List of 1000 TodoItems

**Expected Behavior:**
- ✅ Process all items efficiently
- ✅ Generate consistent output for identical items
- ✅ Memory usage remains reasonable
- ✅ No significant performance degradation

### Test 23: Concurrent Generation
**Test:** Generate multiple .ics files concurrently

**Expected Behavior:**
- ✅ Thread-safe operation (if applicable)
- ✅ No file corruption from concurrent writes
- ✅ All files generated successfully

## Regression Tests

### Test 24: Format Stability
**Requirement:** Same TodoItem input must produce identical iCalendar output across versions

**Test Process:**
1. Define reference TodoItem
2. Generate iCalendar output
3. Store as golden file
4. Compare all future outputs against golden file

**Validation:**
- ✅ Byte-for-byte identical output
- ✅ No unintended format changes
- ✅ Stable field ordering

---

*These test specifications define the exact expected behavior of the VTodoGenerator module. Implementation must pass all these tests to ensure CalDAV compatibility and standards compliance.*