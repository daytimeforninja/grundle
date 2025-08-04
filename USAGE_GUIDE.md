# Todo Converter Usage Guide

## Installation

### 1. Build the Gleam Project
```bash
cd /path/to/grundle
gleam build
gleam export erlang-shipment
```

### 2. Create Executable Script
```bash
# Create a wrapper script for easy execution
cat > grundle << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
gleam run -- "$@"
EOF

chmod +x grundle
```

### 3. Add to PATH (Optional)
```bash
# Add to your ~/.bashrc or ~/.zshrc
export PATH="$PATH:/path/to/grundle"
```

## Basic Usage

### Command Syntax
```bash
# Convert markdown to ICS files
grundle todo.md --to-ics output_directory/

# Convert ICS files back to markdown  
grundle --from-ics input_directory/ todo.md
```

## Workflow Examples

### Scenario 1: Local-Only Usage

**Your todo.md:**
```markdown
# GTD Todo List

## Next Actions
- [ ] Build out mx2 server @computer
- [ ] Check garage maintenance @home
- [ ] Meeting prep due 7/25 @office
  - Prepare agenda
  - Book room

## Waiting For
- [ ] Lawyer response @waiting
```

**Convert to see VTODO format:**
```bash
# Create ICS files to inspect CalDAV format
grundle todo.md --to-ics ./ics-output/
ls ./ics-output/
# Results:
# a84cb35cde77.ics  (mx2 server task)
# b91df46ce88a.ics  (garage task) 
# c78776b060d2.ics  (meeting task)
# d9aace978771.ics  (lawyer task)
```

**Check a generated file:**
```bash
cat ./ics-output/c78776b060d2.ics
```
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
SUMMARY:Meeting prep
STATUS:NEEDS-ACTION
CATEGORIES:Next Actions
LOCATION:office
DUE;VALUE=DATE:20240725
DESCRIPTION:Prepare agenda\nBook room
END:VTODO
END:VCALENDAR
```

### Scenario 2: CalDAV Synchronization with vdirsyncer

**1. Set up vdirsyncer configuration (~/.config/vdirsyncer/config):**
```ini
[general]
status_path = "~/.vdirsyncer/status/"

[pair todos]
a = "todos_local"
b = "todos_remote"
collections = ["from a", "from b"]

[storage todos_local]
type = "filesystem"
path = "~/.calendars/todos/"
fileext = ".ics"

[storage todos_remote]
type = "caldav"
url = "https://your-caldav-server.com/calendars/username/todos/"
username = "your-username"
password = "your-password"
```

**2. Initialize vdirsyncer:**
```bash
vdirsyncer discover
vdirsyncer metasync
```

**3. Daily workflow:**
```bash
# Morning: Get latest from CalDAV server
vdirsyncer sync
grundle --from-ics ~/.calendars/todos/ todo.md

# Edit your todo.md throughout the day
vim todo.md  # or your preferred editor

# Evening: Push changes to CalDAV server
grundle todo.md --to-ics ~/.calendars/todos/
vdirsyncer sync
```

### Scenario 3: Team Collaboration

**Setup shared CalDAV calendar:**
```bash
# Each team member runs:
grundle shared-todos.md --to-ics ~/.calendars/shared-todos/
vdirsyncer sync

# Others can pull updates:
vdirsyncer sync  
grundle --from-ics ~/.calendars/shared-todos/ shared-todos.md
```

**Collaborative workflow:**
1. Team maintains shared `team-todos.md` in version control
2. Each member converts to personal CalDAV for mobile/calendar integration
3. Updates flow: Git → markdown → ICS → CalDAV → mobile apps

## Advanced Usage Patterns

### Multiple Todo Collections

**Organize by context:**
```bash
# Work todos
grundle work-todos.md --to-ics ~/.calendars/work-todos/

# Personal todos  
grundle personal-todos.md --to-ics ~/.calendars/personal-todos/

# Project-specific todos
grundle project-x-todos.md --to-ics ~/.calendars/project-x/
```

### Automation Scripts

**Daily sync script (~/bin/sync-todos):**
```bash
#!/bin/bash
set -e

TODO_DIR="$HOME/Documents/todos"
CALDAV_DIR="$HOME/.calendars/todos"

echo "Syncing todos..."

# Pull from CalDAV
vdirsyncer sync
grundle --from-ics "$CALDAV_DIR" "$TODO_DIR/todo.md"

echo "✓ Downloaded latest todos to $TODO_DIR/todo.md"
echo "Edit your todos, then run 'push-todos' to sync back"
```

**Push script (~/bin/push-todos):**
```bash
#!/bin/bash
set -e

TODO_DIR="$HOME/Documents/todos" 
CALDAV_DIR="$HOME/.calendars/todos"

echo "Pushing todos..."

# Convert and push to CalDAV
grundle "$TODO_DIR/todo.md" --to-ics "$CALDAV_DIR"
vdirsyncer sync

echo "✓ Pushed todos to CalDAV server"
```

**Make executable:**
```bash
chmod +x ~/bin/sync-todos ~/bin/push-todos
```

### Integration with Text Editors

**Vim integration (~/.vimrc):**
```vim
" Quick todo sync commands
command! TodoSync !sync-todos
command! TodoPush !push-todos

" Auto-sync on todo.md save
autocmd BufWritePost todo.md !push-todos &
```

**VS Code tasks (.vscode/tasks.json):**
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Sync Todos",
            "type": "shell", 
            "command": "sync-todos",
            "group": "build"
        },
        {
            "label": "Push Todos",
            "type": "shell",
            "command": "push-todos", 
            "group": "build"
        }
    ]
}
```

## Mobile Integration

### iOS (via CalDAV)
1. Set up CalDAV account in iOS Settings → Mail → Accounts
2. Enable Reminders sync for the account
3. Your todos appear in the Reminders app with:
   - ✅ Completion status
   - 📅 Due dates  
   - 📍 Contexts as locations
   - 📝 Notes as descriptions

### Android (via CalDAV-Sync)
1. Install CalDAV-Sync app
2. Configure with your CalDAV server
3. Todos sync to calendar apps and task managers
4. OpenTasks or similar apps provide task-focused interface

## Troubleshooting

### Common Issues

**"Command not found" error:**
```bash
# Check if Gleam is installed
gleam --version

# Build the project
cd /path/to/grundle
gleam build

# Use full path if not in PATH
/path/to/grundle/grundle todo.md --to-ics ./output/
```

**vdirsyncer sync errors:**
```bash
# Check vdirsyncer status
vdirsyncer status

# Verify configuration  
vdirsyncer discover
vdirsyncer metasync

# Check CalDAV credentials
vdirsyncer sync --verbosity DEBUG
```

**Conversion errors:**
```bash
# Test with simple todo first
echo "- [ ] Test task" > test.md
grundle test.md --to-ics ./test-output/

# Check output for errors
ls -la ./test-output/
cat ./test-output/*.ics
```

### Validation

**Verify roundtrip conversion:**
```bash
# Original → ICS → Back to markdown
cp todo.md todo-original.md
grundle todo.md --to-ics ./temp-ics/
grundle --from-ics ./temp-ics/ todo-restored.md

# Compare (should be semantically equivalent)
diff todo-original.md todo-restored.md
```

**Check ICS file validity:**
```bash
# Install ical validation tool (varies by system)
# macOS: brew install libical
# Ubuntu: apt install libical-dev

# Validate generated ICS files
for file in ./output/*.ics; do
    echo "Validating $file..."
    # Tool-specific validation command
done
```

## Best Practices

### Todo.md Organization
- **Use consistent section headers**: Stick to GTD convention (Inbox, Next Actions, Projects, Waiting For, Someday/Maybe)
- **One line per task**: Don't break tasks across multiple lines  
- **Consistent context format**: Always use @context at end of line
- **Date format**: Use MM/DD format for due dates and scheduling

### Sync Frequency
- **Manual sync**: For careful control over changes
- **Automated sync**: Use cron jobs for regular updates
- **Pre-commit hooks**: Auto-push changes when committing todo.md to Git

### Backup Strategy
```bash
# Daily backup script
DATE=$(date +%Y%m%d)
cp todo.md "backups/todo-$DATE.md"
cp -r ~/.calendars/todos/ "backups/ics-$DATE/"
```

This converter bridges the gap between plain-text productivity and modern cross-device synchronization, letting you maintain your preferred text-based workflow while gaining the benefits of CalDAV integration.