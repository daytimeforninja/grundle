# Roundtrip Conversion Test Specification

## Test Philosophy

Roundtrip tests validate the most critical requirement: **semantic preservation**. A task should maintain its essential meaning and properties through the complete conversion cycle: `markdown → VTODO → markdown`.

Perfect syntactic preservation is not required (formatting may change), but semantic equivalence must be maintained.

## Semantic Equivalence Definition

Two TodoItems are semantically equivalent if they have identical:
- Task completion status
- Core task description (summary)
- Context assignment
- Due and start dates
- Sub-notes content (order preserved)
- Section assignment

## Basic Roundtrip Tests

### Test 1: Simple Task Roundtrip
**Input Markdown:**
```markdown
- [ ] Simple task
```

**Conversion Flow:**
```
markdown → TodoItem → VTODO → TodoItem → markdown
```

**Expected Output Markdown:**
```markdown
# GTD Todo List

## Inbox
- [ ] Simple task

---
*Last Weekly Review: [To be filled]*
*GTD Contexts: @computer, @home, @errands, @calls, @anywhere, @waiting, @shopping, @yurt*
```

**Validation:**
- ✅ Task completion status preserved (uncompleted)
- ✅ Summary preserved exactly
- ✅ Assigned to default section (Inbox)
- ✅ Standard GTD header/footer added

### Test 2: Completed Task Roundtrip
**Input Markdown:**
```markdown
- [x] Completed task
```

**Expected Output Difference:**
```markdown
## Inbox
- [x] Completed task
```

**Validation:**
- ✅ Completion status (x) preserved through VTODO STATUS field

### Test 3: Task with Context Roundtrip
**Input Markdown:**
```markdown
- [ ] Build server @computer
```

**Expected Output:**
```markdown
## Inbox
- [ ] Build server @computer
```

**Validation:**
- ✅ Context extracted to LOCATION and restored to summary
- ✅ @ prefix preserved in final output

## Section Preservation Tests

### Test 4: Multiple Sections Roundtrip
**Input Markdown:**
```markdown
## Next Actions
- [ ] First task @home

## Projects
- [ ] Second task @computer

## Waiting For
- [ ] Third task @waiting
```

**Expected Output Markdown:**
```markdown
# GTD Todo List

## Next Actions
- [ ] First task @home

## Projects
- [ ] Second task @computer

## Waiting For
- [ ] Third task @waiting

---
*Last Weekly Review: [To be filled]*
*GTD Contexts: @computer, @home, @errands, @calls, @anywhere, @waiting, @shopping, @yurt*
```

**Validation:**
- ✅ All three sections preserved via CATEGORIES field
- ✅ Tasks remain in correct sections
- ✅ Section order normalized to canonical order
- ✅ Contexts preserved for all tasks

### Test 5: Section Order Normalization
**Input Markdown (non-canonical order):**
```markdown
## Someday/Maybe
- [ ] Future task

## Inbox
- [ ] Unorganized task

## Next Actions
- [ ] Urgent task
```

**Expected Output (canonical order):**
```markdown
# GTD Todo List

## Inbox
- [ ] Unorganized task

## Next Actions
- [ ] Urgent task

## Someday/Maybe  
- [ ] Future task

---
*Last Weekly Review: [To be filled]*
*GTD Contexts: @computer, @home, @errands, @calls, @anywhere, @waiting, @shopping, @yurt*
```

**Validation:**
- ✅ Tasks preserved in semantically correct sections
- ✅ Order normalized to Inbox → Next Actions → Someday/Maybe
- ✅ Task content unchanged

## Date Handling Roundtrip Tests

### Test 6: Due Date Roundtrip
**Input Markdown:**
```markdown
- [ ] Important deadline due 7/25
```

**Expected Output:**
```markdown
## Inbox
- [ ] Important deadline - Due 7/25
```

**Validation:**
- ✅ Due date extracted to DUE field in VTODO
- ✅ Date restored to summary in output
- ✅ MM/DD format preserved
- ✅ "due" text pattern may change to "Due" (normalization acceptable)

### Test 7: Start Date Roundtrip  
**Input Markdown:**
```markdown
- [ ] Scheduled work - Scheduled for 12/1
```

**Expected Output:**
```markdown
## Inbox
- [ ] Scheduled work - Scheduled for 12/1
```

**Validation:**
- ✅ Start date preserved through DTSTART field
- ✅ Date format maintained
- ✅ Scheduling language preserved

### Test 8: Both Dates Roundtrip
**Input Markdown:**
```markdown
- [ ] Project phase - Scheduled for 11/15, Due 11/30
```

**Expected Output:**
```markdown
## Inbox
- [ ] Project phase - Scheduled for 11/15, Due 11/30
```

**Validation:**
- ✅ Both dates preserved independently
- ✅ Date relationship maintained (start before due)
- ✅ Comma separation preserved

## Sub-Notes Roundtrip Tests

### Test 9: Single Note Roundtrip
**Input Markdown:**
```markdown
- [ ] Main task
  - Important note
```

**Expected Output:**
```markdown
## Inbox
- [ ] Main task
  - Important note
```

**Validation:**
- ✅ Note preserved through DESCRIPTION field
- ✅ Indentation format maintained
- ✅ Note content unchanged

### Test 10: Multiple Notes Roundtrip
**Input Markdown:**
```markdown
- [ ] Complex task
  - First note
  - Second note  
  - Third note with details
```

**Expected Output:**
```markdown
## Inbox
- [ ] Complex task
  - First note
  - Second note
  - Third note with details
```

**Validation:**
- ✅ All notes preserved in order
- ✅ Multi-line DESCRIPTION properly parsed back
- ✅ Note content integrity maintained

## Complex Document Roundtrip Tests

### Test 11: Full GTD Document Roundtrip
**Input Markdown:**
```markdown
# GTD Todo List

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
- [ ] Learn French @anywhere

---
*Last Weekly Review: 2024-07-20*
*GTD Contexts: @computer, @home, @errands, @calls, @anywhere, @waiting, @shopping, @yurt*
```

**Expected Output:**
```markdown
# GTD Todo List

## Inbox
- [ ] Process later @computer

## Next Actions
- [ ] Build mx2 server @computer
- [x] Fix bathroom grout @home
- [ ] Meeting prep - Due 7/25 @office
  - Prepare agenda
  - Book room

## Projects
- [ ] Website redesign @computer
  - Research frameworks
  - Create mockups

## Waiting For
- [ ] Lawyer response @waiting

## Someday/Maybe
- [ ] Learn French @anywhere

---
*Last Weekly Review: [To be filled]*
*GTD Contexts: @computer, @home, @errands, @calls, @anywhere, @waiting, @shopping, @yurt*
```

**Comprehensive Validation:**
- ✅ All 7 tasks preserved with correct completion status
- ✅ All contexts maintained (@computer, @home, @office, @waiting, @anywhere)
- ✅ Due date preserved and reformatted consistently
- ✅ 4 sub-notes preserved in correct order
- ✅ All 5 sections maintained
- ✅ Footer regenerated (acceptable change)

## Special Characters and Edge Cases

### Test 12: Unicode and Special Characters Roundtrip
**Input Markdown:**
```markdown
- [ ] Task with émojis 🚀 and chars: @café
- [ ] Task, with; special & symbols @computer
```

**Expected Output:**
```markdown
## Inbox
- [ ] Task with émojis 🚀 and chars: @café
- [ ] Task, with; special & symbols @computer
```

**Validation:**
- ✅ Unicode characters preserved through iCalendar escaping
- ✅ Emoji maintained in VTODO and back to markdown
- ✅ Special punctuation preserved (@café context)
- ✅ iCalendar escaping (commas, semicolons) properly reversed

### Test 13: Newlines in Notes Roundtrip
**Input Markdown:**
```markdown
- [ ] Task with complex notes
  - First line of note
  - Second line of note
  - Note with embedded content
```

**Expected Output:**
```markdown
## Inbox
- [ ] Task with complex notes
  - First line of note
  - Second line of note  
  - Note with embedded content
```

**Validation:**
- ✅ Multi-line DESCRIPTION field properly split back to individual notes
- ✅ Note boundaries preserved (each line = one note)
- ✅ No content loss in conversion

## Error Recovery and Robustness

### Test 14: Malformed Input Recovery
**Input Markdown (with errors):**
```markdown
- [ ] Good task @home
- [] Bad checkbox syntax
- [ ] Another good task @computer
- [invalid] Bad completion marker
- [ ] Final good task @office
```

**Expected Output:**
```markdown
## Inbox
- [ ] Good task @home
- [ ] Another good task @computer
- [ ] Final good task @office
```

**Validation:**
- ✅ Valid tasks preserved through conversion
- ✅ Invalid syntax gracefully ignored (no crash)
- ✅ Partial document processing maintains valid content

### Test 15: UID Stability Across Roundtrips
**Test Process:**
1. Parse original markdown to TodoItem list
2. Record all UIDs
3. Convert to VTODO and back to TodoItem
4. Verify UIDs remain identical

**Validation:**
- ✅ Same content produces same UID across conversions
- ✅ UID stability enables proper CalDAV sync
- ✅ No UID collision between different tasks

## Performance and Scale Tests

### Test 16: Large Document Roundtrip
**Input:** 500+ tasks across all sections with various features

**Expected Behavior:**
- ✅ All tasks processed successfully
- ✅ No memory exhaustion during conversion
- ✅ Processing time remains reasonable
- ✅ Output format remains consistent

### Test 17: Deep Notes Structure Roundtrip
**Input:** Tasks with 50+ sub-notes each

**Expected Behavior:**
- ✅ All notes preserved in order
- ✅ No note truncation or loss
- ✅ Proper DESCRIPTION field handling

## Integration Tests

### Test 18: vdirsyncer Workflow Simulation
**Complete Workflow:**
1. Start with `todo.md`
2. Convert to `.ics` files in directory
3. Simulate CalDAV sync (file modifications)
4. Convert back to `todo.md`
5. Compare semantic content

**Expected Behavior:**
- ✅ Survives complete vdirsyncer workflow
- ✅ CalDAV sync doesn't break conversion
- ✅ External modifications handled gracefully

### Test 19: Multiple Roundtrip Cycles
**Test Process:**
1. Start with complex `todo.md`
2. Perform 10 complete roundtrip cycles
3. Compare final output to original

**Expected Behavior:**
- ✅ No progressive data loss
- ✅ Semantic equivalence maintained across cycles
- ✅ No format drift or corruption

## Acceptance Criteria

A roundtrip conversion system passes all tests if:

1. **Semantic Preservation**: Core task information maintained
2. **Data Integrity**: No loss of structured data (dates, notes, contexts)
3. **Format Stability**: Consistent output format across conversions
4. **Error Resilience**: Graceful handling of malformed input
5. **Performance**: Reasonable processing time for realistic document sizes
6. **Standards Compliance**: Generated VTODO format works with CalDAV clients

## Golden File Testing

### Test 20: Regression Prevention
**Setup:**
- Define canonical test documents
- Store expected outputs as "golden files"
- Compare all future outputs against golden files

**Validation:**
- ✅ Detect unintended changes in conversion behavior
- ✅ Ensure format stability across code changes
- ✅ Maintain backward compatibility

---

*These roundtrip tests represent the ultimate validation of the conversion system. Passing all roundtrip tests proves the system maintains semantic integrity and is suitable for production use with CalDAV synchronization.*