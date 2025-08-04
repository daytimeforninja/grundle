# Integrating grundle with vdirsyncer

This guide walks through setting up grundle with vdirsyncer for CalDAV synchronization.

## Prerequisites

1. Install vdirsyncer:
   ```bash
   # With Nix
   nix-env -iA nixpkgs.vdirsyncer
   
   # Or with pip
   pip install vdirsyncer
   ```

2. Install grundle (you've already done this)

## Step 1: Configure vdirsyncer

Create or edit `~/.config/vdirsyncer/config`:

```ini
[general]
status_path = "~/.vdirsyncer/status/"

# Local storage for tasks
[storage tasks_local]
type = "filesystem"
path = "~/.calendars/tasks/"
fileext = ".ics"

# Remote CalDAV storage (example with Nextcloud)
[storage tasks_remote]
type = "caldav"
url = "https://your-server.com/remote.php/dav/calendars/username/tasks/"
username = "your-username"
password.fetch = ["command", "pass", "nextcloud"]  # or use password = "your-password"

# Sync pair
[pair tasks]
a = "tasks_local"
b = "tasks_remote"
collections = ["from a", "from b"]
metadata = ["displayname", "color"]
```

### For other CalDAV providers:

**Google Calendar:**
```ini
[storage tasks_remote]
type = "google_calendar"
token_file = "~/.vdirsyncer/google_token"
client_id = "your-client-id"
client_secret = "your-client-secret"
```

**iCloud:**
```ini
[storage tasks_remote]
type = "caldav"
url = "https://caldav.icloud.com/"
username = "your-apple-id@icloud.com"
password = "app-specific-password"
```

**Fastmail:**
```ini
[storage tasks_remote]
type = "caldav"
url = "https://caldav.fastmail.com/"
username = "your-email@fastmail.com"
password = "app-specific-password"
```

## Step 2: Initialize vdirsyncer

```bash
# Create directories
mkdir -p ~/.calendars/tasks/
mkdir -p ~/.vdirsyncer/status/

# Discover collections
vdirsyncer discover

# Initial sync
vdirsyncer sync
```

## Step 3: Create your todo.md file

Create `~/todo.md` with your GTD-style tasks:

```markdown
# GTD Todo List

## Next Actions
- [ ] Review project documentation @computer
- [ ] Call dentist for appointment @phone
- [ ] Buy groceries @errands

## Projects
- [ ] Website redesign @computer
  - Research modern design trends
  - Create mockups

## Waiting For
- [ ] Response from client about proposal @waiting

## Someday/Maybe
- [ ] Learn Spanish @personal
```

## Step 4: Set up the sync workflow

### Option A: Manual sync

```bash
# Convert markdown to ICS files
grundle ~/todo.md --to-ics ~/.calendars/tasks/

# Sync with CalDAV server
vdirsyncer sync

# Convert back after remote changes
grundle --from-ics ~/.calendars/tasks/ ~/todo.md
```

### Option B: Create sync scripts

Create `~/bin/todo-push`:
```bash
#!/usr/bin/env bash
set -e

TODO_FILE="${TODO_FILE:-$HOME/todo.md}"
CALENDAR_DIR="${CALENDAR_DIR:-$HOME/.calendars/tasks/}"

echo "📤 Pushing todos to CalDAV..."

# Convert markdown to ICS
grundle "$TODO_FILE" --to-ics "$CALENDAR_DIR"

# Sync with server
vdirsyncer sync

echo "✅ Push complete!"
```

Create `~/bin/todo-pull`:
```bash
#!/usr/bin/env bash
set -e

TODO_FILE="${TODO_FILE:-$HOME/todo.md}"
CALENDAR_DIR="${CALENDAR_DIR:-$HOME/.calendars/tasks/}"

echo "📥 Pulling todos from CalDAV..."

# Sync with server
vdirsyncer sync

# Convert ICS back to markdown
grundle --from-ics "$CALENDAR_DIR" "$TODO_FILE"

echo "✅ Pull complete!"
```

Make them executable:
```bash
chmod +x ~/bin/todo-push ~/bin/todo-pull
```

### Option C: Automated sync with systemd (Linux)

Create `~/.config/systemd/user/todo-sync.service`:
```ini
[Unit]
Description=Sync todo.md with CalDAV

[Service]
Type=oneshot
ExecStart=/home/your-username/bin/todo-push
ExecStart=/home/your-username/bin/todo-pull
```

Create `~/.config/systemd/user/todo-sync.timer`:
```ini
[Unit]
Description=Sync todos every 30 minutes

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
```

Enable the timer:
```bash
systemctl --user enable --now todo-sync.timer
```

### Option D: Git hooks (if using git for todo.md)

Create `.git/hooks/pre-commit`:
```bash
#!/usr/bin/env bash
grundle todo.md --to-ics ~/.calendars/tasks/
vdirsyncer sync
```

Create `.git/hooks/post-merge`:
```bash
#!/usr/bin/env bash
vdirsyncer sync
grundle --from-ics ~/.calendars/tasks/ todo.md
```

## Step 5: Mobile access

With your tasks synced to CalDAV, you can use any CalDAV-compatible app:

- **iOS**: Apple Reminders, Tasks.org, 2Do
- **Android**: Tasks.org, DAVx5 + any task app, OpenTasks
- **Web**: Nextcloud Tasks, Fastmail, etc.

**iOS Compatibility**: grundle automatically handles iOS Reminders format differences (list name prefixes, timestamp formats) for seamless bidirectional sync with Apple devices.

## Troubleshooting

1. **Conflicting UIDs**: grundle generates stable UIDs based on task content. If you get conflicts, try:
   ```bash
   rm ~/.calendars/tasks/*.ics
   grundle ~/todo.md --to-ics ~/.calendars/tasks/
   vdirsyncer sync
   ```

2. **Date parsing**: grundle uses intelligent date parsing. Dates like "7/25" will use the current year if the date hasn't passed, or next year if it has.

3. **Special characters**: grundle properly escapes special characters in both directions.

4. **Debugging vdirsyncer**:
   ```bash
   vdirsyncer -v DEBUG sync
   ```

## Best Practices

1. **Backup your todo.md**: Keep it in git or another backup system
2. **Test first**: Try with a test CalDAV account before using your main one
3. **One-way sync**: If you only edit on one device, consider one-way sync
4. **Regular pulls**: Pull changes before editing to avoid conflicts

## Example Full Workflow

```bash
# Morning: Pull any overnight changes
todo-pull

# Edit your todos in your favorite editor
vim ~/todo.md

# Push changes when done
todo-push

# Or use git if you track todo.md
git add todo.md
git commit -m "Updated tasks"
# Pre-commit hook handles the sync
```