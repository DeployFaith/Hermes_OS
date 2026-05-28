# HermesUI v0.1

HermesUI is the new native Godot app-authoring layer for Hermes_OS.

It is not a second shell theme and not a React-style runtime.
It is a bridge over the existing Hermes_OS UI foundation:
- `scripts/os/design_tokens.gd`
- `scripts/os/style_factory.gd`
- existing `OSShell` helper styling patterns
- existing `AppManifest` / `AppRegistry`
- existing `os_app_*` lifecycle hooks

New apps should use HermesUI.
Existing apps can migrate gradually.

## Design principles

1. Native Godot only
- GDScript + Control nodes
- no WebView app runtime
- no JavaScript/HTML/CSS runtime
- no virtual DOM

2. Bridge, do not fork
- HermesTheme maps to current Hermes_OS palette first
- HermesUI does not replace shell chrome colors in v0
- DesignTokens/StyleFactory stay as the low-level foundation

3. Boring and extendable
- clean Linux-style desktop app surfaces
- dark-mode-first
- readable, practical, calm
- easy for game developers and agents to extend

4. Consistency first
- spacing scale instead of arbitrary gaps
- shared button/input/panel styles
- standard app layouts with visible status feedback

## Bridge strategy

HermesUI token aliases intentionally map onto the current Hermes_OS palette.

Current source mapping:
- `bg` -> `DesignTokens.BG`
- `bg_elevated` -> `DesignTokens.BG_ELEVATED`
- `surface` -> `DesignTokens.PANEL`
- `surface_2` -> `DesignTokens.SURFACE`
- `surface_3` -> `DesignTokens.SURFACE_ACTIVE`
- `border` -> `DesignTokens.BORDER_ACTIVE`
- `border_soft` -> `DesignTokens.BORDER`
- `focus_ring` -> `DesignTokens.FOCUS`
- `text` -> `DesignTokens.TEXT`
- `text_muted` -> `DesignTokens.TEXT_MUTED`
- `text_disabled` -> `DesignTokens.TEXT_DISABLED`
- `accent` -> `DesignTokens.ACCENT`
- `accent_hover` -> `DesignTokens.ACCENT_HOVER`
- `success` -> `DesignTokens.SUCCESS`
- `warning` -> `DesignTokens.WARNING`
- `danger` -> `DesignTokens.ERROR`

Synthesized v0 tokens are only used where the old system has no exact match:
- `text_faint`
- `accent_pressed`
- `accent_soft`
- `info`
- terminal-specific aliases

## Color token aliases

Background:
- bg
- bg_elevated
- surface
- surface_2
- surface_3

Borders:
- border
- border_soft
- focus_ring

Text:
- text
- text_muted
- text_faint
- text_disabled

Accent:
- accent
- accent_hover
- accent_pressed
- accent_soft

Semantic:
- success
- warning
- danger
- info

Terminal:
- terminal_bg
- terminal_text
- terminal_prompt
- terminal_muted
- terminal_error
- terminal_success

## Spacing tokens

- space_0 = 0
- space_1 = 4
- space_2 = 8
- space_3 = 12
- space_4 = 16
- space_5 = 20
- space_6 = 24
- space_8 = 32
- space_10 = 40
- space_12 = 48
- space_16 = 64

Recommended usage:
- app outer padding: 16
- panel padding: 14-16
- card padding: 14
- toolbar gap: 8
- form row gap: 10
- section gap: 16
- major layout gap: 20-24

## Radius tokens

- radius_sm = 6
- radius_md = 10
- radius_lg = 14
- radius_xl = 18
- radius_pill = 999

Recommended usage:
- buttons: radius_md
- inputs: radius_md
- cards/panels: radius_lg
- badges: radius_pill

## Typography tokens

Using Godot default project font in v0.

Sizes:
- text_xs = 11
- text_sm = 12
- text_base = 14
- text_md = 15
- text_lg = 18
- text_xl = 22
- text_title = 26

Recommended usage:
- app title: 20-22
- toolbar title: 16-18
- section heading: 15-18
- body text: 14
- helper/status text: 12-13
- terminal monospace-like usage: 13

## Theme API

`hermes_theme.gd`

Methods:
- `color(name: String) -> Color`
- `spacing(name_or_value) -> int`
- `radius(name_or_value) -> int`
- `font_size(name_or_value) -> int`
- `duration(name: String) -> float`
- `easing(name: String) -> int`
- `build_theme() -> Theme`
- `apply_to(control: Control) -> void`

Style helpers:
- `panel_style(options := {})`
- `card_style(options := {})`
- `button_style(variant := "secondary", state := "normal", options := {})`
- `input_style(state := "normal", options := {})`
- `text_area_style(state := "normal", options := {})`
- `list_row_style(state := "normal", options := {})`
- `badge_style(kind := "info", options := {})`

Status:
- HermesTheme builds and applies a real Godot `Theme`
- HermesUI still uses explicit `StyleBoxFlat` helpers for boring, predictable v0 styling

## Component list

`hermes_component_factory.gd`

Layout:
- `vbox(children := [], gap := -1, options := {})`
- `hbox(children := [], gap := -1, options := {})`
- `spacer(size := 8, vertical := false)`
- `split_view(left, right, sidebar_width := -1, options := {})`

Surfaces:
- `panel(children := [], padding := -1, variant := "base", options := {})`
- `card(children := [], padding := -1, options := {})`

Text:
- `label(text := "", variant := "body", options := {})`
- `badge(text := "", kind := "info", options := {})`
- `message_item(sender := "", text := "", kind := "user", options := {})`

Controls:
- `button(...)`
- `icon_button(...)`
- `input(...)`
- `text_area(...)`

App structure:
- `toolbar(children := [], options := {})`
- `sidebar(children := [], width := -1, options := {})`
- `status_bar(text := "", kind := "info", options := {})`
- `list(items := [], selected_id := "", on_select := Callable(), options := {})`
  - Supports standard text rows and custom rows via `{ "node": <Control> }` entries for advanced content (e.g., chat message cards).
- `tabs(tabs := [], active_id := "", on_change := Callable(), options := {})`

Interactive components store MCP-friendly metadata fields:
- ref
- role
- label
- actions
- enabled
- visible

## Layout templates

`hermes_layout.gd`

- `basic_app(toolbar, content, status, options := {})`
- `sidebar_app(toolbar, sidebar, content, status, options := {})`
- `chat_app(toolbar, message_list, composer, status, options := {})`

These standardize:
- toolbar/status sizing
- split view wiring
- expand flags
- top-to-bottom app composition

## Example button/input usage

```gdscript
var ui := HermesComponentFactory.new()
var search := ui.input("", "Search files…")
var save := ui.button("Save", Callable(self, "_save"), "primary")
var row := ui.hbox([search, save], 8)
```

## Example app layout

```gdscript
var toolbar := ui.toolbar([
    ui.label("Notes", "heading"),
])
var body := ui.panel([
    ui.text_area("", "Write here…", Callable(self, "_on_change"), {"expand_v": true})
], 16)
var status := ui.status_bar("Ready", "info")
var root := layout.basic_app(toolbar, body, status)
```

## HermesApp framework

`hermes_app.gd`

Existing Hermes_OS lifecycle is preserved:
- `os_app_init(context)`
- `os_app_focus()`
- `os_app_blur()`
- `os_app_close_requested()`
- `os_app_get_state()`
- `os_app_restore_state(state)`
- `os_app_handle_agent_action(action, args)`

HermesApp bridges these to nicer overrides:
- `setup(context)`
- `render()`
- `on_focus()`
- `on_blur()`
- `on_close_requested()`
- `get_state()`
- `restore_state(state)`
- `get_mcp_actions()`
- `handle_mcp_action(action, args)`

Important rule:
- `render()` builds once during init
- updates should modify existing nodes imperatively
- do not rebuild the entire UI on every keystroke

Status helpers:
- `set_status(text, kind := "info")`
- `get_status()`
- optional status-bar control binding through `set_status_control(control)`

## State rules

Allowed in app state:
- Dictionary
- Array
- String
- int
- float
- bool
- null

Do not return from `get_state()`:
- Node
- Control
- Callable
- Signal
- Texture
- Resource
- Object references

HermesApp sanitizes state to serializable values.

## Reference / MCP metadata

`hermes_refs.gd`

Methods:
- `make_ref(app_id, local_ref, window_id := "")`
- `attach_meta(control, meta)`
- `get_attached_meta(control)`
- `validate_ref(ref)`

Naming note:
- HermesRefs uses `get_attached_meta` (not `get_meta`) to avoid confusion/collision with Godot's built-in metadata APIs on `Object`.

Examples:
- `hermes_chat.send`
- `hermes_chat.composer`
- `settings.gateway.connect`
- `files.new_file`

## Migration plan

1. Hermes Chat
2. System Settings
3. Notes
4. Text Editor
5. Files
6. Terminal
7. Browser last

Why this order:
- Hermes Chat is the proof-of-concept for the new layer
- Settings/Notes/Text are ordinary Control-heavy apps and easiest to normalize
- Files has more complex state and selection flows
- Terminal has special rendering/input behavior
- Browser has native surface/runtime concerns and should migrate last

## Rules for future apps

- New apps should use HermesUI instead of raw shell styling helpers
- DesignTokens/StyleFactory remain the legacy-low-level foundation
- HermesUI is the preferred authoring layer for new native apps
- Existing apps can migrate incrementally without a big-bang re-theme
