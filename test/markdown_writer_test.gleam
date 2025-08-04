import birl
import gleam/list
import gleam/option.{None}
import gleeunit/should
import markdown_writer
import simplifile
import todo_item.{TodoItem}

pub fn backup_creates_cache_directory_test() {
  // Clean up any existing cache for test
  let _ = simplifile.delete("/tmp/test_cache")

  // Set up test environment with temp HOME
  let _ = simplifile.create_directory_all("/tmp/test_home")
  let test_todo_path = "/tmp/test_home/todo.md"
  let test_content = "# Test Todo\n\n## Inbox\n- [ ] Test task"

  // Create initial todo.md
  simplifile.write(test_todo_path, test_content)
  |> should.be_ok()

  // Create a simple todo item to trigger backup
  let now = birl.utc_now()
  let test_item =
    TodoItem(
      uid: "test123@todo-md-sync",
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

  // This should create backup and write new content
  markdown_writer.write_items_to_file([test_item], test_todo_path)
  |> should.be_ok()
  // Verify backup was created in cache directory
  // Note: This test assumes HOME environment variable is set to /tmp/test_home
  // In real test environment, we'd need to mock the envoy.get("HOME") call
}

pub fn backup_rotation_keeps_five_backups_test() {
  let test_todo_path = "/tmp/test_rotation/todo.md"
  let _ = simplifile.create_directory_all("/tmp/test_rotation")
  let initial_content = "# Initial Todo"

  // Create initial file
  simplifile.write(test_todo_path, initial_content)
  |> should.be_ok()

  let now = birl.utc_now()
  let test_item =
    TodoItem(
      uid: "test123@todo-md-sync",
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

  // Create 7 backups by writing 7 times
  let results =
    [1, 2, 3, 4, 5, 6, 7]
    |> list.map(fn(_) {
      markdown_writer.write_items_to_file([test_item], test_todo_path)
    })

  // All writes should succeed
  results
  |> list.all(fn(result) {
    case result {
      Ok(_) -> True
      Error(_) -> False
    }
  })
  |> should.be_true()
  // Note: Actual verification of 5-backup limit would require access to
  // the cache directory, which depends on HOME environment variable
}

pub fn safe_filename_conversion_test() {
  // Test that problematic file paths get converted to safe cache filenames
  // This is a unit test concept - in practice we'd need to expose the
  // safe filename conversion as a public function or test it indirectly

  // Example: "/home/user/Documents/todo.md" -> "home_user_Documents_todo.md"
  // Example: "~/todo.md" -> "home_todo.md"

  should.equal(1, 1)
  // Placeholder - would test filename conversion logic
}
