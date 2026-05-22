# Godot-OS: In-Game Operating System Asset Spec

## Project Name

**Godot-OS**

Godot-OS is a reusable in-game operating system built inside Godot. It is intended to be used as a drop-in asset for games that need an interactive computer, laptop, terminal, office workstation, hacking interface, surveillance desk, spaceship console, mystery game desktop, or any other in-world computer UI.

The OS should feel like a clean, usable Linux distribution: snappy, practical, smooth, slightly boring by default, and easy for game developers to customize.

It should not feel like a cyberpunk hacking toy by default. It should feel like a normal, believable desktop environment that can be themed into many different game settings.

---

# Primary Goal

Build a feature-rich, modular, polished in-game computer operating system for Godot.

Godot-OS should include:

- Desktop environment
- Window manager
- App launcher
- Taskbar/panel
- File system simulation
- File manager
- Text editor
- Terminal
- Settings app
- Notifications
- Simple browser/mock intranet viewer
- Mail/messages app
- Media/image viewer
- Notes app
- Calculator
- Optional login/lock screen
- Developer customization API
- Save/load state support
- Theme system
- Game event hooks

The asset should be usable by game developers without needing to rewrite the entire system.

---

# Design Philosophy

Godot-OS should feel:

- Fast
- Smooth
- Responsive
- Familiar
- Minimal
- Useful
- Slightly plain
- Customizable
- Diegetic
- Modular
- Game-friendly

The default visual style should be close to a clean Linux desktop environment. Think somewhere between XFCE, GNOME, KDE Plasma, Pop!_OS, Linux Mint, and a generic corporate workstation.

Avoid over-stylizing the default. No heavy cyberpunk effects. No excessive glitching. No neon overload. No fake “hacker movie” nonsense unless enabled by a theme.

The default should feel like a template that a developer could easily adapt for:

- Modern office computer
- School computer
- Police workstation
- Research lab terminal
- Home desktop
- Space station computer
- Retro-futuristic PC
- Mystery game laptop
- Horror game workstation
- Government archive terminal
- Corporate intranet terminal

---

# Target Engine

Use **Godot 4.x**.

The project should be built using Godot’s UI system:

- Control nodes
- Containers
- Themes
- Signals
- Resources
- PackedScenes
- Autoloads where appropriate

The system should avoid unnecessary 3D inside the OS itself. The OS should be a reusable 2D UI scene that can be rendered directly or placed on a `ViewportTexture` for use on a 3D monitor, laptop, tablet, phone, control panel, or in-world terminal.

---

# Core Requirements

## 1. Drop-In Asset Structure

Godot-OS should be usable as a self-contained Godot asset.

Suggested structure:

```text
addons/godot_os/
  core/
    os_root.tscn
    os_root.gd
    boot/
    desktop/
    window_manager/
    app_system/
    filesystem/
    theme/
    state/
    events/
    input/
  apps/
    file_manager/
    text_editor/
    terminal/
    settings/
    browser/
    mail/
    notes/
    calculator/
    image_viewer/
    media_player/
    system_monitor/
  themes/
    default/
    dark/
    light/
    retro/
  examples/
    demo_computer.tscn
    demo_3d_monitor.tscn
    demo_story_terminal.tscn
  docs/
    customization.md
    app_creation.md
    game_integration.md
    virtual_filesystem.md
```

The consuming developer should be able to instance `os_root.tscn`, configure it, and start adding custom apps, files, themes, user accounts, events, and game-specific integrations.

---

# User Experience Requirements

## 2. Boot Flow

Godot-OS should support a configurable boot sequence.

Default boot should be quick and skippable.

Boot states:

- Powered off
- Booting
- Login screen
- Desktop ready
- Locked
- Shutting down
- Restarting

Boot sequence should include:

- Optional logo
- Optional loading text
- Optional fake system messages
- Optional progress bar
- Optional startup sound
- Optional delay settings

The default boot should feel practical, not dramatic.

Game developers should be able to configure:

- Whether login is required
- Boot duration
- Boot messages
- Logo
- Startup apps
- User profile name
- Wallpaper
- Available apps
- Whether boot can be skipped
- Whether boot only happens once per game/session

---

## 3. Login / Lock Screen

Include an optional login screen.

Features:

- Username display
- Password input
- Optional guest login
- Optional failed password attempts
- Optional password hint
- Optional locked account state
- Optional “forgot password” hook for gameplay
- Configurable correct password
- Configurable lock screen wallpaper
- Configurable user avatar
- Support for multiple fake users if needed

The login screen should support game events:

```gdscript
login_success(user_id)
login_failed(user_id, attempt_count)
login_locked(user_id)
guest_login()
os_locked()
os_unlocked(user_id)
```

Developers should be able to use the login flow for puzzles, gated narrative content, security terminals, private accounts, or simple ambience.

---

## 4. Desktop Environment

The desktop should include:

- Wallpaper
- Desktop icons
- Top or bottom panel
- App launcher
- Clock
- Notification indicator
- Open app indicators
- Optional system tray
- Optional right-click context menu
- Optional draggable desktop icons

Default desktop icons:

- Files
- Notes
- Browser
- Terminal
- Settings
- Trash

Desktop icons should be data-driven, not hardcoded.

Developers should be able to add desktop shortcuts through a config resource or script API.

Example shortcut config:

```json
{
  "id": "case_files_shortcut",
  "label": "Case Files",
  "icon": "res://game/ui/icons/folder_case.svg",
  "target_type": "folder",
  "target": "/home/user/Documents/Case Files",
  "show_on_desktop": true
}
```

---

## 5. Window Manager

The window manager is one of the most important parts of the asset.

Windows should feel smooth, responsive, and fun to use.

Required features:

- Open windows
- Close windows
- Minimize windows
- Maximize windows
- Restore windows
- Drag windows
- Resize windows
- Focus windows
- Bring focused window to front
- Taskbar integration
- Window title bars
- Window icons
- Basic keyboard shortcuts
- Configurable minimum sizes

Optional but desirable:

- Snap to screen edges
- Double-click title bar to maximize
- Smooth open/close animations
- Subtle shadows
- Window transparency setting
- Modal dialogs
- Confirmation dialogs
- Toast notifications
- Window state persistence
- Resizable border hit areas that feel forgiving
- Optional fake performance mode for older-style computers

The window manager should expose clean signals:

```gdscript
window_opened(app_id, window_id)
window_closed(app_id, window_id)
window_focused(app_id, window_id)
window_minimized(app_id, window_id)
window_maximized(app_id, window_id)
window_restored(app_id, window_id)
window_moved(app_id, window_id, position)
window_resized(app_id, window_id, size)
```

Windows should be built as reusable components. Apps should not need to implement their own title bar, close button, drag behavior, or resize logic unless they intentionally opt out.

---

## 6. App System

Apps should be modular.

Each app should be a `PackedScene` registered with an app manifest.

App manifest fields:

```gdscript
app_id
display_name
icon
scene_path
category
default_window_size
min_window_size
singleton
show_in_launcher
show_on_desktop
permissions
startup_args
```

Example app manifest:

```json
{
  "app_id": "files",
  "display_name": "Files",
  "icon": "res://addons/godot_os/apps/file_manager/icon.svg",
  "scene_path": "res://addons/godot_os/apps/file_manager/file_manager.tscn",
  "category": "System",
  "default_window_size": [820, 560],
  "min_window_size": [480, 320],
  "singleton": true,
  "show_in_launcher": true,
  "show_on_desktop": true
}
```

Godot-OS should include an `AppRegistry` service responsible for:

- Registering apps
- Launching apps
- Closing apps
- Passing arguments to apps
- Checking whether apps are installed/enabled
- Returning app metadata
- Supporting custom developer apps
- Enforcing singleton behavior where configured
- Supporting hidden apps used only by game events

Suggested API:

```gdscript
HermesOS.register_app(manifest: HermesOSAppManifest)
HermesOS.launch_app(app_id: String, args := {})
HermesOS.close_app(app_id: String)
HermesOS.is_app_installed(app_id: String) -> bool
HermesOS.get_app_manifest(app_id: String) -> HermesOSAppManifest
HermesOS.list_apps() -> Array
```

---

# Built-In Apps

## 7. File Manager

The file manager should simulate a simple filesystem.

Features:

- Folder tree
- File list
- Open files
- Rename files
- Delete files
- Move files
- Copy files
- Create folder
- Create text file
- File icons by type
- Search files
- Breadcrumb navigation
- Back/forward navigation
- Trash support
- Recent files
- Hidden files toggle
- Read-only files/folders
- Locked files/folders for gameplay

Supported default file types:

- `.txt`
- `.md`
- `.log`
- `.cfg`
- `.json`
- `.png`
- `.jpg`
- `.ogg`
- `.wav`
- `.mail`
- `.note`
- `.link`
- `.exe` or fake app shortcut

The file manager should use the simulated OS filesystem, not the real player machine filesystem.

Developers should be able to define files in data resources.

Example virtual filesystem:

```json
{
  "home": {
    "user": {
      "Documents": {
        "readme.txt": {
          "type": "text",
          "content": "Welcome to Godot-OS."
        },
        "notes.md": {
          "type": "markdown",
          "content": "# Notes\nThis is a simulated file."
        }
      },
      "Pictures": {},
      "Downloads": {},
      "Desktop": {}
    }
  }
}
```

File actions should emit signals:

```gdscript
file_opened(path)
file_created(path)
file_deleted(path)
file_renamed(old_path, new_path)
file_moved(old_path, new_path)
folder_opened(path)
locked_file_access_attempted(path)
```

---

## 8. Virtual Filesystem Service

Create a reusable virtual filesystem layer.

The filesystem should support:

- Directories
- Files
- File metadata
- File permissions
- Read-only flags
- Hidden flags
- File timestamps
- File icons
- File associations
- Soft links / shortcuts
- Trash/recycle behavior
- Save/load persistence

File object fields:

```gdscript
path
name
extension
type
content
created_at
modified_at
readonly
hidden
locked
password
metadata
```

The virtual filesystem should not touch the user’s real disk unless a developer explicitly writes their own importer/exporter.

Suggested API:

```gdscript
HermesOS.fs.exists(path: String) -> bool
HermesOS.fs.read_file(path: String) -> Variant
HermesOS.fs.write_file(path: String, content: Variant) -> void
HermesOS.fs.create_file(path: String, content := "") -> void
HermesOS.fs.create_folder(path: String) -> void
HermesOS.fs.delete(path: String) -> void
HermesOS.fs.move(from_path: String, to_path: String) -> void
HermesOS.fs.copy(from_path: String, to_path: String) -> void
HermesOS.fs.list(path: String) -> Array
HermesOS.fs.search(query: String, root := "/") -> Array
```

---

## 9. Text Editor

A simple text editor should be included.

Features:

- Open text files
- Edit text files
- Save files
- Save as
- Unsaved changes indicator
- Basic find text
- Monospace option
- Word wrap toggle
- Plain text support
- Markdown preview option if easy

The editor does not need to become a full IDE. It should be fast, clean, and practical.

Game uses:

- Reading notes
- Editing config files
- Viewing logs
- Writing commands or passwords
- Finding clues
- Letting players leave notes

---

## 10. Terminal

The terminal should be one of the best-feeling built-in apps.

It should look like a real terminal, but be safe, fake, and controlled.

Features:

- Command prompt
- Command history
- Tab completion if practical
- Fake current working directory
- Basic command parser
- Output area
- Scrollback
- Clear command
- Themed prompt
- Configurable username/hostname

Default commands:

```text
help
clear
ls
cd
pwd
cat
echo
date
whoami
hostname
open
run
mkdir
touch
rm
cp
mv
find
history
login
logout
reboot
shutdown
```

Optional commands:

```text
ping
ssh
scan
connect
decode
decrypt
unlock
sudo
journalctl
systemctl
top
ps
kill
```

Commands should be safe fake commands operating only on the virtual OS state.

The terminal should support developer-registered custom commands.

Example custom command registration:

```gdscript
HermesOS.terminal.register_command(
  "unlock_lab",
  Callable(self, "_on_unlock_lab_command"),
  "Unlocks the laboratory access panel."
)
```

Command result structure:

```gdscript
{
  "success": true,
  "output": "Door unlocked.",
  "event": "lab_door_unlocked"
}
```

The terminal should support game event hooks:

```gdscript
terminal_command_entered(command, args)
terminal_command_succeeded(command, args)
terminal_command_failed(command, args, reason)
terminal_custom_event(event_id, payload)
```

The terminal should feel authentic but approachable. It should not require real Linux knowledge unless the consuming game wants that.

---

## 11. Settings App

The settings app should allow players and developers to change simple OS preferences.

Default settings categories:

- Appearance
- Wallpaper
- Theme
- Accent color
- Font size
- Sound
- Notifications
- Date/time display
- Accessibility
- About system

Settings should be backed by OS state.

Changing settings should update the OS live where possible.

The settings app is also a good place for game-specific configuration screens.

Example settings:

```json
{
  "theme": "default_dark",
  "accent_color": "blue",
  "wallpaper": "res://game/wallpapers/default.png",
  "font_scale": 1.0,
  "sound_enabled": true,
  "notifications_enabled": true,
  "animations_enabled": true
}
```

---

## 12. Browser / Intranet Viewer

Godot-OS should include a fake browser or intranet viewer.

This should not be a real web browser.

It should display developer-defined fake pages, local HTML-like content, or simplified rich text pages.

Features:

- Address bar
- Back/forward buttons
- Reload button
- Fake bookmarks
- Page title
- Links
- Forms if practical
- Search page if practical
- Error pages
- Developer-defined fake domains

Example fake URLs:

```text
home.local
intranet.local
archive.local
mail.local
company.local/login
casefiles.local/search
```

The browser should support game events:

```gdscript
browser_page_opened(url)
browser_link_clicked(url)
browser_form_submitted(url, form_data)
browser_login_attempted(url, username, password)
```

Fake page definition example:

```json
{
  "url": "intranet.local",
  "title": "Company Intranet",
  "body": "Welcome to the company intranet.",
  "links": [
    {
      "label": "Employee Directory",
      "url": "intranet.local/employees"
    }
  ]
}
```

This app should be useful for mystery games, ARG-style clues, office terminals, lore browsing, login puzzles, fake databases, and story progression.

---

## 13. Mail / Messages App

Include a simple email or messages app.

Features:

- Inbox
- Sent
- Drafts
- Trash
- Message list
- Message detail view
- Sender
- Recipients
- Subject
- Body
- Timestamp
- Attachments from virtual filesystem
- Search messages
- Unread/read state
- Starred/important flag

Optional features:

- Compose message
- Reply
- Forward
- Scheduled incoming messages
- Story-triggered messages
- Locked/encrypted messages

Game event hooks:

```gdscript
mail_opened(message_id)
mail_sent(message_id, recipients)
mail_deleted(message_id)
mail_attachment_opened(message_id, path)
mail_received(message_id)
```

Developers should be able to define a mailbox through JSON, resources, or script.

Example:

```json
{
  "id": "msg_001",
  "from": "admin@company.local",
  "to": ["user@company.local"],
  "subject": "Welcome",
  "body": "Your workstation has been configured.",
  "timestamp": "2034-04-18 09:15",
  "unread": true,
  "attachments": []
}
```

---

## 14. Notes App

Include a lightweight notes app.

Features:

- Create note
- Edit note
- Delete note
- Search notes
- Pin note
- Optional categories/tags
- Autosave

This app should be useful for player-created notes, clues, developer-authored notes, and environmental storytelling.

---

## 15. Calculator

Include a simple calculator.

Features:

- Basic arithmetic
- Keyboard input
- Copy result
- Clear
- Optional scientific mode

It does not need to be fancy. It should mostly exist because real desktop systems usually include one, and game designers may use it for puzzles.

---

## 16. Image Viewer

Include a simple image viewer.

Features:

- Open image files from virtual filesystem
- Zoom in/out
- Fit to window
- Actual size
- Next/previous image in folder
- Basic metadata panel if useful

Useful for:

- Photos
- Screenshots
- Evidence
- Maps
- Diagrams
- Puzzle images
- Character files

---

## 17. Media Player

Include a simple media player if feasible.

Features:

- Open audio files
- Play/pause
- Seek bar
- Volume control
- Track title
- Playlist support optional

Useful for:

- Audio logs
- Voicemails
- Music files
- Surveillance recordings
- Clue playback

Video support is optional and may be skipped unless straightforward.

---

## 18. System Monitor

Include a fake system monitor app.

Features:

- Fake CPU usage
- Fake memory usage
- Fake disk usage
- Fake process list
- Uptime
- Hostname
- OS version

This should look believable but does not need to reflect actual engine performance.

The developer should be able to control displayed values.

Useful for:

- Atmosphere
- Fake diagnostics
- Puzzle states
- “System compromised” moments
- Lab/industrial computers

---

## 19. Notifications

Godot-OS should include a notification system.

Features:

- Toast notifications
- Notification list/history
- App icon
- Title
- Body
- Timestamp
- Click action
- Dismiss action
- Optional sound
- Optional urgency levels

Notification types:

- Info
- Success
- Warning
- Error
- Message
- System

Suggested API:

```gdscript
HermesOS.notify({
  "title": "New mail",
  "body": "You have received a new message.",
  "app_id": "mail",
  "level": "info",
  "action": {
    "type": "launch_app",
    "app_id": "mail",
    "args": { "message_id": "msg_001" }
  }
})
```

Signals:

```gdscript
notification_created(notification_id)
notification_clicked(notification_id)
notification_dismissed(notification_id)
```

---

## 20. App Launcher

The app launcher should be simple and familiar.

Features:

- List installed apps
- Search apps
- Categories
- App icons
- Launch apps
- Optional recent apps
- Optional favorites

Default categories:

- System
- Utilities
- Internet
- Office
- Media
- Developer
- Game Specific

The launcher should feel clean and functional. It can be simple, but opening apps should feel satisfying and immediate.

---

## 21. Taskbar / Panel

The taskbar or panel should include:

- Launcher button
- Open app buttons
- Active window indicator
- Clock
- Notification indicator
- Optional system tray
- Optional power menu

Panel location should be configurable:

- Bottom
- Top
- Left
- Right if practical

Default should probably be bottom for familiarity.

---

## 22. Power Menu

Include a simple power menu.

Options:

- Lock
- Log out
- Restart
- Shut down

These should not necessarily quit the game. They should change the in-game OS state.

Signals:

```gdscript
os_lock_requested()
os_logout_requested()
os_restart_requested()
os_shutdown_requested()
```

The consuming game can decide whether shutting down the OS hides the UI, turns off a monitor, plays an animation, or triggers a gameplay event.

---

# Theme System

## 23. Default Theme

The default theme should be polished but plain.

Visual direction:

- Clean Linux desktop
- Muted colors
- Soft borders
- Subtle shadows
- Clear typography
- Smooth hover/focus states
- Practical spacing
- No extreme stylization

Default theme should include:

- Dark mode
- Light mode
- Accent color support
- Window styling
- Button styling
- Input styling
- Panel styling
- Context menu styling
- Notification styling
- Icon set
- Default wallpaper

The default should be “boring in a good way.” It should feel like a reliable OS that came preinstalled.

---

## 24. Theme Overrides

Developers should be able to override:

- Wallpaper
- Accent color
- Fonts
- Icons
- Window border radius
- Panel location
- Panel opacity
- Sounds
- Cursor style
- Boot logo
- Login background
- App availability
- Desktop shortcuts

Theme data should be centralized. Avoid scattering colors and style constants across individual apps.

Suggested theme resource:

```gdscript
HermesOSTheme
  theme_id
  display_name
  godot_theme_resource
  wallpaper
  boot_logo
  icon_pack
  sounds
  accent_color
  window_radius
  panel_opacity
```

---

## 25. Included Themes

Include a small set of starter themes:

### Default Dark

A clean modern dark Linux-style desktop.

### Default Light

A clean modern light Linux-style desktop.

### Classic

A slightly older desktop style. Useful for offices, schools, older computers, and public terminals.

### Terminal Green

A minimal old-terminal inspired theme, but not too cheesy.

### High Contrast

Accessibility-oriented high-contrast theme.

Avoid making the default theme too stylized. Specialized themes should be optional.

---

# Input Requirements

## 26. Mouse Input

Godot-OS should support normal mouse interaction:

- Click
- Double-click
- Right-click
- Drag
- Resize
- Scroll
- Hover
- Focus

Mouse interactions should feel forgiving. Hit boxes for resize handles and title bars should not be frustratingly tiny.

---

## 27. Keyboard Input

Support keyboard navigation where practical.

Suggested shortcuts:

```text
Alt+Tab: cycle windows
Ctrl+W: close active window if app supports it
Ctrl+S: save in supported apps
Ctrl+F: find/search in supported apps
Ctrl+L: focus browser address bar
Ctrl+C / Ctrl+V: copy/paste where supported
Enter: activate focused item
Esc: close modal/menu
```

Shortcuts should be configurable or easy to disable if they conflict with the consuming game.

---

## 28. Gamepad Support

Gamepad support is optional but valuable.

If included:

- Focus navigation should work between controls
- Left stick / D-pad moves focus
- Confirm opens/activates
- Cancel closes menus/dialogs
- Shoulder buttons could cycle windows
- Virtual cursor mode optional

At minimum, the system should not break if the consuming game uses gamepad input.

---

# Save / Load / State

## 29. OS State Persistence

Godot-OS should support save/load.

Persistable state:

- User settings
- Window positions/sizes
- Files created/edited/deleted
- Notes
- Mail read/unread status
- Trash contents
- App-specific state
- Login state if desired
- Desktop icon positions
- Terminal history if desired
- Notification history if desired

Suggested API:

```gdscript
var save_data = HermesOS.export_state()
HermesOS.import_state(save_data)
HermesOS.reset_state()
```

The save format should be a dictionary or JSON-compatible object so the consuming game can integrate it into its own save system.

Godot-OS should not assume it owns the full game save file.

---

## 30. Session State vs Persistent State

Separate short-lived session state from persistent state.

Session state examples:

- Currently open windows
- Focused window
- Current boot phase
- Current mouse hover state

Persistent state examples:

- Edited files
- Deleted files
- Read messages
- Settings
- Completed terminal commands
- Puzzle flags

This distinction matters because some games may want the computer to reset visually each time while preserving discovered information.

---

# Game Integration

## 31. Event Hooks

Godot-OS must expose clean event hooks so game developers can connect OS interactions to gameplay.

Examples:

```gdscript
HermesOS.events.connect("file_opened", Callable(self, "_on_file_opened"))
HermesOS.events.connect("terminal_command_entered", Callable(self, "_on_terminal_command"))
HermesOS.events.connect("mail_opened", Callable(self, "_on_mail_opened"))
HermesOS.events.connect("browser_page_opened", Callable(self, "_on_page_opened"))
HermesOS.events.connect("login_success", Callable(self, "_on_login_success"))
```

Use cases:

- Unlocking doors
- Revealing clues
- Updating quest flags
- Triggering NPC dialogue
- Starting cutscenes
- Playing sounds
- Showing warnings
- Spawning enemies
- Changing the virtual filesystem
- Sending new mail
- Unlocking hidden apps

---

## 32. Developer Scripting API

The public API should feel simple.

Suggested high-level API:

```gdscript
HermesOS.boot()
HermesOS.shutdown()
HermesOS.restart()
HermesOS.lock()
HermesOS.unlock(password: String)

HermesOS.launch_app(app_id: String, args := {})
HermesOS.close_app(app_id: String)
HermesOS.notify(data: Dictionary)

HermesOS.fs.read_file(path: String)
HermesOS.fs.write_file(path: String, content)
HermesOS.fs.create_file(path: String, content := "")
HermesOS.fs.delete(path: String)

HermesOS.mail.add_message(message_data: Dictionary)
HermesOS.browser.register_page(page_data: Dictionary)
HermesOS.terminal.register_command(name: String, callback: Callable, help_text := "")

HermesOS.export_state() -> Dictionary
HermesOS.import_state(state: Dictionary)
```

The API should be documented clearly and should not require developers to understand internal scene structure.

---

## 33. Data-Driven Configuration

Developers should be able to configure most things without editing core scripts.

Support configuration through Godot Resources, JSON, or both.

Configurable items:

- OS name
- Version string
- Hostname
- Username
- Password/login settings
- Apps installed
- Desktop shortcuts
- Filesystem contents
- Mailbox contents
- Browser pages
- Terminal commands
- Theme
- Wallpaper
- Boot behavior
- Sounds
- Save/load behavior

Example config:

```json
{
  "os_name": "Godot-OS",
  "version": "0.1.0",
  "hostname": "workstation-04",
  "username": "guest",
  "login_required": true,
  "password": "letmein",
  "theme": "default_dark",
  "wallpaper": "res://game/wallpapers/office.png",
  "installed_apps": [
    "files",
    "terminal",
    "mail",
    "browser",
    "settings"
  ]
}
```

---

# 3D / Diegetic Usage

## 34. In-World Monitor Support

Godot-OS should be easy to place on an in-game monitor.

Provide an example scene showing:

- OS rendered to a SubViewport
- SubViewportTexture applied to a 3D monitor mesh
- Mouse input projected into the viewport
- Keyboard focus handling
- Power state integration

This is important because many games will use the OS on an actual in-world screen rather than as a full-screen overlay.

---

## 35. Interaction Modes

Support multiple ways to use the OS:

### Fullscreen Overlay

The game switches to the OS as a full UI screen.

### Embedded 2D Panel

The OS appears inside a 2D UI panel.

### 3D Monitor

The OS is rendered onto a 3D monitor or laptop screen.

### Hybrid Interaction

Player looks at a 3D monitor, presses interact, then the OS opens fullscreen for easier use.

Developers should be able to choose whichever mode fits their game.

---

# Polish Requirements

## 36. Responsiveness

The OS must feel snappy.

Requirements:

- Apps open quickly
- Buttons respond immediately
- Windows drag smoothly
- Animations are short and subtle
- No long fake delays by default
- Boot delay is configurable
- Terminal output should feel immediate unless intentionally delayed

Avoid sluggish UI. Fake computers in games often feel bad because every action waits on an unnecessary animation. Godot-OS should feel good to use.

---

## 37. Animations

Use subtle animations:

- Window open
- Window close
- Minimize
- Restore
- Notification slide/fade
- Launcher open
- Menu open
- Button hover/focus

Animations should be:

- Fast
- Optional
- Configurable
- Disabled by accessibility setting if needed

Default animation duration should generally be between `0.08s` and `0.18s`.

---

## 38. Audio Feedback

Include optional UI sounds.

Sounds:

- Click
- Window open
- Window close
- Notification
- Error
- Login success
- Login failure
- Startup
- Shutdown

Sounds should be subtle and easy to disable.

Developers should be able to replace sounds with their own.

---

## 39. Accessibility

Include basic accessibility options:

- Font scale
- High contrast theme
- Reduced motion
- Sound toggle
- Larger cursor option if practical
- Keyboard navigation where practical

This is especially important because in-game computer UI can become frustrating if text is too small or interaction is too precise.

---

# Performance Requirements

## 40. Performance Goals

Godot-OS should be light enough to run inside games without becoming a performance problem.

Goals:

- Avoid heavy per-frame processing
- Avoid unnecessary `_process` loops
- Use signals where possible
- Pool/reuse UI elements where useful
- Lazy-load apps if practical
- Avoid loading all app scenes at startup unless needed
- Keep default assets lightweight

The OS should work well as:

- Fullscreen UI
- SubViewport texture
- Embedded control

---

## 41. Rendering Considerations

If used in a SubViewport:

- Support configurable resolution
- Support scaling without blurry text where possible
- Allow low/high resolution modes
- Avoid tiny text by default
- Provide recommended viewport sizes

Recommended default OS viewport sizes:

```text
1280x720
1366x768
1600x900
1920x1080
```

Minimum practical design target:

```text
1024x576
```

---

# Security / Safety Boundaries

## 42. Fake OS Only

Godot-OS is not a real operating system and must not pretend to access the player’s actual machine.

The terminal, filesystem, browser, mail, and apps should all operate in a virtual sandbox.

Avoid features that could accidentally read or modify real local files unless a developer intentionally adds that behavior for tooling outside gameplay.

Default behavior should be safe and entirely internal to the game.

---

# Documentation Requirements

## 43. Developer Documentation

Include clear documentation for:

- Installing the asset
- Instancing the OS
- Creating a virtual filesystem
- Adding custom apps
- Adding custom files
- Adding terminal commands
- Adding browser pages
- Adding mail messages
- Handling OS events
- Saving/loading OS state
- Rendering the OS on a 3D monitor
- Creating themes
- Disabling built-in apps

Docs should be written for game developers, not just engine programmers.

---

## 44. Example Scenes

Include examples:

### Basic Desktop Demo

A full-screen OS scene with all default apps.

### 3D Monitor Demo

A simple room with a monitor running Godot-OS.

### Mystery Game Demo

A small example showing:

- Locked login
- Email clue
- Browser clue
- Terminal command
- File unlock
- Game event trigger

### Custom Theme Demo

Shows how to reskin the OS for a different game.

### Custom App Demo

Shows how to register and launch a simple custom app.

---

# Suggested Internal Architecture

## 45. Core Services

Suggested services/autoloads:

```text
HermesOS
HermesOSAppRegistry
HermesOSWindowManager
HermesOSFileSystem
HermesOSTerminal
HermesOSNotifications
HermesOSThemeManager
HermesOSStateManager
HermesOSEventBus
HermesOSInputRouter
```

Depending on preference, these can be separate autoloads or internal service nodes under `os_root.tscn`.

The public-facing API should be simple even if the internals are modular.

---

## 46. Scene Composition

Suggested root scene:

```text
OSRoot (Control)
  BootLayer
  LoginLayer
  DesktopLayer
    Wallpaper
    DesktopIcons
    WindowLayer
    Panel
    Launcher
    NotificationLayer
    ContextMenuLayer
    ModalLayer
```

The scene should keep layers clear and predictable.

Window z-index management should be centralized.

---

## 47. App Base Class

Create a base class for apps.

Suggested base:

```gdscript
class_name HermesOSApp
extends Control

var app_id: String
var window_id: String
var args: Dictionary = {}

func on_app_launched(args: Dictionary) -> void:
  pass

func on_app_focused() -> void:
  pass

func on_app_blurred() -> void:
  pass

func on_app_closing() -> bool:
  return true

func export_app_state() -> Dictionary:
  return {}

func import_app_state(state: Dictionary) -> void:
  pass
```

Apps should have predictable lifecycle hooks.

---

## 48. Window Component

Create a reusable window scene.

Suggested structure:

```text
OSWindow (Control)
  Shadow
  PanelContainer
    VBoxContainer
      TitleBar
        Icon
        Title
        Spacer
        MinimizeButton
        MaximizeButton
        CloseButton
      ContentRoot
  ResizeHandles
```

The window component should handle window behavior. App content should be inserted into `ContentRoot`.

---

# Minimum Viable Version

## 49. MVP Scope

The first usable version should include:

- OS root scene
- Boot to desktop
- Desktop wallpaper
- Panel/taskbar
- App launcher
- Window manager
- App registry
- Virtual filesystem
- File manager
- Text editor
- Terminal with basic commands
- Settings app with theme/accent toggle
- Notifications
- Save/load state
- Basic documentation
- One 3D monitor example

Do not build every advanced app first. The window manager, filesystem, app registry, and customization API are the foundation.

---

## 50. Version 2 Features

After MVP, add:

- Mail app
- Browser/intranet viewer
- Notes app
- Image viewer
- Media player
- System monitor
- More themes
- Better gamepad support
- More polished animations
- More example scenes
- Plugin UI for editor-side configuration if desired

---

# Quality Bar

Godot-OS should not feel like a throwaway UI mockup.

It should feel like an asset a developer would actually want to buy, fork, customize, and ship inside a game.

The strongest parts should be:

- Window manager feel
- App modularity
- Virtual filesystem
- Terminal extensibility
- Theme customization
- Game event hooks
- 3D monitor support
- Documentation quality

The default OS should feel plain enough to adapt but polished enough to trust.

---

# Agent Implementation Guidance

Agents working on this project should follow these rules:

1. Keep systems modular.
2. Do not hardcode game-specific content into core OS code.
3. Prefer data-driven configuration.
4. Make the default UI clean and boring, not flashy.
5. Make interactions feel fast and responsive.
6. Use Godot signals for events.
7. Keep the filesystem virtual and safe.
8. Document public APIs as they are created.
9. Build foundations before extra apps.
10. Avoid overengineering, but leave clear extension points.

---

# Definition of Done

Godot-OS is considered successful when a developer can:

1. Add the asset to a Godot 4 project.
2. Instance the OS scene.
3. Boot into a working desktop.
4. Open, move, resize, minimize, maximize, and close windows.
5. Launch built-in apps from the app launcher or desktop icons.
6. Browse and edit a virtual filesystem.
7. Use a fake terminal with virtual commands.
8. Customize wallpaper, theme, apps, files, and login settings.
9. Register a custom app.
10. Register a custom terminal command.
11. Add fake browser pages and mail messages.
12. Save and load OS state through the game’s save system.
13. Render the OS onto a 3D monitor.
14. Connect OS interactions to gameplay events.
15. Ship the OS in a game without rewriting the core.

---

# Final Product Vision

Godot-OS should be the “drop-in Linux-like desktop” for Godot games.

It should give game developers a ready-made in-game computer system that feels believable, useful, and customizable.

By default, it should feel like a normal desktop OS: clean, slightly boring, and practical.

With customization, it should be able to become almost anything:

- Office workstation
- School computer
- Government terminal
- Research lab system
- Space station console
- Horror game computer
- Mystery game laptop
- Corporate intranet machine
- Retro PC
- Hacking game interface

The asset should give developers the boring foundation so they can focus on the interesting game-specific content.

