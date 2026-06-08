# HermesOS

An in-game operating system and interface platform built with Godot 4.6.3.

HermesOS provides a fully interactive desktop environment — window manager, app launcher, taskbar, virtual filesystem, and a suite of built-in applications — all rendered inside a 3D world.

## Features

**Desktop Shell**
- Window manager with drag, resize, snap-to-edge, and alt-tab switching
- Taskbar with running app indicators and system tray
- Start menu launcher with categorized app grid
- Virtual filesystem with home directories, trash, and context menus
- User accounts with avatar selection and persistence

**Built-in Apps**
- **Hermes Chat** — AI assistant with streaming responses and device control
- **Browser** — WebView-powered browser with WorldWeb (in-game internet)
- **Terminal** — Virtual shell with command history, tab completion, and filesystem navigation
- **Files** — File manager with sidebar, context menus, and trash support
- **Text Editor** — Markdown-aware editor with live preview
- **Notes** — Quick note-taking app
- **Calculator** — Standard calculator
- **Media Player** — Audio playback with ambient tracks
- **System Settings** — Appearance, accounts, and system configuration
- **Command Palette** — Quick-action overlay (Ctrl+K)

**3D World**
- First-person room and hallway environment
- Interactive devices (lights, monitor) with 15 color presets
- Desktop monitor rendered as an in-world surface
- Player movement, interaction system, and door mechanics

**WorldWeb (In-Game Internet)**
- Pythia — search engine
- Agora Market — marketplace
- Home.hermes — portal with games and interactive demos

**HermesUI Framework**
- Declarative markup (`.hml`) and stylesheets (`.hss`)
- Component-based app architecture with manifests
- Semantic tree for accessibility and agent interaction
- Theme system with dark/light mode support

**Hermes Agent Integration**
- Natural language chat controls devices (lights, colors, status)
- Agent can launch apps, manage files, and query system state
- Gateway bridge for external AI model connections

## Requirements

- [Godot 4.6.3](https://godotengine.org/download/) (standard build, not Flatpak)

## Running

1. Clone this repository
2. Open the project folder in Godot 4.6.3
3. Let Godot import assets on first load
4. Press **F5** to run

The default main scene is `res://scenes/world_3d.tscn` (3D world with desktop).  
For desktop-only mode, change the main scene to `res://scenes/os/os_shell.tscn`.

## Controls

| Action | Key |
|--------|-----|
| Move | WASD |
| Look | Mouse |
| Interact | E |
| Open Terminal | Ctrl+T |
| Command Palette | Ctrl+K |
| Alt-Tab | Alt+Tab |

## Project Structure

```
scenes/              Game scenes (3D world, OS shell, rooms)
scripts/
  apps/              Built-in applications
  ui/hermes_ui/      HermesUI declarative framework
  os/                Shell, window manager, agent service
  world_3d/          3D world controllers and builders
  core/              Device controller, scene bridge
  hermes/            Agent integration, kernel, bridge client
assets/              Audio, icons, wallpapers, avatars
addons/godot_wry/    WRY WebView plugin (pre-built)
content/hermes_internet/  WorldWeb sites and content
```

## License

[MIT](LICENSE)
