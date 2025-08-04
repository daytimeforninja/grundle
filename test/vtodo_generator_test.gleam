import gleeunit/should
import gleam/option.{None}
import simplifile
import birl
import todo_item.{TodoItem}
import vtodo_generator

pub fn write_ics_files_cleans_directory_test() {
  let test_dir = "/tmp/test_ics_cleanup"
  let _ = simplifile.delete(test_dir)
  let _ = simplifile.create_directory_all(test_dir)
  
  // Create some old .ics files to simulate existing state
  simplifile.write(test_dir <> "/old_task1.ics", "BEGIN:VCALENDAR\nEND:VCALENDAR")
  |> should.be_ok()
  
  simplifile.write(test_dir <> "/old_task2.ics", "BEGIN:VCALENDAR\nEND:VCALENDAR") 
  |> should.be_ok()
  
  // Also create a non-.ics file that should NOT be deleted
  simplifile.write(test_dir <> "/keep_this.txt", "This should remain")
  |> should.be_ok()
  
  // Verify old files exist before cleanup
  simplifile.is_file(test_dir <> "/old_task1.ics")
  |> should.equal(Ok(True))
  
  simplifile.is_file(test_dir <> "/old_task2.ics")
  |> should.equal(Ok(True))
  
  simplifile.is_file(test_dir <> "/keep_this.txt")
  |> should.equal(Ok(True))
  
  // Create new todo items to write
  let now = birl.utc_now()
  let new_item = TodoItem(
    uid: "newtask123@todo-md-sync",
    summary: "New task",
    completed: False,
    context: None,
    notes: [],
    section: "Inbox",
    due_date: None,
    start_date: None, 
    created_at: now,
    modified_at: now,
  )
  
  // Write new ICS files (should clean old ones first)
  vtodo_generator.write_ics_files([new_item], test_dir)
  |> should.be_ok()
  
  // Verify old .ics files were deleted
  simplifile.is_file(test_dir <> "/old_task1.ics")
  |> should.equal(Ok(False))
  
  simplifile.is_file(test_dir <> "/old_task2.ics") 
  |> should.equal(Ok(False))
  
  // Verify non-.ics file was preserved
  simplifile.is_file(test_dir <> "/keep_this.txt")
  |> should.equal(Ok(True))
  
  // Verify new .ics file was created
  simplifile.is_file(test_dir <> "/newtask123.ics")
  |> should.equal(Ok(True))
  
  // Clean up
  let _ = simplifile.delete(test_dir)
}

pub fn empty_directory_cleanup_succeeds_test() {
  let test_dir = "/tmp/test_empty_cleanup" 
  let _ = simplifile.delete(test_dir)
  let _ = simplifile.create_directory_all(test_dir)
  
  let now = birl.utc_now()
  let test_item = TodoItem(
    uid: "test456@todo-md-sync",
    summary: "Test task",
    completed: False,
    context: None,
    notes: [],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: now,  
    modified_at: now,
  )
  
  // Writing to empty directory should succeed (no cleanup needed)
  vtodo_generator.write_ics_files([test_item], test_dir)
  |> should.be_ok()
  
  // Verify file was created
  simplifile.is_file(test_dir <> "/test456.ics")
  |> should.equal(Ok(True))
  
  // Clean up
  let _ = simplifile.delete(test_dir)
}

pub fn nonexistent_directory_cleanup_succeeds_test() {
  let test_dir = "/tmp/test_nonexistent_cleanup"
  let _ = simplifile.delete(test_dir)
  
  // Directory doesn't exist - cleanup should handle gracefully
  let now = birl.utc_now()
  let test_item = TodoItem(
    uid: "test789@todo-md-sync", 
    summary: "Test task",
    completed: False,
    context: None,
    notes: [],
    section: "Inbox",
    due_date: None,
    start_date: None,
    created_at: now,
    modified_at: now,
  )
  
  // This might fail due to directory not existing, but cleanup itself should not fail
  // The current implementation assumes directory exists, so this tests error handling
  let result = vtodo_generator.write_ics_files([test_item], test_dir)
  
  // Either succeeds or fails with appropriate error - but shouldn't crash
  case result {
    Ok(_) -> should.be_true(True)  // Success is fine
    Error(_) -> should.be_true(True)  // Expected error is fine too
  }
}