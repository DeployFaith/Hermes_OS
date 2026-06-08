# HermesOS

An in-game operating system and interface platform built with Godot 4.6.3.

HermesOS provides a fully interactive desktop environment — window manager, app launcher, taskbar, virtual filesystem, and a suite of built-in applications. Designed to run inside a 3D game world (see [Hermes_Live](https://github.com/DeployFaith/Hermes_Live)) or standalone.

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
- Agent can launch apps, manage files, and query system state
- Gateway bridge for external AI model connections
- Device control (lights, colors) when integrated with a 3D world

## Requirements

- [Godot 4.6.3](https://godotengine.org/download/) (standard build, not Flatpak)

## Running

1. Clone this repository
2. Open the project folder in Godot 4.6.3
3. Let Godot import assets on first load
4. Press **F5** to run

The default main scene is `res://scenes/os/os_shell.tscn` (desktop shell).

## Controls

| Action | Key |
|--------|-----|
| Open Terminal | Ctrl+T |
| Command Palette | Ctrl+K |
| Alt-Tab | Alt+Tab |

## Project Structure

```
scenes/
  os/                OS shell scene
  ui/                UI showcase
scripts/
  apps/              Built-in applications
  ui/hermes_ui/      HermesUI declarative framework
  os/                Shell, window manager, agent service
  hermes/            Agent integration, kernel, bridge client
assets/              Icons, wallpapers, avatars, video
addons/godot_wry/    WRY WebView plugin (pre-built)
content/hermes_internet/  WorldWeb sites and content
```

## 3D World Integration

HermesOS is designed to run inside a 3D game world. The 3D environment (rooms, player, devices) lives in a separate project:

**[Hermes_Live](https://github.com/DeployFaith/Hermes_Live)** — 3D interactive world for HermesOS

When integrated, HermesOS connects to the 3D world via autoloads:
- `SceneBridge` — manages transitions between 3D world and OS
- `HomeDeviceController` — controls in-game devices (lights, etc.)

These autoloads are provided by Hermes_Live. HermesOS gracefully degrades without them — it just won't have device control or scene transitions.

## License

[MIT](LICENSE)
