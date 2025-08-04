# Data Flow and Transformation Examples

## Overview

This document traces data through each transformation step with concrete examples, showing exactly how information flows from markdown to VTODO and back.

## Forward Flow: Markdown → VTODO

### Example 1: Complete Transformation Journey

**Input Markdown:**
```markdown
# GTD Todo List

## Next Actions
- [ ] Build out mx2 server @computer
- [x] Fix grout in shower @home
- [ ] Important meeting due 7/25 @office
  - Prepare agenda
  - Book conference room

## Waiting For
- [ ] Lawyer response (IN PROGRESS) @waiting
```

### Step 1: MarkdownParser → List(TodoItem)

**Parser Processing:**
```
Line: "## Next Actions"        → current_section = "Next Actions"
Line: "- [ ] Build out mx2..."  → new TodoItem, add to list
Line: "- [x] Fix grout..."      → new TodoItem (completed=True)
Line: "- [ ] Important..."      → new TodoItem with date extraction
Line: "  - Prepare agenda"      → append to previous item's notes
Line: "  - Book conference..."  → append to previous item's notes
Line: "## Waiting For"          → current_section = "Waiting For"
Line: "- [ ] Lawyer response..." → new TodoItem in new section
```

**Resulting TodoItem List:**
```gleam
[
  TodoItem(
    uid: "next actions:build out mx2 server" |> hash_to_uid(),
    summary: "Build out mx2 server",
    completed: False,
    context: Some("@computer"),
    notes: [],
    section: "Next Actions",
    due_date: None,
    start_date: None,
    created_at: DateTime(2024, 7, 24, 12, 0, 0, 0),
    modified_at: DateTime(2024, 7, 24, 12, 0, 0, 0),
  ),
  
  TodoItem(
    uid: "next actions:fix grout in shower" |> hash_to_uid(),
    summary: "Fix grout in shower",
    completed: True, // ← Checkbox [x] detected
    context: Some("@home"),
    notes: [],
    section: "Next Actions",
    due_date: None,
    start_date: None,
    created_at: DateTime(2024, 7, 24, 12, 0, 0, 0),
    modified_at: DateTime(2024, 7, 24, 12, 0, 0, 0),
  ),
  
  TodoItem(
    uid: "next actions:important meeting" |> hash_to_uid(),
    summary: "Important meeting", // ← "due 7/25" extracted
    completed: False,
    context: Some("@office"),
    notes: ["Prepare agenda", "Book conference room"], // ← Sub-notes
    section: "Next Actions",
    due_date: Some(Date(2024, 7, 25)), // ← Date parsed
    start_date: None,
    created_at: DateTime(2024, 7, 24, 12, 0, 0, 0),
    modified_at: DateTime(2024, 7, 24, 12, 0, 0, 0),
  ),
  
  TodoItem(
    uid: "waiting for:lawyer response (in progress)" |> hash_to_uid(),
    summary: "Lawyer response (IN PROGRESS)",
    completed: False,
    context: Some("@waiting"),
    notes: [],
    section: "Waiting For",
    due_date: None,
    start_date: None,
    created_at: DateTime(2024, 7, 24, 12, 0, 0, 0),
    modified_at: DateTime(2024, 7, 24, 12, 0, 0, 0),
  ),
]
```

### Step 2: VTodoGenerator → iCalendar Files

**TodoItem → VTODO Transformation:**

**Item 1 (mx2 server):**
```gleam
TodoItem(summary: "Build out mx2 server", context: Some("@computer"), ...)
```
↓
```ics
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:a84cb35cde77@todo-md-sync
DTSTAMP:20240724T120000Z
CREATED:20240724T120000Z
LAST-MODIFIED:20240724T120000Z
SUMMARY:Build out mx2 server
STATUS:NEEDS-ACTION
CATEGORIES:Next Actions
LOCATION:computer
END:VTODO
END:VCALENDAR
```

**Item 2 (grout - completed):**
```gleam
TodoItem(summary: "Fix grout in shower", completed: True, ...)
```
↓
```ics
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:b91df46ce88a@todo-md-sync
DTSTAMP:20240724T120000Z
CREATED:20240724T120000Z
LAST-MODIFIED:20240724T120000Z
SUMMARY:Fix grout in shower
STATUS:COMPLETED
CATEGORIES:Next Actions
LOCATION:home
END:VTODO
END:VCALENDAR
```

**Item 3 (meeting with date and notes):**
```gleam
TodoItem(
  summary: "Important meeting",
  due_date: Some(Date(2024, 7, 25)),
  notes: ["Prepare agenda", "Book conference room"],
  ...
)
```
↓
```ics
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Todo.md Sync//EN
CALSCALE:GREGORIAN
BEGIN:VTODO
UID:c78776b060d2@todo-md-sync
DTSTAMP:20240724T120000Z
CREATED:20240724T120000Z
LAST-MODIFIED:20240724T120000Z
SUMMARY:Important meeting
STATUS:NEEDS-ACTION
CATEGORIES:Next Actions
LOCATION:office
DUE;VALUE=DATE:20240725
DESCRIPTION:Prepare agenda\nBook conference room
END:VTODO
END:VCALENDAR
```

**Generated Files:**
- `a84cb35cde77.ics` (mx2 server task)
- `b91df46ce88a.ics` (grout task - completed)
- `c78776b060d2.ics` (meeting task with date and notes)
- `d9aace978771.ics` (lawyer task)

## Reverse Flow: VTODO → Markdown

### Step 1: VTodoParser → List(TodoItem)

**Reading .ics files back:**

**File: c78776b060d2.ics**
```ics
BEGIN:VTODO
UID:c78776b060d2@todo-md-sync
SUMMARY:Important meeting
STATUS:NEEDS-ACTION
CATEGORIES:Next Actions
LOCATION:office
DUE;VALUE=DATE:20240725
DESCRIPTION:Prepare agenda\nBook conference room
END:VTODO
```
↓
```gleam
TodoItem(
  uid: "c78776b060d2@todo-md-sync", // ← From UID field
  summary: "Important meeting", // ← From SUMMARY
  completed: False, // ← STATUS:NEEDS-ACTION → False
  context: Some("@office"), // ← LOCATION:office → @office
  notes: ["Prepare agenda", "Book conference room"], // ← DESCRIPTION split
  section: "Next Actions", // ← From CATEGORIES
  due_date: Some(Date(2024, 7, 25)), // ← DUE parsed
  start_date: None,
  created_at: parsed_from_CREATED,
  modified_at: parsed_from_LAST_MODIFIED,
)
```

### Step 2: MarkdownWriter → Final Markdown

**List(TodoItem) → Markdown Transformation:**

**Section Grouping:**
```gleam
by_section = %{
  "Next Actions" => [mx2_item, grout_item, meeting_item],
  "Waiting For" => [lawyer_item],
}
```

**Section Generation (Canonical Order):**
```gleam
section_order = ["Inbox", "Next Actions", "Projects", "Waiting For", "Someday/Maybe"]

// Process each section:
"Next Actions" → format_section("Next Actions", [mx2_item, grout_item, meeting_item])
"Waiting For" → format_section("Waiting For", [lawyer_item])
```

**Item Formatting Examples:**

**mx2_item formatting:**
```gleam
TodoItem(summary: "Build out mx2 server", completed: False, context: Some("@computer"))
```
↓
```markdown
- [ ] Build out mx2 server @computer
```

**grout_item formatting:**
```gleam
TodoItem(summary: "Fix grout in shower", completed: True, context: Some("@home"))
```
↓
```markdown
- [x] Fix grout in shower @home
```

**meeting_item formatting:**
```gleam
TodoItem(
  summary: "Important meeting",
  completed: False,
  context: Some("@office"),
  due_date: Some(Date(2024, 7, 25)),
  notes: ["Prepare agenda", "Book conference room"],
)
```
↓
```markdown
- [ ] Important meeting - Due 7/25 @office
  - Prepare agenda
  - Book conference room
```

**Final Generated Markdown:**
```markdown
# GTD Todo List

## Next Actions
- [ ] Build out mx2 server @computer
- [x] Fix grout in shower @home
- [ ] Important meeting - Due 7/25 @office
  - Prepare agenda
  - Book conference room

## Waiting For
- [ ] Lawyer response (IN PROGRESS) @waiting

---
*Last Weekly Review: [To be filled]*
*GTD Contexts: @computer, @home, @errands, @calls, @anywhere, @waiting, @shopping, @yurt*
```

## Data Transformation Details

### UID Generation and Stability

**Process:**
```gleam
content = "#{section}:#{summary}"
// Example: "Next Actions:Build out mx2 server"

hash = crypto.hash(:sha256, content)
// SHA256: a84cb35cde77f92b8c9d4e6f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b

uid = String.slice(hash, 0..11) <> "@todo-md-sync"  
// Result: "a84cb35cde77@todo-md-sync"
```

**Stability Verification:**
```gleam
// Same content always produces same UID
uid1 = generate_uid("Build out mx2 server", "Next Actions")
uid2 = generate_uid("Build out mx2 server", "Next Actions")
assert uid1 == uid2 // ✅ Always true

// Different content produces different UIDs
uid3 = generate_uid("Different task", "Next Actions")  
assert uid1 != uid3 // ✅ Always true
```

### Date Parsing and Formatting

**Forward Direction (Markdown → VTODO):**
```gleam
// Input: "Important meeting due 7/25"
summary_with_date = "Important meeting due 7/25"

// Regex extraction: ~r/(.+?)\s*-?\s*[Dd]ue\s+(\d{1,2}\/\d{1,2})/
matches = ["Important meeting due 7/25", "Important meeting", "7/25"]

clean_summary = "Important meeting"
date_string = "7/25"

// Parse MM/DD with year inference
[month_str, day_str] = String.split("7/25", "/")
month = 7, day = 25
year = 2024 // Current year

parsed_date = Date(2024, 7, 25)
```

**VTODO Format:**
```ics
DUE;VALUE=DATE:20240725
```

**Reverse Direction (VTODO → Markdown):**
```gleam
// Input: "DUE;VALUE=DATE:20240725"
due_field = "DUE;VALUE=DATE:20240725"

// Parse iCalendar date
date_str = "20240725" // Extract after colon
parsed = Date(2024, 7, 25) // Parse YYYYMMDD format

// Format back to MM/DD
formatted = "7/25"

// Append to summary
final_summary = "Important meeting - Due 7/25"
```

### Context Handling

**Forward Direction:**
```gleam
// Input: "Build server @computer"
task_line = "- [ ] Build server @computer"

// Regex: ~r/^-\s+\[([ x])\]\s+(.+?)(?:\s+(@\w+))?$/
matches = ["- [ ] Build server @computer", " ", "Build server", "@computer"]

summary = "Build server"    // Context removed from summary
context = "@computer"       // Context extracted separately
```

**VTODO Mapping:**
```ics
SUMMARY:Build server        <!-- Clean summary -->
LOCATION:computer           <!-- Context without @ prefix -->
```

**Reverse Direction:**
```gleam
// Input VTODO fields:
summary = "Build server"     // From SUMMARY
location = "computer"        // From LOCATION

// Reconstruction:
context = "@" <> location   // Add @ prefix back
final_line = "- [ ] #{summary} #{context}"
// Result: "- [ ] Build server @computer"
```

### Notes/Description Handling

**Forward Direction:**
```gleam
// Input notes from markdown:
notes = ["Prepare agenda", "Book conference room"]

// Join for DESCRIPTION field:
description = Enum.join(notes, "\\n")
// Result: "Prepare agenda\\nBook conference room"

// With escaping for iCalendar:
escaped = escape_text(description)
// Result: "Prepare agenda\\nBook conference room" (already safe)
```

**VTODO Format:**
```ics
DESCRIPTION:Prepare agenda\nBook conference room
```

**Reverse Direction:**
```gleam
// Input: "DESCRIPTION:Prepare agenda\nBook conference room"
description = "Prepare agenda\nBook conference room"

// Unescape iCalendar format:
unescaped = unescape_text(description)
// Result: "Prepare agenda\nBook conference room"

// Split back to individual notes:
notes = String.split(unescaped, "\n")
// Result: ["Prepare agenda", "Book conference room"]
```

**Markdown Output:**
```markdown
- [ ] Important meeting @office
  - Prepare agenda
  - Book conference room
```

## Error Handling and Data Integrity

### Invalid Date Handling
```gleam
// Input: "Task due 2/30" (invalid date)
case parse_date_string("2/30") do
  Ok(date) -> Some(date)
  Error(_) -> None  // Graceful degradation
end

// Result: TodoItem with due_date: None, clean summary preserved
```

### Malformed Checkbox Recovery
```gleam
// Input: "- [] Missing space"
case extract_task("- [] Missing space") do
  Ok(task_data) -> process_task(task_data)
  Error(_) -> // Skip line, continue parsing
end

// Parsing continues with next valid line
```

### Text Escaping Integrity
```gleam
// Forward: Special chars → iCalendar escaping
original = "Task, with; special: chars"
escaped = "Task\\, with\\; special: chars"

// Reverse: iCalendar escaping → original text  
unescaped = "Task, with; special: chars"

// Integrity check:
assert original == unescaped // ✅ Must be true
```

## Performance Considerations

### Memory Usage Pattern
```
Input markdown (10KB) 
  → TodoItem list (in-memory, ~50KB for complex tasks)
    → Multiple .ics files (total ~15KB on disk)
      → TodoItem list (in-memory, ~50KB)
        → Output markdown (10KB)
```

### Streaming vs. Batch Processing
- **Markdown parsing**: Line-by-line streaming (memory efficient)
- **TodoItem processing**: Batch processing (predictable memory usage)
- **File I/O**: Individual file operations (atomic writes)

---

*This data flow documentation provides concrete examples of how information transforms through each conversion step, ensuring implementation teams understand the exact expected behavior at each stage.*