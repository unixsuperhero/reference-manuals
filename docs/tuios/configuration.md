---
title: "TUIOS: Configuration, Themes, Glyphs and Hooks"
template: tuios-manual
manual: tuios
chapter: 4
summary: Where the tuios config file lives, every table and key in config.toml, how settings reload, and how themes, glyph sets, sounds and hooks are written and selected.
tags:
  - tuios
  - config
  - themes
  - hooks
  - reference
---

tuios reads one TOML file, `config.toml`, and two directories of JSON files beside
it: `themes/` for colour and `glyphs/` for shape. Almost every scalar setting can
also be changed while tuios runs, from the settings page or with
`tuios set-config`, and the running client writes the change back to the file.
This chapter is the complete reference for that file: where it lives, how it is
loaded and reloaded, every table and key with its type and default, and the theme,
glyph set, sound and hook mechanisms that hang off it. Keybindings have their own
chapter, [Keybindings](keybindings.md).

## Quick reference

| Task | Command or place |
|---|---|
| Print the config file path | `tuios config path` |
| Open the file in your editor | `tuios config edit` |
| Write a fresh default file | `tuios config reset` |
| Apply a change that widens permissions | `tuios config apply` (outside tuios) |
| List every settable option | `tuios list-options` |
| Read one option | `tuios get-config appearance.theme --json` |
| Change one option live | `tuios set-config appearance.gap 1` |
| Open the settings page | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>,</kbd> |
| List themes, describe one | `tuios list-themes`, `tuios list-themes dracula` |
| Print a theme's 16 colours | `tuios --preview-theme dracula` |
| Convert a terminal colour scheme | `tuios import-theme FILE --name ID` |
| List glyph sets, describe one | `tuios list-glyphs`, `tuios list-glyphs heavy` |
| List hooks and their last run | `tuios list-hooks` |
| List dock components and their state | `tuios list-dock-components` |
| Re-run a dock component | `tuios refresh-dock NAME` |
| Check keybindings in the file | `tuios keybinds doctor` |

## Where the configuration lives

### The config file

tuios finds its files with the XDG base directory rules, through the
`github.com/adrg/xdg` library. The config file is `tuios/config.toml` under the
config home:

| Platform | Default path |
|---|---|
| Linux, BSD | `~/.config/tuios/config.toml` |
| macOS | `~/Library/Application Support/tuios/config.toml` |
| Windows | `%LOCALAPPDATA%\tuios\config.toml` |
| Any, with `XDG_CONFIG_HOME` set | `$XDG_CONFIG_HOME/tuios/config.toml` |

When tuios loads the file, it searches the config home first and then the
system config directories (`XDG_CONFIG_DIRS`). When no file exists, it writes a
complete default file at the config home path and uses it. When it saves, it
always writes to the config home path.

The path is the one thing you never have to guess:

```sh
tuios config path
```

```text
/Users/you/Library/Application Support/tuios/config.toml
```

::: tip
On macOS, the default is under `~/Library/Application Support`, not
`~/.config`. To keep your dotfiles in `~/.config`, export
`XDG_CONFIG_HOME="$HOME/.config"` in your shell profile before you start the
daemon. Then `tuios config path` prints `~/.config/tuios/config.toml`.
:::

### The directories beside it

| Path (under the config home) | Holds | Read |
|---|---|---|
| `tuios/config.toml` | All settings | At start, and again on every save |
| `tuios/themes/*.json` | Custom themes | At start, on `tuios list-themes`, and when an unknown id is selected |
| `tuios/glyphs/*.json` | Custom glyph sets | Whenever a set is looked up |
| `tuios/layouts/` | Saved layout templates (`tuios layout`) | On demand |
| `tuios/authorized_keys` | Keys `tuios ssh` accepts | When the SSH server starts |

Only files directly in `themes/` and `glyphs/` are read. Subdirectories are
ignored. `tuios list-themes` and `tuios list-glyphs` print the real directory
on their last line:

```sh
tuios list-themes --filter nord
```

```text
  nord        nord_light

2 of 342 registered themes.

active: (none) (default)
themes dir: /home/you/.config/tuios/themes
```

Scripts that hooks and dock components run can live anywhere. The examples in
this manual put them in `~/.config/tuios/hooks/` and `~/.config/tuios/dock/`,
which is a convention, not a requirement.

### The first file

The first time tuios starts without a file, it writes one with every key at its
default and a comment header that says where the file is and that tuios watches
it. `tuios config reset` writes the same file again, after it asks:

```sh
tuios config reset
```

```text
Are you sure you want to reset to defaults? (yes/no):
```

## The `tuios config` commands

| Command | What it does |
|---|---|
| `tuios config path` | Print the path of the config file. |
| `tuios config edit` | Open the file in `$EDITOR`, then `$VISUAL`, then the first of `vim`, `vi`, `nano` and `emacs` that is installed. |
| `tuios config reset` | Overwrite the file with the defaults, after a `yes`/`no` prompt. |
| `tuios config apply` | Tell the running daemon to apply the file now, including changes that give panes or other machines more than they had. Refused from inside a tuios pane. |

```sh
EDITOR=nvim tuios config edit
```

`tuios config apply` exists because of one rule. The daemon follows the file at
once when a change gives less, such as `[agents.permissions] mode = "strict"`
or a shorter `allow` list in `[hosts]`. A change that gives more waits, because a
process inside a pane can write the file. You apply it from a terminal that is
not a tuios pane:

```sh
# in a plain terminal, not a tuios pane
tuios config apply
```

::: note
There is no `tuios config validate` in v0.8.5. tuios validates the file every
time it loads it. See [Checking a config](#checking-a-config).
:::

### Checking a config

A config file can have errors and warnings.

- An **error** is a value tuios cannot use. At startup, tuios prints each error
  as `Config error in [SECTION]: KEY: MESSAGE` and stops with
  `configuration has N error(s), please fix and restart`. During a session, a
  save with an error is not applied: the running settings stay, and the dock
  shows `Config not reloaded: ...`.
- A **warning** is a value tuios can work around, such as an unknown
  `sound_mode`, an unknown grant name, or a `#RRGGBB` field that is not a
  colour. tuios uses the default for that key and shows the warning inside the
  TUI, because text printed before the alternate screen opens is erased by the
  first frame.

Several commands check one part of the file each:

| Command | What it checks |
|---|---|
| `tuios keybinds doctor` | Every key tuios cannot read (`key_problems`), keys bound twice, keys tuios takes from the pane |
| `tuios list-hooks` | Every hook command, how many times it ran, its last exit code and error |
| `tuios list-dock-components` | Every dock cell, whether it drew, and why a custom one failed |
| `tuios list-glyphs ID --json` | Roles a glyph set named and did not get (`problems`) |
| `tuios list-themes ID --json` | Colours that fail contrast on the theme's background (`palette.illegible`) |
| `tuios hosts` | Hosts that are ignored, and why |
| `tuios pane-grants` | The grants a pane holds, and whether a permission change is waiting |

```sh
tuios keybinds doctor --json | jq -r '.key_problems[]?'
tuios list-hooks --json | jq '.hooks[] | select(.last_error != "")'
```

## File format

The file is TOML. Each feature is a table, and a few tables have sub-tables:

```toml
[appearance]
theme = "catppuccin_mocha"
gap = 1

[appearance.sidebar]
position = "left"
width = 28

[notifications.agent.states]
idle = false
```

A setting's **path** is its table names and key joined with dots:
`appearance.sidebar.width`, `notifications.agent.states.idle`. The CLI and the
settings page use the same paths.

Four rules decide how a value you leave out is read:

1. **A missing key takes its default.** Most toggles are stored so that "not
   written" and "written as `false`" are different, and a missing key gets the
   documented default.
2. **A missing list and an empty list differ.** In `[dock]`, `right = []` draws
   nothing on the right, while leaving `right` out draws the default
   components. In `[keybindings.*]`, an action set to `[]` has no key, while an
   action left out gets its default keys.
3. **`[startup] tiled` and `daemon` have no fill-in.** They default to `true` in
   a new file, but a file that does not name them reads them as `false`. An
   older file therefore keeps the floating, standalone behaviour it had.
4. **Empty strings often mean "follow something else".** For example, an empty
   `appearance.pane_background` follows `appearance.background`, and an empty
   `notifications.mail.dock` follows `notifications.agent.dock`.

::: warning
Every change you make on the settings page, and every `tuios set-config` with
a client attached, rewrites the whole file from tuios's in-memory config. Your
comments, your key order and your blank lines are not kept. Keep an annotated
copy elsewhere (for example in a dotfiles repository) if you care about them,
or make all your changes in the file and not in the app.
:::

## Precedence: flags, environment and the file

A value comes from the first of these that sets it:

1. A **runtime change** in the session: the settings page, `tuios set-config`,
   or a tape's `SetConfig`. These also write the file, so they persist.
2. A **command-line flag** of the `tuios` command that starts the client.
3. The **config file**.
4. The **built-in default**.

A command-line flag applies to the client it starts and is not written to the
file. Bare `tuios` and `tuios attach` take the same appearance flags. The flags
that override config keys:

| Flag | Overrides |
|---|---|
| `--theme ID` | `appearance.theme` |
| `--ascii-only` | The glyph choice (see [ASCII mode](#ascii-mode)); no config key |
| `--border-style STYLE` | `appearance.border_style` |
| `--dockbar-position POS` | `appearance.dockbar_position` |
| `--window-title-position POS` | `appearance.window_title_position` |
| `--window-button-style STYLE` | `appearance.window_button_style` |
| `--window-button-position POS` | `appearance.window_button_position` |
| `--hide-window-buttons` | `appearance.hide_window_buttons` |
| `--hide-scrollbar` | `appearance.hide_scrollbar` |
| `--scrollback-lines N` | `appearance.scrollback_lines` |
| `--shared-borders` | `appearance.shared_borders` |
| `--show-clock`, `--hide-clock` | `appearance.show_clock` |
| `--show-cpu`, `--show-ram` | `appearance.show_cpu`, `appearance.show_ram` |
| `--zoom-max-width N` | `appearance.zoom_max_width` |
| `--confirm-quit` | `appearance.confirm_quit` |
| `--no-animations` | `appearance.motion` (until a runtime change to `motion`) |
| `--show-keys` | `debug.show_key_events` |
| `--standalone` | `startup.daemon` |
| `tuios attach --terminal-mode` | `startup.start_in_terminal_mode` |
| `tuios daemon --log-level LEVEL` | `daemon.log_level` |

```sh
# One client in a different theme and with no dock, without touching the file
tuios attach work --theme rose_pine_dawn --dockbar-position hidden
```

A few environment variables also override the file. They are meant for CI,
demos and debugging, not for daily use:

| Variable | Effect |
|---|---|
| `XDG_CONFIG_HOME` | Moves the whole config directory. |
| `TUIOS_NO_DAEMON=1` | Bare `tuios` runs standalone for the whole shell, like `--standalone`. |
| `TUIOS_TAPE_AUTORUN` | `off`, `ask` or `auto`; wins over `tape.autorun`. |
| `TUIOS_NO_SOUND` | Set to anything: no audible cue, whatever `[notifications.agent]` says. |
| `TUIOS_LOG_LEVEL` | The daemon's starting log level. |
| `TUIOS_AGENT_AUTODETECT` | `0`, `false`, `no` or `off` turns agent detection off, only while `daemon.agent_autodetect` is not in the file. |
| `TUIOS_AGENT_DETECT_SECONDS` | The detector's poll interval, only while `daemon.agent_detect_seconds` is 0. |
| `TUIOS_AGENT_BINARIES` | Comma-separated extra agent binary names, added to `daemon.agent_binaries`. |
| `TUIOS_KITTY_PLACEHOLDERS`, `TUIOS_KITTY_GRAPHICS`, `TUIOS_SIXEL_GRAPHICS` | `1` or `0` forces the graphics capability on or off. |
| `COLORTERM`, `TERM`, `NO_COLOR` | The colour depth the chrome is drawn for (see [Colour depth](#colour-depth)). |
| `LC_ALL`, `LC_CTYPE`, `LANG` | A locale that is not UTF-8 turns on ASCII mode. |

```sh
# A recording with no sound and no project tape prompts
TUIOS_NO_SOUND=1 TUIOS_TAPE_AUTORUN=off tuios --standalone
```

## What reloads and what needs a restart

tuios watches the config file's directory, so it sees a save from any editor,
including editors that write a temporary file and rename it. It waits 200 ms
after the last event of a save, then reads the file once. A file that does not
parse or validate changes nothing. The command palette also has a
**Reload config** entry that does the same thing on demand.

Different parts of the file are owned by different processes, so they reload
in different ways:

| Part of the file | When a change applies |
|---|---|
| `[appearance]` and all its sub-tables, themes, glyph sets, backgrounds | On save, in every attached client |
| `[dock]`, including `[dock.custom.*]` | On save; custom components restart |
| `[spotlight]`, `[hints]`, `[screenshot]`, `[scratch]`, `[pip]`, `[notifications.*]` | On save |
| `[keybindings.*]` | In the next client: detach and attach again. `tuios keybinds unbind` and `free` apply at once |
| `[[keybindings.command]]` | The palette row changes on save; the key works in the next client |
| `[startup]` | When a new session starts. A running session keeps its own layout and mode |
| `[hooks]`, daemon side | When the daemon starts. Run `tuios kill-server` after a change |
| `[hooks]`, client side | When the client starts |
| `[daemon] persist_scrollback*`, `window_size` | When the daemon starts. `set-config daemon.window_size` changes one session at once |
| `[agents.approvals]`, `[agents.queue]`, `[agents] herdr_protocol` | On save, for the next prompt, message or pane |
| `[agents.permissions]`, `[hosts]` | On save when the change gives less; with `tuios config apply` or a daemon restart when it gives more |
| `[agents.recap]` | `test_patterns` on save; `mode` and `away` when the client loads the config |
| `[tape]` | On the next directory change |

::: example
**Example: watch a change land**

Open the file in one pane and the session in another. Change the gap and save:

```toml
[appearance]
gap = 2
```

Within a fraction of a second the panes retile with two cells between them.
Now break the file (delete a closing quote) and save again. The layout stays
as it was and the dock shows `Config not reloaded:` with the parse error.
:::

## Reading and changing options at runtime

### Which options are settable

Every **scalar** option (a bool, an int or a string) is in tuios's option
registry. The registry is the single list that `tuios list-options`,
`tuios get-config`, `tuios set-config`, the tape `SetConfig` command and the
settings page all use, and a test fails the build if an option is missing from
one of them. In v0.8.5 the registry has 196 paths.

Tables, lists and maps are not scalar, so they are not in the registry. You
change them only in the file:

- `[dock]` region lists and `[dock.custom.*]` (only `dock.clock.format` is in
  the registry)
- `[hooks]`
- `[keybindings.*]`, `[[keybindings.command]]`, `[[keybindings.copy_pipe]]`
- `[appearance.sidebar.agent_row]`
- `[hosts.*]` and `[tailscale]`
- `[agents]` and all its sub-tables
- `[notifications.agent.sounds]` (the cue file paths)
- `hints.patterns`, `daemon.agent_binaries`, `daemon.respond_from_shell`

Several of these are excluded on purpose: a process in a pane can call
`tuios set-config`, so nothing that decides what a pane may do is reachable
through it.

### `tuios list-options`

```sh
tuios list-options                         # everything, grouped by section
tuios list-options --section sidebar       # one group
tuios list-options appearance.selection.   # one path prefix
tuios list-options --search "pane bg"      # fuzzy search, best first
tuios list-options --json | jq -r '.options[].path'
```

Each JSON entry has `path`, `type`, `section`, `description`, `default`, and
when they apply `accepted`, `min`, `max` and `deprecated`:

```json
{
  "path": "appearance.gap",
  "type": "int",
  "section": "appearance",
  "description": "Cells of empty ground kept between two neighbouring tiled panes",
  "default": "0",
  "min": 0,
  "max": 8
}
```

### `tuios get-config`

`get-config` reads the value in effect for a session. A path that exists always
reads, even when nothing set it. `--json` adds where the value came from:
`session` (set on this session), `config` (the daemon's file, for
`daemon.window_size` only) or `default`.

```sh
tuios get-config border_style
tuios get-config appearance.sidebar.position --json
```

```json
{
  "default": "right",
  "key": "appearance.sidebar.position",
  "option_type": "string",
  "source": "default",
  "type": "option",
  "value": "right"
}
```

A `notifications.mail` key that is not set reads as what it follows:

```sh
tuios get-config notifications.mail.dock
```

```text
(follows notifications.agent.dock)
```

### `tuios set-config`

`set-config PATH VALUE` validates the path and the value, applies the value to
the session, and, when a client is attached, writes the file the way the
settings page does. With nobody attached, the value applies on the next attach.

```sh
tuios set-config appearance.theme gruvbox_dark
tuios set-config border_style thick          # an [appearance] key also answers to its bare name
tuios set-config appearance.sidebar.width 30
tuios set-config -s work dock_background '#11111b'
tuios set-config appearance.sidebar.background ''   # empty: follow appearance.background again
```

The value is checked against the option:

| Option kind | Accepted value |
|---|---|
| bool | `true` or `false` |
| int | A number inside the option's range |
| Closed set | One of the `accepted` values |
| Colour | `#RRGGBB`, one of the option's keywords, or empty to clear |
| Theme (`appearance.theme`) | A registered theme id. The themes directory is read again first, so a file you just wrote is found |
| Glyph set (`appearance.glyphs`) | A registered set id. The glyphs directory is read again first |
| Box size (`scratch.width`, `scratch.height`) | Cells (`100`) or a percent (`80%`) |

A path that does not exist is refused, never recorded:

```sh
tuios set-config appearance.sidebar.wdith 30
```

The error is `no such option`, with a did-you-mean suggestion (here
`appearance.sidebar.width`) and the full list of valid paths in the JSON
error, so a script can correct itself without a second call.

The result reports `applied`: whether an attached client put the change on
screen. When it is false, `reason` says that nobody is attached or that the
client refused it.

::: warning
There is no undo. Record the old value before you change one from a script:

```sh
old=$(tuios get-config appearance.theme --json | jq -r .value)
tuios set-config appearance.theme nord
# ... later
[ -n "$old" ] && tuios set-config appearance.theme "$old"
```

Three options have an empty default but no empty value in their accepted set,
so `set-config` cannot put them back to the default once changed:
`appearance.sidebar_position`, `appearance.whichkey_position` and
`notifications.agent.sound_mode`. Delete the key from the file instead.
:::

## The settings page

The settings page is the same registry as a set of tabs. Open it with
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>,</kbd> (the leader, then comma), with
<kbd>,</kbd> in window mode, or from the command palette. If you changed your
leader, as in `leader_key = "ctrl+a"`, use that key instead.

The page has fourteen tabs: **Appearance**, **Backgrounds**, **Sidebar**,
**Selection**, **Dock**, **Behavior**, **Startup**, **Advanced**,
**Spotlight**, **Daemon**, **Tape**, **Screenshot**, **Saver** and **Hosts**.

| Key | On the settings page |
|---|---|
| <kbd>Up</kbd>, <kbd>Down</kbd> | Move between rows (wraps at the ends) |
| <kbd>Left</kbd>, <kbd>Right</kbd> | Change the value |
| <kbd>Tab</kbd>, <kbd>]</kbd> | Next tab |
| <kbd>1</kbd> to <kbd>9</kbd> | Go to that tab |
| <kbd>/</kbd> | Search every tab by name, key, current value or description |
| <kbd>Backspace</kbd> | Reset the row to its default |
| <kbd>Ctrl</kbd>+<kbd>z</kbd> | Undo the last change |
| <kbd>Esc</kbd> | Clear the search, then close |

- A bool row flips, an enum row cycles, and an int row has a number editor;
  a percent row draws a gauge.
- A colour row opens a picker seeded with the colour in use. Backgrounds rows
  also offer `off` and `theme`, and <kbd>x</kbd> clears a surface so it follows
  the All surfaces row again.
- The **Theme** row opens the searchable theme picker with a swatch per theme.
  Cancelling restores the theme you had when you opened it.
- The **Glyph set** row, under Theme, opens a picker that draws each set's own
  corner, controls and rail marks, and applies the set as you move.
- **Dock, Components** is an editor for the three region lists: shifted arrows
  move a component (and carry it into the next region off the end), Enter takes
  one off the bar or puts it back, <kbd>u</kbd> undoes this session's edits and
  <kbd>r</kbd> restores the defaults.

Every change applies at once and is saved to the file. A client that is not
allowed to write the file, such as some remote clients, applies the change to
its session and says once that it did not save it.

## The `[appearance]` table

`[appearance]` is the largest table: everything about how tuios looks and how
the mouse and the panes behave. Every key in it is settable at runtime, and
every key also answers to its bare name in `tuios set-config`
(`set-config gap 1` is `set-config appearance.gap 1`). The tables below are
generated from the option registry of v0.8.5, so the types, defaults and value
sets are exact.

### Theme, glyphs and accent colours

| Key | Type | Default | Meaning |
|---|---|---|---|
| `theme` | string | (empty) | Colour theme name. Empty keeps your terminal's own colours. |
| `glyphs` | string | `default` | Chrome glyph set: the characters the border, controls, rules and rail marks are drawn with. |
| `border_focused_color` | string | (empty) | Hex colour overriding the focused pane's border, e.g. #89b4fa. |
| `border_unfocused_color` | string | (empty) | Hex colour overriding an unfocused pane's border, e.g. #585b70. |
| `session_colors` | bool | `true` | Give each session its own colour on the rail and in the switcher. |
| `session_border` | bool | `false` | Carry the session's colour on every pane border, not only on the rail. |

`theme` empty means no theming: panes use your terminal's own sixteen colours.
`border_focused_color` and `border_unfocused_color` override only the border
inks; they are not part of a theme file. See [Themes](#themes) and
[Glyph sets](#glyph-sets).

```toml
[appearance]
theme = "catppuccin_mocha"
glyphs = "unicode"
border_focused_color = "#89b4fa"
border_unfocused_color = "#45475a"
session_border = true      # carry each session's colour on every pane border
```

### Backgrounds

| Key | Type | Default | Meaning |
|---|---|---|---|
| `background` | string | `off` | Background painted on every surface not set on its own (panes, desktop, window chrome, dock, rail): off (your terminal shows through), theme, or a #RRGGBB literal. Values: `off`, `theme`. |
| `pane_background` | string | (empty) | Background behind pane content: off, theme, or a #RRGGBB literal; empty follows appearance.background. Values: `off`, `theme`. |
| `desktop_background` | string | (empty) | Background behind and between panes, including gaps and an empty workspace: off, theme, or a #RRGGBB literal; empty follows appearance.background. Values: `off`, `theme`. |
| `window_chrome_background` | string | (empty) | Background under pane borders, title bars and the lines between shared-border panes: off, theme, or a #RRGGBB literal; empty follows appearance.background. Values: `off`, `theme`. |
| `dock_background` | string | (empty) | Background under the dock: off, theme, or a #RRGGBB literal; empty follows appearance.background. Values: `off`, `theme`. |
| `sidebar.background` | string | (empty) | Background under the rail: off, theme, or a #RRGGBB literal; empty follows appearance.background. Values: `off`, `theme`. |

A cell with no background of its own is transparent, so your terminal's own
background shows through it. That is the default for every surface: pane
content a program left on the default background, the gaps between panes, the
borders, the dock and the rail. These six options paint those cells instead.

| Value | What is painted |
|---|---|
| `off` | Nothing. Your terminal shows through. |
| `theme` | The active theme's background, with the theme's foreground on default-coloured text. With no theme set it behaves as `off`, and the validator warns. |
| `#RRGGBB` | That colour. With a theme, default-coloured text takes the theme's foreground, lifted until it reads on the colour; with none, it keeps your terminal's foreground. |
| empty (per surface only) | Follow `appearance.background`. |

A surface's own option wins whenever it has a value, `off` included. A value
that is neither a keyword nor a `#RRGGBB` literal resolves to `off` for that
surface (it does not fall back to `background`), with a warning.

```toml
[appearance]
background = "theme"          # every surface on the theme's background
dock_background = "#11111b"   # the dock a shade darker
pane_background = "off"       # panes keep the terminal's own background

[appearance.sidebar]
background = "#181825"
```

Only cells with no background are painted. A background a program chose
always wins, and so do tuios's own marks: the selection, search matches, the
copy-mode cursor, border inks, title-bar buttons, the dock's pills and the
rail's highlighted rows. Overlay panels (palette, settings, which-key, Inbox,
pickers, tooltips) fill their own rectangle and are not affected.

While the pane background paints a colour, a program's OSC 11 query for the
background is answered with that colour and OSC 10 with the text colour tuios
gives default text there. See [OSC colour queries](#osc-colour-queries).

### Borders, titles and window controls

| Key | Type | Default | Meaning |
|---|---|---|---|
| `border_style` | string | `rounded` | Border style drawn around every pane. Values: `rounded`, `normal`, `thick`, `double`, `block`, `outer-half-block`, `inner-half-block`, `ascii`, `hidden`, `glyphs`. |
| `shared_borders` | bool | `false` | Share one border between adjacent tiled panes. |
| `zen_mode` | string | `disabled` | When window borders are hidden: never, always, or while the mouse is idle. Values: `disabled`, `always`, `mouse`. |
| `window_title_position` | string | `top` | Edge of the pane the title is drawn on. Values: `bottom`, `top`, `hidden`. |
| `window_title_format` | string | (empty) | Title template accepting {title}, {index} and {cwd}. |
| `hide_window_buttons` | bool | `false` | Hide the minimize, maximize and close buttons. |
| `window_button_style` | string | `dots` | Window controls as a filled pill or as macOS traffic lights. Values: `pill`, `dots`. |
| `window_button_position` | string | `left` | Which end of the title bar the window controls sit on. Values: `right`, `left`. |
| `window_button_zoom` | bool | `true` | Carry the third title bar control on a tiled pane, where it toggles the zoom. |
| `hide_scrollbar` | bool | `false` | Hide the scrollbar thumb on the pane border. |

`window_title_format` takes the tokens `{title}` (the window's custom name if
set, else the terminal title), `{index}` and `{cwd}`. `border_style = "glyphs"`
draws the border the active glyph set defines (see
[The border](#the-border)).

```toml
[appearance]
border_style = "rounded"
window_title_position = "top"
window_title_format = "{index}: {title}"
window_button_style = "dots"      # macOS traffic lights
window_button_position = "left"   # the shipped pair
zen_mode = "mouse"                # hide borders while the mouse is idle
```

### The dock and the clock

These keys are in `[appearance]`. What the dock is made of is the separate
[`[dock]` table](#the-dock-table).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `dockbar_position` | string | `top` | Edge the dock sits on, or hidden. Values: `bottom`, `top`, `hidden`. |
| `dock_workspace_tabs` | bool | `true` | Show the clickable workspace strip in the dock. |
| `dock_workspace_tab_format` | string | (empty) | Workspace tab template accepting {index} and {name} (empty: {name}). |
| `dock_workspace_tooltip` | bool | `true` | Pop a truncated workspace name in full on hover. |
| `dock_pill_caps` | bool | `false` | Draw powerline caps on the dock's pills instead of flat ends. |
| `show_clock` | bool | `false` | Show the clock overlay. |
| `hide_clock` | bool | `false` | Hide the clock overlay. **Deprecated:** superseded by appearance.show_clock, which says the same thing the right way round. |
| `clock_format` | string | `15:04:05` | Go time layout the clock is drawn with, e.g. 15:04 or Mon 3:04PM. |
| `show_cpu` | bool | `false` | Show the CPU graph in the dock. |
| `show_ram` | bool | `false` | Show RAM usage in the dock. |

`dock_workspace_tab_format` takes `{index}` and `{name}`. `clock_format` is a
Go time layout, written with the reference time `Mon Jan 2 15:04:05 2006`:
`15:04` is a 24-hour clock, `3:04PM` a 12-hour one, `Mon 15:04` adds the day.

```toml
[appearance]
dockbar_position = "top"
dock_workspace_tab_format = "{index} {name}"
show_clock = true
clock_format = "Mon 15:04"
show_cpu = true
show_ram = true
```

### Layout and tiling

| Key | Type | Default | Meaning |
|---|---|---|---|
| `gap` | int | `0` | Cells of empty ground kept between two neighbouring tiled panes. Range 0 to 8. |
| `tiling_scheme` | string | `spiral` | BSP scheme a workspace inserts new windows with the first time it is tiled. A workspace already tiled keeps its own scheme. Values: `spiral`, `longest_side`, `alternate`, `smart_split`. |
| `master_position` | string | `left` | Side the master panes take in the master-stack layout. Center puts the stack on both sides. Values: `left`, `right`, `top`, `bottom`, `center`. |
| `master_count` | int | `1` | How many panes are master panes in the master-stack layout. Range 1 to 9. |
| `master_ratio` | int | `50` | Width of the master pane in the master-stack layout, as a percent of the screen. Range 10 to 90. |
| `master_grid` | bool | `true` | With one master on the left, show four or more panes as a grid. |
| `scroll_column_width` | int | `55` | Width of a column in the scrolling layout, as a percent of the screen. Range 20 to 100. |
| `scroll_column_max` | int | `90` | Highest a column's width may be set to in the scrolling layout, as a percent. 100 lets a column fill the screen, at the cost of the next one peeking in at the edge. Range 20 to 100. |
| `niri_scroll_cells` | int | `8` | Cells the scrolling layout's strip moves per mouse wheel event. Range 1 to 200. |
| `niri_reverse_scroll` | bool | `false` | Reverse the wheel direction in niri scrolling mode. |
| `niri_click_reveals` | bool | `true` | In the scrolling layout, clicking a column that is partly off the edge brings all of it on screen. |
| `niri_hover_reveals` | bool | `true` | In the scrolling layout with focus-follows-mouse on, hovering a column that is partly off the edge brings all of it on screen. |
| `zoom_size` | int | `95` | How much of the screen a zoomed pane takes, as a percent. Below 100 the layout around it stays visible at the edges. Range 50 to 100. |
| `zoom_max_width` | int | `0` | Width in cells of a zoomed pane. 0 fills the screen. |
| `zoom_animation` | bool | `true` | Slide a pane between its tile and the zoom box instead of swapping the two in one frame. |
| `zoom_follows_focus` | bool | `true` | Hand the zoom to the pane the focus lands on, so moving focus while zoomed shows the pane you moved to. |

Each workspace starts with these values. A layout key that changes a workspace
on screen (such as resizing the master) is kept by that workspace, so these are
starting points, not live bindings. With `master_position = "center"`, the
stack panes go to the right and the left in turn and `master_grid` has no
effect. See [Concepts](concepts.md) for the three layouts.

```toml
[startup]
layout = "master-stack"

[appearance]
master_position = "center"   # an editor in the middle, terminals both sides
master_ratio = 50
gap = 1
```

### Motion, dimming and overlays

| Key | Type | Default | Meaning |
|---|---|---|---|
| `motion` | string | `full` | How much moves: none, basic (window slides and the copy sweep), or full (also overlay fades and the working-agent shimmer). Values: `none`, `basic`, `full`. |
| `animations_enabled` | bool | `true` | Animate UI transitions instead of applying them instantly. **Deprecated:** folded into appearance.motion on load (false is none); set appearance.motion. |
| `modal_dim` | int | `30` | How much the screen behind a modal panel is darkened, as a percent. 0 is off. Range 0 to 90. |
| `dim_unfocused` | int | `0` | How much tuios fades a pane you are not in, as a percent. 0 is off. Range 0 to 90. |
| `dim_multifocus` | bool | `false` | Dim the panes in the multifocus set like other panes you are not in. |
| `panel_padding` | int | `2` | Columns of padding each side of an overlay panel's content. Range 1 to 6. |
| `whichkey_enabled` | bool | `true` | Show the which-key popup after the leader key. |
| `whichkey_position` | string | (empty) | Corner the which-key popup opens in (empty: bottom-right). Values: `bottom-right`, `bottom-left`, `top-right`, `top-left`, `center`. |
| `wrap_lists` | bool | `true` | Up on a list's first row goes to its last, and down on the last goes to the first. |
| `max_fps` | int | `0` | Highest frame rate tuios draws at. 0 uses 60. The range is 10 to 120. Range 0 to 120. |

`motion` has three levels: `none`, `basic` (window slides and the copy sweep)
and `full` (also the panel fade-in and the shimmer on a working agent's rail
row). `dim_unfocused` reaches only cells a program coloured itself unless a
theme is set. On a light theme, `modal_dim` fades the screen toward the theme's
background instead of darkening it.

```toml
[appearance]
motion = "basic"
modal_dim = 15
dim_unfocused = 10
panel_padding = 2
whichkey_position = "bottom-right"
```

### Mouse, keyboard and links

| Key | Type | Default | Meaning |
|---|---|---|---|
| `click_to_type` | string | `double` | What a click on a pane's content does in window-management mode. Values: `single`, `double`, `off`. |
| `alt_drag` | bool | `true` | Alt plus left-drag moves a pane. |
| `focus_follows_mouse` | bool | `false` | Focus the pane under the cursor as the mouse moves. |
| `right_click_opens_menu` | bool | `false` | A plain right-click on a pane in terminal mode opens the pane menu, for pasting without selecting first. |
| `copy_on_select` | bool | `true` | Copy a mouse selection to the clipboard on release. |
| `word_characters` | string | `@-./_~?&=%+#` | Punctuation that counts as part of a word for double-click selection. |
| `links` | string | `all` | Links the pointer picks up: off, only marked links, or plain URLs too. Values: `off`, `marked`, `all`. |
| `auto_enter_terminal_on_focus` | string | `off` | Type in a pane when a keyboard focus command moves to it: off, targeted (select and arrows), or all (including Tab). Values: `off`, `targeted`, `all`. |
| `prefix_repeat_time` | int | `500` | Milliseconds the prefix stays armed after a repeatable command. 0 turns it off. Range 0 to 5000. |
| `confirm_quit` | bool | `false` | Always confirm on quit, not only when processes are running. |

```toml
[appearance]
click_to_type = "single"            # one click on a pane starts typing in it
focus_follows_mouse = false
auto_enter_terminal_on_focus = "targeted"
links = "all"
confirm_quit = true
```

### Terminal, shell and scrollback

| Key | Type | Default | Meaning |
|---|---|---|---|
| `preferred_shell` | string | (empty) | Shell that new panes run. Empty picks one for your platform. |
| `new_window_inherit_cwd` | bool | `true` | A new window starts in the focused pane's working directory. |
| `scrollback_lines` | int | `10000` | Lines each pane keeps in its scrollback. A pane takes the value when it is made. The daemon reads it when it starts. Range 100 to 1000000. |
| `scroll_lines` | int | `3` | Lines scrolled per mouse wheel notch. Range 1 to 50. |
| `kitty_placeholders` | string | `auto` | Draw images an app positions with kitty Unicode placeholders: auto, on, off. Values: `auto`, `on`, `off`. |
| `global_session` | bool | `true` | Offer a session in the rail that holds panes from several machines, once a second one is reachable. |
| `git_dirty` | bool | `true` | Count staged, changed and untracked paths in the rail's git section. The only part of it that costs a walk of the working tree. |

`preferred_shell` empty auto-detects the shell for the platform. A scrollback
of a few hundred thousand lines is allowed, but every pane holds its own, so
memory grows with panes times lines.

```toml
[appearance]
preferred_shell = "/bin/zsh"
scrollback_lines = 50000
scroll_lines = 3
```

### Deprecated flat sidebar keys

Before `[appearance.sidebar]` existed, the rail was configured with flat keys.
They still load, and each maps onto its replacement:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `sidebar_enabled` | bool | `false` | Show the session rail. **Deprecated:** folded into [appearance.sidebar] on load; set appearance.sidebar.enabled. |
| `sidebar_position` | string | (empty) | Edge the session rail sits on. Values: `left`, `right`, `hidden`. **Deprecated:** folded into [appearance.sidebar] on load; set appearance.sidebar.position. |
| `sidebar_width` | int | `0` | Preferred rail width in columns. **Deprecated:** folded into [appearance.sidebar] on load; set appearance.sidebar.width. |
| `sidebar_show_windows` | bool | `true` | Show the terminals section on the rail. **Deprecated:** folded into [appearance.sidebar] on load; set appearance.sidebar.show_windows. |
| `sidebar_show_glyphs` | bool | `true` | Show the agent-state glyph on each rail row. **Deprecated:** folded into [appearance.sidebar] on load; set appearance.sidebar.show_glyphs. |
| `sidebar_show_counts` | bool | `true` | Show the window count on each session row. **Deprecated:** folded into [appearance.sidebar] on load; set appearance.sidebar.show_counts. |

Write the `[appearance.sidebar]` keys in a new file.

### `[appearance.scrollbar]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `style` | string | `track` | Hairline thumb over the content column, or a full-height track. Values: `thin`, `track`. |
| `thumb` | string | (empty) | One-cell glyph for the thumb. Empty uses the style's own. |
| `track` | string | (empty) | One-cell glyph for the track, or none. Empty uses the style's own. |
| `tint` | string | `quiet` | Bar colour: quiet, border, muted, or a #RRGGBB literal. Values: `quiet`, `border`, `muted`. |

`thumb` and `track` are one-cell glyphs, and `track` also takes `none`. They win
over the glyph set's `scrollbar_thumb` and `scrollbar_track` roles, because they
are the narrower setting. Empty takes the style's default (thin: `▐` on `▕`;
track: `█` on the surface fill; ASCII: `|` on nothing).

```toml
[appearance.scrollbar]
style = "thin"
tint = "border"
```

### `[appearance.selection]`

The colours of a selection, search matches and the copy-mode cursor, and how
copying behaves.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `bg` | string | `#45475A` | Background behind selected text. |
| `fg` | string | (empty) | Selected text colour. Empty keeps the colour it already has. |
| `bold` | bool | `false` | Draw selected text bold as well as tinted. |
| `search_bg` | string | `#8A6D2F` | Background behind every search match. |
| `search_fg` | string | `#F5E7C8` | Text colour of a search match. Empty keeps the colour it has. |
| `match_bg` | string | `#E5A93D` | Background behind the match the cursor is on. |
| `match_fg` | string | `#1C1B19` | Text colour of the match the cursor is on. Empty keeps it. |
| `cursor_bg` | string | `#39C5CF` | Background of the copy mode cursor block. |
| `cursor_fg` | string | `#08222B` | Text colour under the copy mode cursor. Empty keeps it. |
| `flash` | bool | `true` | Sweep a band of light over text that was just copied. Set motion to none to turn it off. |
| `flash_ms` | int | `420` | Milliseconds one copy sweep takes. Range 80 to 3000. |
| `flash_color` | string | (empty) | The light the copy sweep is made of. |
| `flash_style` | string | `diagonal` | The shape the copy sweep takes. Values: `diagonal`, `diagonal-reverse`, `horizontal`, `vertical`. |
| `multi_format` | string | `plain` | The format multi copy mode yanks in: plain, markdown or json. Values: `plain`, `markdown`, `json`. |
| `copy_entry` | string | `cursor` | Where copy mode puts its cursor: on the terminal cursor or in the center. Values: `cursor`, `center`. |
| `osc52_write` | string | `focused` | What happens when a program in a pane sets the clipboard: off, ask, focused (the focused pane only, others ask) or on. Values: `off`, `ask`, `focused`, `on`. |
| `copy_command` | string | (empty) | A command that gets each copy mode yank on stdin. Its output goes to the clipboard. If this is empty, tuios copies the selection as it is. |

`copy_command` is tmux's `copy-command`: every yank in copy mode goes to the
command on stdin, and its stdout goes to the clipboard. For per-key pipes, use
`[[keybindings.copy_pipe]]` (see [Keybindings](keybindings.md)).

```toml
[appearance.selection]
bg = "#45475A"
copy_entry = "center"          # copy mode starts on the middle row
osc52_write = "ask"            # a program setting the clipboard asks first
copy_command = "tr -d '\\r'"
```

### `[appearance.sidebar]`

The rail: the column of sessions, terminals, files and agents at one edge.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Show the session rail. |
| `position` | string | `right` | Edge the rail sits on, or hidden. Values: `left`, `right`, `hidden`. |
| `width` | int | `24` | Preferred rail width in columns on a wide screen. |
| `sections` | string | `sessions:25,terminals,files:25,agents:34` | Section names in the order the rail stacks them, each with an optional percent share. A name left out is a section the rail does not draw, and "spacer" is an empty block you may repeat. |
| `show_windows` | bool | `true` | Show the terminals section. **Deprecated:** folded into appearance.sidebar.sections on load; leave terminals out of the layout. |
| `show_agents` | bool | `true` | Show the agents section at the rail's bottom. **Deprecated:** folded into appearance.sidebar.sections on load; leave agents out of the layout. |
| `show_glyphs` | bool | `true` | Show the agent-state glyph on each row. |
| `show_counts` | bool | `true` | Show the window count on each session row. |
| `marquee` | bool | `true` | Scroll a hovered row's overflowing title. |
| `tooltips` | bool | `true` | Label the collapsed strip on hover. |
| `workspaces` | string | (empty) | Workspace chip band the rail used to draw. **Deprecated:** no longer used: panes name their own workspace, and switching lives on the dock and alt+1..9. |
| `file_icons` | bool | `true` | Draw a nerd font icon per file type in the files section. |
| `file_icon_colors` | bool | `true` | Draw each file icon in its file type's own colour. |
| `folder_click` | string | `navigate` | What a click on a folder row does. Values: `navigate`, `cd`, `both`. |
| `editor` | string | (empty) | The terminal editor that opens a text file. If this is empty, tuios uses $EDITOR, then $VISUAL, then vi. |
| `file_actions` | bool | `true` | Let the files section create, rename, delete, copy and paste. |
| `file_delete` | string | `trash` | Where a delete sends the file: the trash, or nowhere. Values: `trash`, `permanent`. |
| `agent_rest_fold` | string | `1h` | How long an agent row rests (idle, unknown, or done and seen) before the rail folds it into one line: a duration such as 1h, or off. |

`sections` is the order of the rail's sections, each with an optional share of
the rail's height as a percent: `sessions:25,terminals,files:25,agents:34`. A
section left out is not drawn, and `spacer` is an empty block you may repeat.

`editor` is the terminal editor that <kbd>Shift</kbd>+<kbd>Enter</kbd> opens a
text file with, and that file links and hints open files with. tuios splits it
into arguments (quote a path that contains spaces), runs no shell, and appends
the file's full path. Empty uses `$EDITOR`, then `$VISUAL`, then `vi`. tuios reads
the first 512 bytes to check the file is text, and refuses binary and special
files.

`agent_rest_fold` is how long an agent row rests (idle, unknown, or done and
seen) before the rail folds it into one `+N at rest` line, as a Go duration such
as `1h`, or `off`. A row that needs you, an unseen finished turn, a working
agent, the pane you are in, a pane with queued messages or one with subagents at
work is never folded.

```toml
[appearance.sidebar]
position = "left"
width = 28
sections = "sessions:30,terminals,agents:40"
editor = "nvim"
folder_click = "both"
file_delete = "trash"
agent_rest_fold = "30m"
```

### `[appearance.sidebar.agent_row]`

This table decides what an agent row on the rail shows, in what order and in
what ink. It is not scalar, so only the file sets it. It is read leniently: a
value tuios does not understand is dropped and reported as a warning, and the
rest of the table stands.

| Key | Type | Meaning |
|---|---|---|
| `tokens` | list of strings | The tokens the row draws, in order. |
| `[appearance.sidebar.agent_row.TOKEN]` | table | The look of one token: `fg`, `bold`, `dim`. |
| `[[appearance.sidebar.agent_row.TOKEN.rule]]` | array of tables | Value rules for one token, first match wins, at most 8. |

The tokens are `harness`, `name`, `state`, `elapsed`, `need`, `now`, `prompt`,
`context`, `subagents`, `meta`, `message`, `session` and `host`, plus `$key` for
one key of the pane's agent metadata (1 to 24 lower-case letters, digits, `_`
and `-`, starting with a letter), such as `$model`, `$cost` or `$plan`.

The shipped list is:

```toml
[appearance.sidebar.agent_row]
tokens = ["session", "need", "harness", "name", "elapsed", "context", "subagents", "meta", "now", "message"]
```

| Token | Draws |
|---|---|
| `need` | What the row wants from you: `approval`, `question`, `errored`, `finished` |
| `now` | What a working agent is doing, such as `Bash: go test ./...`; only while it works |
| `context` | `ctx 84%` in the warning ink, only at 80% full or more |
| `subagents` | `2 subagents` while any run |
| `prompt` | The first line of the last prompt (not in the shipped list) |
| `meta` | Other keys the pane reported with `tuios set-agent-meta`, leaving out the fed keys `now`, `prompt`, `model`, `context`, `cost`, `plan`, `subagents` |
| `elapsed` | Time in the current state; as a number for rules, in minutes |

`fg` takes `text`, `dim`, `muted`, `accent`, `warning`, `error`, `success`,
`info` or a `#rrggbb` literal. A rule has its look keys plus exactly one test:
`equals`, `contains`, `starts_with` (on the token as drawn), or `gt`, `lt` (on
the token as a number). There are no regular expressions here on purpose.

```toml
[appearance.sidebar.agent_row]
tokens = ["need", "harness", "name", "elapsed", "$model", "context", "now"]

[appearance.sidebar.agent_row.name]
fg = "text"
bold = true

[[appearance.sidebar.agent_row.elapsed.rule]]
gt = 30
fg = "warning"

[[appearance.sidebar.agent_row.need.rule]]
equals = "errored"
fg = "error"
bold = true
```

::: note
A `tokens` list you wrote keeps its own order and gains nothing when a release
adds a token. To see a new token, such as `subagents`, add it to your list.
:::

## The `[dock]` table

The dock is the bar at the top (or bottom) of the screen. `[dock]` is three
ordered lists of component names, one per region, plus a table per custom
component. Its position and its clock, CPU and RAM switches are
[`[appearance]` keys](#the-dock-and-the-clock).

### Regions

| Key | Type | Default |
|---|---|---|
| `left` | list of names | `["mode", "workspaces", "trail", "tape"]` |
| `center` | list of names | `["windows"]` |
| `right` | list of names | `["notifications", "copy-help", "cpu", "ram", "clock", "session-controls"]` |

Leave the table out and the bar is the default. Leave a name out and that
segment is not drawn. Reorder the names and the bar reorders. A list written as
`[]` draws nothing on that side, which is different from leaving the key out.
A name that is neither a built-in nor `custom/NAME` is a warning that names the
valid choices.

### Built-in components

| Name | What it draws |
|---|---|
| `mode` | The mode pill: window mode, terminal mode, copy mode |
| `workspaces` | The clickable workspace strip (`appearance.dock_workspace_tabs`) |
| `trail` | The workspace readout; it also says when a host link is being dialled again |
| `tape` | The project-tape badge (see [`[tape]`](#the-tape-table)) |
| `windows` | The window pills, minimized windows included |
| `notifications` | Dock messages; takes the right-hand end while it has something to say |
| `copy-help` | Copy-mode key help; takes the right-hand end while copy mode is on |
| `cpu` | CPU graph, when `appearance.show_cpu` is on |
| `ram` | RAM usage, when `appearance.show_ram` is on |
| `clock` | The clock, in `[dock.clock] format` |
| `session-controls` | Session buttons; always holds the bar's right-hand end and is never truncated |

Naming a built-in makes it eligible to draw; its own switch still decides.
`cpu` in the list with `show_cpu = false` draws nothing.

### `[dock.clock]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `dock.clock.format` | string | (empty) | Go time layout the clock renders in (empty means 15:04:05); a layout without seconds refreshes once a minute. |

The format is a Go time layout, and it also sets the cadence: a layout with
seconds refreshes every second, one without refreshes on the minute. The same
format drives the clock badge that `appearance.show_clock` turns on.

```toml
[dock]
right = ["notifications", "copy-help", "clock", "session-controls"]

[dock.clock]
format = "Mon 15:04"
```

### `[dock.custom.NAME]`

A custom component is a command whose first line of stdout becomes a cell.
Place it by writing `custom/NAME` in one of the region lists.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `command` | string | (required) | Run with `sh -c`. The first line of stdout is the cell. |
| `refresh` | string | `once` | When to run it: `once`, a duration such as `"30s"` (floor 1 s), `push`, or `event:TYPE[,TYPE...]`. |
| `on-click` | string | (none) | Run with `sh -c`, like a hook, when the cell is clicked. |
| `max-width` | int | `24` | The cell is cut to this many cells. |

| `refresh` | Behaviour | Idle cost |
|---|---|---|
| `event:TYPE` | Re-runs when the event happens. Types are the hook names (`after-focus-change`, `after-agent-state`, `after-workspace-switch`, `after-new-window`, `after-close-window`, `after-layout-change`, `after-attach`, `after-detach`, `after-resize`) or their event-hub spellings (`window-focused`, `agent-state`, `workspace-switched`, `window-created`, `window-closed`, `layout-changed`, `attached`, `detached`, `resized`). | None |
| `push` | The command keeps running and each line it writes is an update. | None |
| `"30s"` | Polls. One timer serves every polling component, and an unchanged value draws no frame. | One run per interval |
| `once` | Runs at startup, then only on `tuios refresh-dock NAME`. | None |

The command gets the session's environment plus `TUIOS_DOCK_COMPONENT`,
`TUIOS_SESSION` and `TUIOS_SOCKET`; an `on-click` command also gets
`TUIOS_CLICK_BUTTON`. SGR colour escapes survive; every other control sequence
is stripped. A command has a 3 second timeout, and only the first line is read.

A component that fails, times out or prints nothing is hidden, never left
showing a stale value. You are told once per failure streak. After five
failures in a row it stops polling until `tuios refresh-dock NAME` revives it.
Components run where the client runs: on the SSH host under `tuios ssh`, on the
tuios-web server for a browser client.

```toml
[dock]
left  = ["mode", "workspaces", "trail", "custom/branch"]
right = ["notifications", "copy-help", "custom/agents", "cpu", "ram", "clock", "session-controls"]

[dock.custom.branch]
command  = "~/.config/tuios/dock/git-branch.sh"
refresh  = "event:after-focus-change"
on-click = "tuios new-window log -- git log --oneline -20"

[dock.custom.agents]
command   = "~/.config/tuios/dock/agents.sh"
refresh   = "event:after-agent-state"
max-width = 16
```

```sh
tuios list-dock-components
tuios refresh-dock branch
```

The upstream recipes are in
[examples/dock](https://github.com/Gaurav-Gosain/tuios/tree/v0.8.5/examples/dock)
(`git-branch.sh`, `battery.sh`, `kube-context.sh`, `agents.sh`, `inbox.sh`).
Writing and debugging your own components is covered in
[Extending tuios](howto-extending.md).

## The `[notifications]` tables

### Dock message durations

| Key | Type | Default | Meaning |
|---|---|---|---|
| `notifications.duration` | int | `0` | Seconds an info message stays up. 0 uses the default. Range 0 to 3600. |
| `notifications.warning_duration` | int | `0` | Seconds a warning stays up. 0 uses the default. Range 0 to 3600. |
| `notifications.error_duration` | int | `0` | Seconds an error stays up when error_sticky is false. Range 0 to 3600. |
| `notifications.error_sticky` | bool | `true` | Make errors wait for esc instead of expiring. |

The durations are floors: a message that asks to stay longer still does.

```toml
[notifications]
duration = 6
error_sticky = true      # errors wait for Esc
```

### `[notifications.agent]`

What tuios does when a pane's agent state changes. The defaults are quiet on
purpose: only the states that mean an agent is waiting on you or has stopped
raise anything.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turn every agent alert on or off. |
| `notify` | bool | `true` | Send a desktop notification to the attached terminal. |
| `dock` | bool | `true` | Show the alert in the dock. Click it to go to the pane. |
| `sound` | bool | `false` | Make an alert audible. |
| `sound_mode` | string | (empty) | How an alert sounds: a cue, a BEL, or both. Values: `audio`, `bell`, `both`. |
| `sound_cooldown_seconds` | int | `3` | Shortest gap between two sounds, in seconds. 0 uses 3. Range 0 to 3600. |
| `settle_seconds` | int | `2` | Seconds to wait. tuios drops the alert if the pane changes state. Range 0 to 3600. |
| `suppress_focused` | bool | `true` | No alert for the focused pane while the terminal has focus. |
| `quiet_hours` | string | (empty) | Hours when nothing alerts. Write it as HH:MM-HH:MM. |
| `command` | string | (empty) | Shell command to run on an alert. Empty runs nothing. |

| Key | Detail |
|---|---|
| `enabled` | The master switch. `false` silences every sink below, the command included. |
| `notify` | An in-band desktop notification written to the terminal the client is attached to, so it reaches you even when the session is on another machine. |
| `dock` | A clickable dock message that jumps to the pane. |
| `sound`, `sound_mode` | See [Sounds, cue files and quiet hours](#sounds-cue-files-and-quiet-hours). |
| `settle_seconds` | Hold an alert this long and drop it if the pane leaves the state first, so a flapping agent gives one alert. `0` alerts at once. |
| `suppress_focused` | Drop alerts for the pane you are looking at. A pane counts as looked at while it is focused and the host terminal has not reported losing focus (focus events, DECSET 1004). |
| `quiet_hours` | `HH:MM-HH:MM` in local time; a window across midnight works. Every sink is silent inside it. |
| `command` | A shell command run on an alert, a shorthand for an `after-agent-state` hook. |

#### `[notifications.agent.states]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `needs_input` | bool | `true` | Alert when an agent waits for you. |
| `errored` | bool | `true` | Alert when an agent stops on an error. |
| `done` | bool | `true` | Alert when an agent reports it finished. |
| `idle` | bool | `false` | Alert when an agent goes quiet. |
| `working` | bool | `false` | Alert when an agent starts work. |

`idle` is guessed from silence by the stall timer, so it is the state that
flaps; it is off by default for that reason.

#### `[notifications.agent.sounds]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `needs_input` | path | built in | Cue file for an agent waiting on you, or one that errored |
| `done` | path | built in | Cue file for an agent that stopped (done or idle) |

```toml
[notifications.agent]
enabled = true
notify = true
dock = true
sound = true
sound_mode = "audio"
settle_seconds = 3
suppress_focused = true
quiet_hours = "22:30-07:30"

[notifications.agent.states]
needs_input = true
errored = true
done = true
idle = false
working = false

[notifications.agent.sounds]
needs_input = "~/.config/tuios/sounds/attention.wav"
done = "~/.config/tuios/sounds/done.wav"
```

### `[notifications.mail]`

What happens when agent mail arrives for you. Each key except
`between_agents` follows the same key in `[notifications.agent]` while unset,
so a config without this table alerts as `[notifications.agent]` says. Sound
mode, cooldown, cue files and quiet hours always come from
`[notifications.agent]`.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | (unset) | Turn mail alerts on or off. Unset follows notifications.agent.enabled. |
| `notify` | bool | (unset) | Send a desktop notification for mail. Unset follows notifications.agent.notify. |
| `dock` | bool | (unset) | Show a mail alert in the dock. Unset follows notifications.agent.dock. |
| `sound` | bool | (unset) | Make a mail alert audible. Unset follows notifications.agent.sound. |
| `between_agents` | bool | `false` | Alert on a message from one agent to another agent too. |

`between_agents` also alerts on a message from one agent to another, which
otherwise only counts on the recipient's rail row. To make a key follow again,
clear it:

```sh
tuios set-config notifications.mail.sound ""
tuios get-config notifications.mail.sound      # (follows notifications.agent.sound)
```

```toml
[notifications.mail]
dock = true
sound = false            # mail is quieter than an agent that needs you
between_agents = false
```

## Sounds, cue files and quiet hours

tuios has two cues, not one per state, because two sounds can be told apart by
ear in under half a second and a third would be guessed at:

| Cue | Plays for | Character |
|---|---|---|
| attention (`sounds.needs_input`) | `needs_input`, `errored` | Higher, longer, louder |
| done (`sounds.done`) | `done`, `idle` | Quiet, informational |

`sound = true` turns sound on. `sound_mode` decides what sound means:

| `sound_mode` | Effect |
|---|---|
| `audio` (default) | Play the cue through a system audio player |
| `bell` | Write a BEL and let your terminal decide (flash, sound, nothing) |
| `both` | Do each |

For `audio`, tuios uses the first player it finds, once per process:

| Platform | Players, in order |
|---|---|
| Linux, BSD | `paplay`, `pw-play`, `aplay -q`, `ffplay`, `mpv` |
| macOS | `afplay`, `ffplay`, `mpv` |
| Windows | `powershell` or `pwsh` (System.Media.SoundPlayer), `ffplay`, `mpv` |

A cue file is a path to a WAV file. A path that does not exist falls back to
the built-in cue, so a typo costs the custom sound and not all sound.
`aplay` and `pw-play` do not decode compressed formats, so use WAV for files
that must play everywhere; `afplay`, `ffplay` and `mpv` also play MP3 and
others.

- **Cooldown.** `sound_cooldown_seconds` (default 3) is the shortest gap
  between two audio cues, across every pane, so six agents finishing together
  make one sound. The bell is not rate-limited by tuios.
- **One at a time.** A single worker with a one-deep queue plays the cues,
  so cues never overlap.
- **No audio.** A machine with no working player goes quiet for the life of the
  process after a run of failures, and prints nothing.
- **Where it plays.** The cue plays where the client runs. Under `tuios ssh`
  and `tuios-web` that is the server, and tuios warns about it when the client
  starts; use `sound_mode = "bell"` to ring your own terminal. With
  `tuios attach --host`, the client runs on your machine.
- **Turn it all off.** `TUIOS_NO_SOUND=1` silences sound whatever the config
  says, for a test run, CI or a recording.

**Quiet hours** silence every sink: the notification, the dock message, the
sound, the command and the `after-agent-state` hook. The value is one window,
`HH:MM-HH:MM`, in the local time of the process that alerts. A window that
wraps midnight, such as `23:00-07:00`, is understood.

```toml
[notifications.agent]
sound = true
sound_mode = "both"
sound_cooldown_seconds = 5
quiet_hours = "23:00-07:00"
```

## The `[daemon]` table

| Key | Type | Default | Meaning |
|---|---|---|---|
| `log_level` | string | `off` | How much the daemon logs. Values: `off`, `errors`, `basic`, `messages`, `verbose`, `trace`. |
| `agent_autodetect` | bool | `true` | Detect a pane's foreground agent CLI and set its state glyph. |
| `agent_detect_seconds` | int | `0` | Seconds between checks. 0 uses 2. A negative number turns checks off. |
| `resume_agents` | string | `ask` | After a daemon restart, ask to resume each pane's agent conversation, resume it, or do neither. Values: `ask`, `auto`, `off`. |
| `persist_scrollback` | bool | `true` | Save each pane's history and show it again after a daemon restart. A change applies when the daemon next starts. |
| `persist_scrollback_lines` | int | `0` | Most history lines one pane saves. 0 uses 1000. A change applies when the daemon next starts. Range 0 to 1000000. |
| `persist_scrollback_kb` | int | `0` | Most KiB one pane's saved history takes on disk. 0 uses 2048. A change applies when the daemon next starts. Range 0 to 1048576. |
| `window_size` | string | `smallest` | The size of a session with more than one client: the smallest client, the largest client, or the client that last had input. Values: `smallest`, `largest`, `latest`. |

Two more keys are in the file but not in the registry:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `agent_binaries` | list of strings | `[]` | Extra binary names to treat as agents, added to the built-in list. |
| `respond_from_shell` | bool | `false` | Let `tuios respond`, run from a shell outside every pane, answer an agent's prompt with no client attached. A caller inside a pane is refused either way. |

- `agent_detect_seconds`: `0` uses the default of 2 seconds; a negative value
  turns detection off.
- `persist_scrollback_lines` `0` means 1000 and `persist_scrollback_kb` `0`
  means 2048 KiB (compressed). The saved history holds what your panes printed,
  secrets included. Turning `persist_scrollback` off deletes the saved history
  when the daemon next starts.
- `window_size` names follow tmux's `window-size`: `smallest` shows the full
  session to every client, `largest` and `latest` let a smaller client show
  part of it. See [Sessions](sessions.md).
- `resume_agents`: `ask` puts one Inbox item per restored agent pane, `auto`
  types each harness's resume command, `off` does neither.

```toml
[daemon]
log_level = "off"
agent_autodetect = true
agent_binaries = ["my-agent", "llm"]
resume_agents = "ask"
persist_scrollback = true
persist_scrollback_lines = 2000
window_size = "latest"
```

## The `[startup]` table

Settings that only take effect when a session starts.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `daemon` | bool | `true` | Make a bare "tuios" attach to a daemon-backed session instead of running standalone. TUIOS_NO_DAEMON=1 or --standalone overrides it. |
| `tiled` | bool | `true` | Start a new session tiled instead of floating. |
| `layout` | string | `bsp` | Tiling scheme a new session starts in. An existing session keeps its own. Values: `bsp`, `master-stack`, `scrolling`. |
| `open_default_window` | bool | `false` | Open one terminal automatically when a session starts empty. |
| `start_in_terminal_mode` | bool | `false` | Start focused in terminal mode, when a window is present. |

`daemon = true` makes bare `tuios` attach to a daemon-backed session, so the
session outlives the terminal window. It changes bare `tuios` and nothing else.
`--standalone` and `TUIOS_NO_DAEMON=1` override it, and if the daemon will not
start, bare `tuios` runs standalone for that run and says so.

::: warning
`tiled` and `daemon` default to `true` only in a file tuios writes. A file that
leaves them out reads them as `false`. Write both keys explicitly.
:::

```toml
[startup]
daemon = true
tiled = true
layout = "bsp"
open_default_window = true
start_in_terminal_mode = true
```

## The `[tape]` table

Project tapes are `.tuios.tape` files in a directory, detected when the focused
pane's shell enters that directory. See [Automation](automation.md).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `autorun` | string | `ask` | What happens on entering a directory with a project tape. Values: `off`, `ask`, `auto`. |
| `auto_review` | bool | `false` | Open the review dialog on detection instead of only badging it. |

| `autorun` | Behaviour |
|---|---|
| `off` | No detection, no indicator. |
| `ask` | A passive dock badge and a notification; nothing runs until you open the review dialog (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>t</kbd>) and choose Run. |
| `auto` | A trusted, unedited tape runs on entry. An untrusted or changed tape falls back to `ask`. |

`auto_review = true` opens the review dialog on detection instead of only
showing the badge. It never weakens trust: you still choose Run once, Trust and
run, Never or Not now. `TUIOS_TAPE_AUTORUN` overrides `autorun`.

```toml
[tape]
autorun = "ask"
auto_review = true
```

## The `[screenshot]` table

Defaults for `tuios screenshot` and the screenshot keys. See [CLI](cli.md).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `format` | string | `png` | Default output format for captures. Values: `png`, `svg`, `ansi`, `html`, `txt`. |
| `directory` | string | `~/Pictures/tuios` | Folder where capture files are saved. |
| `frame` | string | `window` | Dressing around the capture: a window card, a plain card, or nothing. Values: `window`, `plain`, `none`. |
| `background` | string | `auto` | Wash behind the card: auto derives it from the theme; none, a hex color, or hex..hex work too. |
| `controls` | string | `auto` | Window control marks: the macOS lights, your glyph set, or none. Values: `auto`, `macos`, `glyphs`, `none`. |
| `title_format` | string | `{title}` | Title bar text, with {title}, {index} and {cwd} tokens. |
| `font_family` | string | `JetBrains Mono, monospace` | Font to draw the capture in when your terminal does not say which it uses. |
| `font_file` | string | (empty) | Font file to draw PNG with, also embedded in SVG and HTML. It wins over every other font choice. |
| `scale` | int | `2` | PNG size multiplier. Range 1 to 4. |
| `padding` | int | `48` | Space around the card in pixels. Range 0 to 128. |
| `radius` | int | `10` | Card corner radius in pixels. Range 0 to 32. |
| `shadow` | bool | `true` | Draw a soft shadow under the card. |
| `cursor` | bool | `false` | Draw the cursor cell in the capture. |
| `copy` | bool | `true` | Try to copy the capture to the clipboard. |
| `preview` | bool | `true` | Open the preview panel after a capture. |

`background` takes `auto` (derived from the theme), `none`, a hex colour, or a
gradient written `#hex..#hex`. `title_format` takes `{title}`, `{index}` and
`{cwd}`.

```toml
[screenshot]
format = "png"
directory = "~/Pictures/tuios"
frame = "window"
background = "#1e1e2e..#313244"
font_family = "JetBrains Mono, monospace"
scale = 2
```

## The `[hints]` table

Hints mode (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>F</kbd>) labels URLs, paths,
hashes and addresses in the focused pane; typing a label copies one. See
[Keybindings](keybindings.md).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `builtins` | string | `all` | Built-in patterns hints mode looks for: all, none, or names such as url,path,sha. |
| `alphabet` | string | `asdfghjkl` | Letters the hint labels are made of, easiest first. |
| `open` | bool | `true` | Ctrl and a label opens the URL or path. It does not open on a remote client. |
| `dim` | int | `60` | Percent of its light the text around the hints loses. Range 10 to 90. |
| `all_panes` | bool | `false` | The hints key labels every pane on the workspace, not only the focused pane. |

| Key | Type | Default | Meaning |
|---|---|---|---|
| `patterns` | list of strings | `[]` | More Go regular expressions to label. A group named `match` narrows what is copied. Not in the registry. |

The built-in pattern names for `builtins` are `url`, `path`, `diff`, `sha`,
`ip`, `uuid`, `color`, `hex`, `number`, `email` and `id`. Write `all`, `none`, or
a comma-separated list.

```toml
[hints]
builtins = "url,path,sha,ip"
patterns = ['branch: (?P<match>\S+)', 'JIRA-\d+']
alphabet = "asdfghjkl"
all_panes = true
```

## Small feature tables

### `[scratch]`

The box in which <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>g</kbd> shows the scratch
terminal. See [Sessions](sessions.md).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `width` | string | `80%` | Width of the scratch terminal, in cells (60) or percent (80%). |
| `height` | string | `80%` | Height of the scratch terminal, in cells (20) or percent (80%). |

### `[pip]`

The picture-in-picture view that <kbd>p</kbd> pins in window mode.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `width` | int | `40` | Width of the picture-in-picture view, border included, in cells. Range 12 to 200. |
| `height` | int | `12` | Height of the picture-in-picture view, border included, in cells. Range 3 to 100. |
| `corner` | string | `bottom-right` | Corner the picture-in-picture view goes to first. It moves to another corner when the cursor enters it. Values: `bottom-right`, `bottom-left`, `top-right`, `top-left`. |

### `[spotlight]`

Lights one part of the screen and dims the rest.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `false` | Light one part of the screen and dim the rest. |
| `follow` | string | `mouse` | What the beam follows: the mouse, or the focused pane's cursor. The cursor sends fewer bytes to a remote client. Values: `cursor`, `mouse`. |
| `radius` | int | `10` | Half the beam's height, in rows. Range 2 to 200. |
| `dim` | int | `75` | Percent of its light an unlit cell loses. Range 10 to 95. |
| `edge` | string | `hard` | Cut the beam at its edge, or fade it out. A fade sends about three times the bytes each time the beam moves. Values: `hard`, `soft`. |
| `shake` | bool | `false` | Move the mouse left and right fast to turn the beam on and off. A shake does not move the beam. The follow setting decides where it goes. |

### `[screensaver]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `false` | Animate the screen after a spell with no input. |
| `idle_minutes` | int | `10` | Minutes of quiet before the screen saver starts. Range 1 to 240. |
| `effect` | string | `random` | Which effect runs, or random for a different one each time. Values: `random`, `binarypath`, `blackhole`, `bouncyballs`, `bubbles`, `burn`, `crumble`, `decrypt`, `errorcorrect`, `expand`, `fireworks`, `highlight`, `laseretch`, `matrix`, `middleout`, `orbittingvolley`, `overflow`, `pour`, `print`, `rain`, `randomsequence`, `rings`, `scattered`, `slice`, `slide`, `smoke`, `spotlights`, `spray`, `swarm`, `sweep`, `synthgrid`, `thunderstorm`, `tuffbaby`, `unstable`, `vhstape`, `waves`, `wipe`. |
| `while_busy` | bool | `false` | Start even when a pane is running a command or an agent. |

```toml
[scratch]
width = "80%"
height = "70%"

[pip]
width = 48
height = 14
corner = "top-right"

[spotlight]
enabled = false
follow = "cursor"     # sends fewer bytes to a remote client than mouse
edge = "soft"

[screensaver]
enabled = true
idle_minutes = 10
effect = "matrix"
while_busy = false
```

### `[debug]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `show_key_events` | bool | `false` | Show the on-screen keycast of recent keypresses. |

The showkeys overlay is a keycast in the bottom-right corner. The same overlay
is toggled by `--show-keys`, the settings page, the palette and
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> <kbd>k</kbd>.

```toml
[debug]
show_key_events = false
```

## The `[hosts]` and `[tailscale]` tables

`[hosts.NAME]` names a machine this one links to, and, read on the machine a
link arrives at, says what that machine may do there. None of it is in the
registry. See [Sessions](sessions.md) for linking and
[Agents](agents.md) for mail.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `addr` | string | (none) | Anything ssh understands, `ssh_config` aliases included. A table with no `addr` is a policy only: nothing is dialled and `tuios hosts` does not list it. |
| `connect_timeout` | int (seconds) | built in | How long one dial may take before the host is called unreachable; also handed to ssh. |
| `command` | string | found | The tuios binary on the far side. Empty: the PATH, known install paths, then the login shell. |
| `ssh_options` | list of strings | `[]` | Extra ssh arguments, from a safe list only (see below). |
| `repos_root` | string | (host default) | Where the host's checkouts live, absolute or `~/`, for commands that name a repository by URL. |
| `allow` | list of strings | `["list", "mail", "open", "write"]` | What the machine of this name may do here. `[]` allows nothing but `hello`. |
| `hold_mail` | bool | `false` | Hold mail from that machine to agents here in your Inbox until you pass it on. |
| `hosted_grace` | duration | `"10m"` | How long a pane this machine runs for the other one outlives a dropped link. `"0"` ends it with the link; at most 24 h. |

| Capability | Lets the other machine |
|---|---|
| `list` | Read sessions, windows, captures, screenshots, agent state, the Inbox, prompts, waits and events. |
| `mail` | Send and read agent mail, and use the stash. |
| `open` | Start sessions, windows, worktrees, fans, agents, clones, and hosted panes. |
| `write` | Type into panes, run lines, close and move windows, set options and layouts, report agent state, attach, pull worktrees. |
| `respond` | Answer for you: prompts, approvals, `ask-human` questions, Inbox dismissals, held mail. Opt-in only. |

Each field inherits from `[hosts."*"]`, then from the default. Names match
without regard to case. `ssh_options` accepts only options that cannot run code
or write files, each as `-o Keyword=value` or a plain flag such as `-p`, `-i`,
`-l`, `-J` (host names only); `ProxyCommand`, `LocalCommand`, known-hosts
files, `ControlPath`, socket forwards and `-F` are refused, and a host with a
refused entry is ignored.

```toml
[hosts.build]
addr = "ubuntu@build.example.ts.net"
connect_timeout = 8
repos_root = "~/src"
ssh_options = ["-o", "ServerAliveInterval=30"]
allow = ["list", "mail"]

[hosts.laptop]
allow = ["list", "mail", "open", "write", "respond"]
hold_mail = true
hosted_grace = "30m"

[hosts."*"]
allow = ["list", "mail"]
```

`[tailscale]` decides which tailnet machines tuios offers as addresses when
you add a host. The list comes from the local `tailscaled`, costs one local
call, and is empty off a tailnet.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Offer tailnet machines at all. |
| `addr` | string | `dns` | Address form: `dns` (MagicDNS name), `name` (short name), `ip` (100.x). |
| `user` | string | (none) | An ssh login put in front of every address. |
| `users` | table | (none) | Per-machine logins by short name; wins over `user`. |
| `os` | list | daemon-capable OSes | Operating systems to offer; `[]` offers every machine. |
| `offline` | bool | `false` | Offer machines that are not connected. |
| `self` | bool | `false` | Offer this machine. |
| `shared` | bool | `false` | Offer machines shared into the tailnet. |
| `include`, `exclude` | lists of globs | `[]` | Match short and MagicDNS names; `exclude` wins, empty `include` means all. |
| `max` | int | built in | Bound on the offered list. |
| `socket` | string | found | Path to the tailscaled local API socket. |

```toml
[tailscale]
addr = "dns"
user = "ubuntu"
exclude = ["*-phone", "nas*"]

[tailscale.users]
mac-mini = "you"
```

## The `[agents]` tables

These tables configure agent detection, approvals, permissions and the work
queue. None of them is in the registry, so a pane cannot change them through
`tuios set-config`. The full behaviour is in [Agents](agents.md).

### `[agents]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `herdr_protocol` | string | `always` | Which panes get herdr's environment (`HERDR_ENV=1`, `HERDR_SOCKET_PATH` and so on) so Crush and other herdr reporters report to tuios: `always`, `agents` (only panes that start a known reporter directly), `off`. An unknown value reads as `always`, with a warning. |

### `[agents.approvals]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | list | `[]` (off) | Harnesses whose permission prompts the Inbox may answer: `claude-code` (or `claude`), `opencode`, `kilo`, `qwen`. |
| `hold_seconds` | int | `120` | How long a prompt waits in the Inbox before the harness asks in its pane; kept between 10 and 300. |
| `hold_plans` | bool | `true` | Also hold a plan-mode approval (Claude Code's `ExitPlanMode`) for the harnesses in `enabled`. |

Only a call the Inbox can show whole on one line is held. After an upgrade, run
`tuios integration install claude-code` (or the other harness) again.

### `[agents.approvals.risk]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `builtin` | bool | `true` | Keep the shipped risk rules. |
| `panes_may_allow` | bool | `false` | Let a pane with the `respond` grant allow a risky call. |
| `[[agents.approvals.risk.rule]]` | array of tables | none | Rules of your own: `name`, `tools` (empty: every tool), `pattern` (RE2). |

A rule matches each command of a shell call and the whole text of any other.
Naming one shell tool (such as `Bash`) covers every shell tool, and naming one
file tool (such as `Write`) every file tool. A rule with no name or a pattern
that does not compile is ignored, with a warning. Allowing a risky approval
takes a second press in the Inbox.

### `[agents.recap]` and `[agents.queue]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `recap.mode` | string | `toast` | Where the away recap shows: `toast` (dock and Inbox), `inbox`, `off` (only `agent-log`). |
| `recap.away` | duration | `10m` | How long you must be away for the dock to show it. |
| `recap.test_patterns` | list | built in | Commands that count as a test run. |
| `queue.max` | int | `8` | Messages one pane's queue holds; at most 64. Past it, `queue_full`. |

### `[agents.permissions]`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `mode` | string | `open` | `open`: every pane holds `admin`. `strict`: a pane holds `grants`. Any other value reads as `strict`. |
| `grants` | list | `["read", "write", "fan"]` | What a pane holds under `strict` when it was started with no grants of its own. `[]` gives nothing but self-reporting. |

The grants are `read`, `write`, `fan`, `respond` and `admin`. `admin` never
includes `respond`. A change that gives panes less applies at the next call; a
change that gives more waits for `tuios config apply` from outside tuios.

```toml
[agents]
herdr_protocol = "agents"

[agents.approvals]
enabled = ["claude-code", "opencode"]
hold_seconds = 120

[agents.approvals.risk]
builtin = true

[[agents.approvals.risk.rule]]
name = "kubectl apply"
tools = ["Bash"]
pattern = '\bkubectl\s+(apply|delete)\b'

[agents.recap]
mode = "toast"
away = "15m"
test_patterns = ["go test", "pytest", "bun test"]

[agents.queue]
max = 8

[agents.permissions]
mode = "strict"
grants = ["read", "write", "fan"]
```

## The `[keybindings]` tables

Keys are configured in `[keybindings]` (`leader_key`) and one sub-table per
scope, such as `[keybindings.window_management]`, `[keybindings.prefix_mode]`,
`[keybindings.terminal_mode]`, `[keybindings.global]` and
`[keybindings.sidebar]`. Each entry maps an action name to a list of keys, an
action left out keeps its default keys, and an action set to `[]` has none.
`[[keybindings.command]]` binds a key to a command you write, and
`[[keybindings.copy_pipe]]` pipes a copy-mode selection through one. Key edits
take effect in the next client. Every scope, action, default and the
`tuios keybinds` tools are in [Keybindings](keybindings.md).

```toml
[keybindings]
leader_key = "ctrl+a"

[keybindings.prefix_mode]
copy_mode_search_backward = ["/"]
```

## Themes

A theme supplies the sixteen ANSI colours plus foreground, background and
cursor. Programs in panes paint with those colours, and tuios derives its own
chrome (borders, pills, the dock, overlays) from them, or from an optional
`chrome` object in the theme file. Upstream reference:
[THEMES.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/THEMES.md).

### The built-in themes

v0.8.5 ships 342 themes. Ids are lowercase with underscores
(`catppuccin_mocha`, not `catppuccin-mocha`).

| Initial | Theme ids |
|---|---|
| 0-9 | `3024_day`, `3024_night` |
| A | `aardvark_blue`, `abernathy`, `adventure`, `adventure_time`, `afterglow`, `alabaster`, `alien_blood`, `andromeda`, `apple_classic`, `arcoiris`, `argonaut`, `arthur`, `atelier_sulphurpool`, `atom`, `atom_one_light`, `aurora`, `ayu`, `ayu_light`, `ayu_mirage` |
| B | `banana_blueberry`, `batman`, `belafonte_day`, `belafonte_night`, `birds_of_paradise`, `blazer`, `blue_berry_pie`, `blue_dolphin`, `blue_matrix`, `bluloco_dark`, `bluloco_light`, `borland`, `breeze`, `bright_lights`, `broadcast`, `brogrammer`, `bubbles`, `builtin_dark`, `builtin_light`, `builtin_pastel_dark`, `builtin_solarized_dark`, `builtin_solarized_light`, `builtin_tango_dark`, `builtin_tango_light` |
| C | `c_64`, `calamity`, `catppuccin_frappe`, `catppuccin_latte`, `catppuccin_macchiato`, `catppuccin_mocha`, `cga`, `chalk`, `chalkboard`, `challenger_deep`, `chester`, `ciapre`, `clrs`, `cobalt_2`, `cobalt_neon`, `coffee_theme`, `contrast_light`, `coolnight`, `crayon_pony_fish`, `crystal_violet`, `cyber_cube`, `cyber_punk_2077`, `cyberdyne`, `cyberpunk` |
| D | `dark_pastel`, `dark_plus`, `darkermatrix`, `darkmatrix`, `darkside`, `deep`, `desert`, `dimmed_monokai`, `django`, `django_reborn_again`, `django_smooth`, `doom_one`, `doom_peacock`, `dot_gov`, `dracula`, `dracula_plus`, `duckbones`, `duotone_dark` |
| E | `earthsong`, `elemental`, `elementary`, `encom`, `espresso`, `espresso_libre`, `everblush` |
| F | `fahrenheit`, `fairyfloss`, `fideloper`, `firefox_dev`, `firewatch`, `fish_tank`, `flat`, `flatland`, `floraverse`, `forest_blue`, `framer`, `front_end_delight`, `fun_forrest` |
| G | `galaxy`, `galizur`, `ganyu`, `git_hub_dark`, `github`, `glacier`, `glorious`, `grape`, `grass`, `grey_green`, `gruvbox_dark`, `gruvbox_dark_hard`, `gruvbox_light`, `guezwhoz` |
| H | `h_4_rithd`, `h_4_rithd_com`, `ha_x_0_r_blue`, `ha_x_0_r_gr_33_n`, `ha_x_0_r_r_3_d`, `hacktober`, `hardcore`, `harper`, `highway`, `hipster_green`, `hivacruz`, `homebrew`, `hopscotch`, `hopscotch_256`, `horizon`, `hurtado`, `hybrid`, `hyper` |
| I | `i_term_2_dark_background`, `i_term_2_default`, `i_term_2_light_background`, `i_term_2_pastel_dark_background`, `i_term_2_smoooooth`, `i_term_2_solarized_dark`, `i_term_2_solarized_light`, `i_term_2_tango_dark`, `i_term_2_tango_light`, `ic_green_ppl`, `ic_orange_ppl`, `iceberg_dark`, `iceberg_light`, `idea`, `idle_toes`, `ir_black` |
| J | `jackie_brown`, `japanesque`, `jellybeans`, `jet_brains_darcula`, `jubi`, `juicy_colors` |
| K | `kanagawa`, `kanagawabones`, `kibble`, `kolorit`, `konsolas` |
| L | `lab_fox`, `laser`, `later_this_evening`, `lavandula`, `liquid_carbon`, `liquid_carbon_transparent`, `liquid_carbon_transparent_inverse`, `lovelace` |
| M | `man_page`, `mariana`, `material`, `material_dark`, `material_darker`, `material_design_colors`, `material_ocean`, `mathias`, `matrix`, `medallion`, `midnight_in_mojave`, `mirage`, `misterioso`, `molokai`, `mona_lisa`, `monokai_cmder`, `monokai_pro`, `monokai_pro_filter_octagon`, `monokai_pro_filter_ristretto`, `monokai_remastered`, `monokai_soda`, `monokai_vivid`, `moonlight_ii` |
| N | `n_0_tch_2_k`, `neobones_dark`, `neobones_light`, `neon`, `neopolitan`, `neutron`, `night_lion_v_1`, `night_lion_v_2`, `night_owlish_light`, `niji`, `nocturnal_winter`, `nord`, `nord_light`, `novel` |
| O | `obsidian`, `ocean`, `oceanic_material`, `oceanic_next`, `ollie`, `one_dark`, `one_half_dark`, `one_half_light`, `one_star`, `operator_mono_dark`, `overnight_slumber` |
| P | `pale_night_hc`, `pandora`, `paraiso_dark`, `paul_millr`, `pencil_dark`, `pencil_light`, `peppermint`, `piatto_light`, `pnevma`, `popping_and_locking`, `primary`, `primer`, `pro`, `pro_light`, `purple_rain`, `purplepeter` |
| Q | `qb_64_super_dark_blue` |
| R | `rapture`, `raycast_dark`, `raycast_light`, `rebecca`, `red_alert`, `red_planet`, `red_sands`, `relaxed`, `retro`, `retrowave`, `rippedcasts`, `rose_pine`, `rose_pine_dawn`, `rose_pine_moon`, `rouge_2`, `royal`, `ryuuko` |
| S | `sakura`, `scarlet_protocol`, `sea_shells`, `seafoam_pastel`, `seoulbones_dark`, `seoulbones_light`, `serendipity_midnight`, `serendipity_morning`, `serendipity_sunset`, `seti`, `shades_of_purple`, `shaman`, `slate`, `sleepy_hollow`, `smyck`, `snazzy`, `soft_server`, `solarized_darcula`, `solarized_dark___patched`, `solarized_dark_higher_contrast`, `sonoran_gothic`, `sonoran_sunrise`, `space_gray`, `space_gray_eighties`, `space_gray_eighties_dull`, `spacedust`, `spiderman`, `spring`, `square`, `sublette`, `subliminal`, `sundried`, `symfonic`, `synthwave`, `synthwave_alpha`, `synthwave_everything` |
| T | `tango_adapted`, `tango_half_adapted`, `teerb`, `terminal_basic`, `thayer_bright`, `the_hulk`, `tinacious_design_dark`, `tinacious_design_light`, `tokyo_night`, `tokyo_night_light`, `tokyo_night_storm`, `tokyonight`, `tokyonight_day`, `tokyonight_storm`, `tomorrow`, `tomorrow_night`, `tomorrow_night_blue`, `tomorrow_night_bright`, `tomorrow_night_burns`, `tomorrow_night_eighties`, `toy_chest`, `treehouse`, `twilight` |
| U | `ubuntu`, `ultra_dark`, `ultra_violent`, `under_the_sea`, `unholy`, `unikitty`, `urple` |
| V | `vaughn`, `vibrant_ink`, `vimbones`, `violet_dark`, `violet_light` |
| W | `warm_neon`, `wez`, `whimsy`, `wild_cherry`, `wilmersdorf`, `wombat`, `wryan` |
| Z | `zenbones`, `zenbones_dark`, `zenbones_light`, `zenburn`, `zenburned`, `zenwritten_dark`, `zenwritten_light`, `zeonica` |

### Selecting a theme

| Where | How |
|---|---|
| Config file | `[appearance] theme = "dracula"` |
| Command line, one client | `tuios --theme dracula` (wins over the file) |
| Running session | `tuios set-config appearance.theme dracula` |
| In the app | Command palette, **Theme picker**; or the settings page **Theme** row |
| No theme | `theme = ""`; panes use your terminal's own colours |

```sh
tuios --list-themes                          # every id, custom ones included, then exit
tuios --preview-theme dracula                # print the 16 ANSI colours as swatches
tuios --theme "$(tuios --list-themes | fzf --preview 'tuios --preview-theme {}')"
```

`--preview-theme` prints a colour swatch, the slot name and the hex value for
each of the sixteen slots, normal (0-7) then bright (8-15), for example
`Red  #ff5555` for dracula's slot 1.

Against a running daemon, the `list-themes` subcommand filters, describes and
measures:

```sh
tuios list-themes --filter gruvbox
tuios list-themes dracula
tuios list-themes --json | jq -r .active
tuios list-themes catppuccin_latte --json | jq -r '.palette.illegible[]'
```

```text
dracula  (Dracula)  dark, background #1e1f28

   fg             #f8f8f2  15.37:1  needs 4.5
   cursor         #bbbbbb   8.53:1  needs 3.0
 ! black          #000000   1.28:1  needs 3.0
   red            #ff5555   5.21:1  needs 3.0
   ...
 ! bright_black   #555555   2.20:1  needs 3.0
   ...

2 of these do not clear their floor on this background: black, bright_black
tuios adjusts a border drawn in one of them so it stays visible. Text printed in one stays as the theme wrote it.
```

Each colour is measured against the theme's own background: 4.5:1 for the
foreground and 3:1 for the rest. A dim black failing is normal; a foreground
under 4.5 is the one to fix.

An unknown theme name in the file logs a warning and leaves the colours as they
were; tuios still starts. `set-config` refuses an unknown id with
`no theme named "ID"`.

### Custom theme files

A custom theme is a `.json` file directly in the themes directory
(`~/.config/tuios/themes/` on Linux; `tuios list-themes` prints the real path).
Every file there is registered beside the built-ins at startup, so it is
selected exactly like one. A file that does not parse is skipped with a
warning, and the others still load.

The directory is read again on every `tuios list-themes`, and when an id that
is not registered is selected with `set-config`. So you can write a file and
select it without a restart. Selecting an id that is already registered does
not re-read its file: to see an edit to a loaded theme, restart tuios or save
it under a new id.

| Key | Type | Fallback when omitted |
|---|---|---|
| `id` | string | The filename, lowercased, without `.json` (`My-Theme.json` is `my-theme`) |
| `display_name` | string | The `id` |
| `fg` | colour | `#e5e5e5` |
| `bg` | colour | `#000000` |
| `cursor` | colour | The resolved `fg` |
| `black`, `red`, `green`, `yellow`, `blue`, `purple`, `cyan`, `white` | colour | xterm defaults: `#000000`, `#cd0000`, `#00cd00`, `#cdcd00`, `#0000ee`, `#cd00cd`, `#00cdcd`, `#e5e5e5` |
| `bright_black` ... `bright_white` | colour | The non-bright counterpart |
| `chrome` | object | All chrome roles derived (see below) |

A colour is a hex string (`"#e06c75"`) or an RGBA object
(`{"r": 224, "g": 108, "b": 117, "a": 255}`). The magenta slot is called
`purple`, not `magenta`.

::: warning
A theme that defines only the eight normal colours draws bright text the same
as normal text, because each bright slot falls back to its counterpart. Define
all sixteen.
:::

The optional `chrome` object names tuios's own colours directly, so you can
give the chrome an amber accent without putting amber in `bright_blue` and
recolouring every bold blue `ls` prints:

| `chrome` key | Colours | Derived from when absent |
|---|---|---|
| `accent` | Logo, selected row, window-mode pill | `bright_blue` |
| `accent_bright` | Secondary accent, focused border in window mode | `bright_cyan` |
| `success` | Terminal-mode pill, focused border in terminal mode, success messages | `bright_green` |
| `warning` | Copy-mode pill, warnings | `yellow` |
| `error` | Errors, alert ink | `red` |
| `info` | Info messages | `blue` |
| `surface` | Fill of every dialog: palette, pickers, context menu, which-key | A constant neutral |
| `canvas` | Darkest step of the neutral ramp | Derived from `surface` |
| `panel` | Outer band and selected-row bar | Derived from `surface` |
| `card` | Inset chips and input fields | Derived from `surface` |

A `chrome` field that is not a hex colour is dropped on its own and that role
derives as usual. The text tiers of the chrome are never set by a file: they
are derived by contrast against `surface`, so a light `surface` gets dark text.

A complete theme file:

```json
{
  "id": "harbor",
  "display_name": "Harbor Night",

  "fg": "#d8dee9",
  "bg": "#14181f",
  "cursor": "#f2c572",

  "black":   "#1c222b",
  "red":     "#e06c75",
  "green":   "#98c379",
  "yellow":  "#e5c07b",
  "blue":    "#61afef",
  "purple":  "#c678dd",
  "cyan":    "#56b6c2",
  "white":   "#abb2bf",

  "bright_black":  "#4b5563",
  "bright_red":    "#ef7a83",
  "bright_green":  "#a9d18a",
  "bright_yellow": "#f0cc8c",
  "bright_blue":   "#72bcff",
  "bright_purple": "#d788ee",
  "bright_cyan":   "#67c5d3",
  "bright_white":  "#f5f7fa",

  "chrome": {
    "accent":        "#f2c572",
    "accent_bright": "#ffd98e",
    "success":       "#a9d18a",
    "warning":       "#f0cc8c",
    "error":         "#ef7a83",
    "info":          "#72bcff",
    "surface":       "#1b2029"
  }
}
```

```sh
dir=$(tuios list-themes --json | jq -r '.themes_dir // empty')
cp harbor.json "${dir:-$HOME/.config/tuios/themes}/"
tuios list-themes harbor                 # check contrast before you look
tuios set-config appearance.theme harbor
```

::: note
`border_focused_color` and `border_unfocused_color` in `[appearance]` override
a theme's border colours and are not part of the theme file. Use
`tuios --preview-theme ID` or `tuios list-themes ID` to check a theme: a file
that parses loads, whatever its colours are.
:::

### Importing a terminal colour scheme

`tuios import-theme FILE` converts a kitty, ghostty, alacritty or wezterm
scheme into a theme file in the themes directory. The format is read from the
content, not the file name: kitty's `key value` lines, ghostty's `key = value`
lines (with `palette = N=#rrggbb` entries), and alacritty's or wezterm's TOML.
Colours the scheme does not set fall back to the xterm defaults. The theme is
registered as it is written, so the id it prints is selectable at once.

| Flag | Meaning |
|---|---|
| `--name ID` | Theme id to write (default: the file's name) |
| `--json` | Print the result as JSON |

```sh
tuios import-theme ~/.config/kitty/current-theme.conf
tuios import-theme ~/.config/ghostty/config --name mine
tuios import-theme ~/gruvbox.toml --name gruvbox && tuios set-config appearance.theme gruvbox
```

### Light and dark

tuios decides whether a background is light or dark by its luminance, with
hysteresis: a dark verdict turns light only above an 8-bit luminance of 140,
and a light one turns dark only below 110, so a mid grey does not flip.

- **With a theme**, the theme's background decides. On a light theme the dialog
  ramp is built from the background (a dialog is a light panel, not a dark
  slab), accents are darkened just enough to read (4.5:1 for text, 3:1 for
  marks), and `modal_dim` fades toward the background instead of darkening.
- **With no theme**, the host terminal's background decides. When it starts or
  attaches, a client asks its terminal for its background, foreground and
  sixteen colours, and draws the chrome with the light ramp on a light
  terminal.
- **Following the system.** A local client turns on mode 2031. A terminal that
  supports it (ghostty, kitty, contour and others) then reports switches
  between light and dark appearance; tuios asks for the colours again, tells
  the panes and redraws the chrome. SSH and browser clients ask once when they
  attach and do not follow the switch.
- **Terminals that do not answer** (mosh, for example) leave the defaults:
  panes are told a black background and white text, and the chrome uses its
  dark ramp. Set a theme or `pane_background` to give panes a real answer.

There is no separate light and dark theme pair in v0.8.5: `appearance.theme`
is one id. To switch with the system, call `tuios set-config appearance.theme`
from a script that watches your desktop's appearance.

### OSC colour queries

Programs such as editors ask the terminal for its colours with OSC 10
(foreground), OSC 11 (background) and OSC 4 (palette entries) and pick a light
or dark palette from the answer. tuios answers for each pane:

| Situation | OSC 11 / OSC 10 answer | OSC 4 answer |
|---|---|---|
| The program set its own colours with OSC 10/11 | Its own colours | - |
| `pane_background` paints a colour | That colour / the text colour tuios uses there | Theme or host palette |
| A theme, pane background off | The theme's `bg` / `fg` | The theme's sixteen |
| No theme, pane background off | The host terminal's own colours | The host terminal's sixteen |

Each client asks its own terminal, so an SSH client on a light terminal and a
local client on a dark one each get the right answer while they are the one
typing. In a daemon session the daemon's emulator answers, using what the
client told it at its last sync; with several clients, the last to sync
decides.

```sh
# inside a pane: ask for the background (the reply arrives on the tty)
printf '\033]11;?\033\\'
```

### Colour depth

The chrome is designed for each colour depth separately, and the depth is read
the usual way:

| Depth | Detected when | Chrome |
|---|---|---|
| truecolor | `COLORTERM=truecolor` or `24bit`, or a known terminal (kitty, ghostty, wezterm, alacritty, foot) | The designed ramp |
| 256 | `TERM` ends in `256color` with no `COLORTERM` (Apple Terminal, mosh, tmux without `Tc`) | Greys from the xterm ramp 232-255; accents to the nearest palette entry in OKLab |
| 16 | `TERM=xterm`, `TERM=linux`, `NO_COLOR` | No painted grounds; thin frame lines; reverse video for the selected row; colours are your palette's slots |

At 16 colours a theme's `chrome` RGB values have no slot, so they give way to
the slots their roles derive from. mosh 1.4 and later pass 24-bit colour but do
not forward `COLORTERM`; set it on the remote side:

```sh
export COLORTERM=truecolor
```

## Glyph sets

A theme decides what colour the chrome is; a glyph set decides what shape it
is: the border corners, the window controls, rules and separators, and the
marks on the rail. It is one option, `appearance.glyphs`, plus a JSON format
for your own. Upstream reference:
[GLYPHS.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/GLYPHS.md).

### The built-in sets

| Id | What it is |
|---|---|
| `default` | What tuios ships: rounded frame, Nerd Font powerline caps, `✕` and `□` controls |
| `unicode` | Box drawing and geometric shapes, with no Nerd Font private-use glyphs, for a good font that is not patched |
| `heavy` | One stroke weight heavier throughout, border and junctions included |
| `ascii` | Nothing outside 7-bit ASCII |

### Selecting a set

```toml
[appearance]
glyphs = "heavy"
```

```sh
tuios set-config appearance.glyphs heavy     # live, no restart
tuios list-glyphs                            # sets, roles, the active set, the directory
tuios list-glyphs heavy                      # role by role: what the set says, what draws
```

```text
heavy  (Heavy)

   add                   -      +
   border.top_left       ┏      ┏
   close                 -      ✕
   focus                 █      █
   rule                  ━      ━
   ...

columns: role, what the set says, what draws. ! marks a role the set
named and did not get.
the border rows are what this set would draw; border_style is "rounded", so
nothing draws them. set appearance.border_style to "glyphs" to use them.
```

On the settings page, the **Glyph set** row sits under **Theme** and opens a
picker that previews each set live.

### The border

A set may define a border, but the border that draws is whichever
`appearance.border_style` names. `glyphs` is the style that means "the active
set's border":

```toml
[appearance]
glyphs = "heavy"
border_style = "glyphs"
```

A set that names only some border runes gets the rounded border for the rest,
so "square corners, everything else as usual" is four lines.

### Roles

| Group | Roles |
|---|---|
| Window controls | `close`, `maximize`, `minimize`, `dot` (traffic-light disc), `pill_left`, `pill_right` |
| Rules and separators | `rule` (hairline), `separator` (dock gap), `arrow_left`, `arrow_right` (overflow chevrons) |
| Rail marks | `focus`, `attention`, `bullet`, `add`, `collapse`, `expand`, `tree_branch`, `tree_last`, `fold_open`, `fold_shut` |
| Files section | `folder`, `parent` (the `..` row), `file` (drawn when file icons are off or in ASCII mode) |
| Scrollbar | `scrollbar_thumb`, `scrollbar_track` |
| Text | `ellipsis`, `sigil`, `dash_rule` |
| Border (`border` object) | `top`, `bottom`, `left`, `right`, `top_left`, `top_right`, `bottom_left`, `bottom_right`, `middle`, `middle_top`, `middle_bottom`, `middle_left`, `middle_right` |

Most roles must be exactly one cell wide. A glyph of the wrong width is dropped
back to the default and reported under `problems`, because the window controls'
click targets are fixed offsets. `separator`, `ellipsis`, `collapse` and
`expand` may be any width. Border runes must be one cell.

### Writing a set

Write `ID.json` in the glyphs directory (the path `tuios list-glyphs` prints).
Every field is optional:

| Key | Meaning |
|---|---|
| `id` | The set's id; default is the file name |
| `display_name` | Name shown in the picker |
| `inherits` | A set to start from, usually a built-in; followed up to eight levels, a loop stops |
| any role name | The glyph for that role |
| `border` | An object with the border roles |

A role you leave out keeps what the inherited set says, falling through to
what tuios ships. The directory is read again whenever a set is looked up, so a
new file is selectable at once. Saved as `square-heavy.json`, this set has the
id `square-heavy`:

```json
{
  "display_name": "Square Heavy",
  "inherits": "heavy",
  "bullet": "◦",
  "focus": "▐",
  "attention": "▲",
  "close": "x",
  "separator": " │ ",
  "ellipsis": "…",
  "border": {
    "top_left": "┏",
    "top_right": "┓",
    "bottom_left": "┗",
    "bottom_right": "┛"
  }
}
```

```sh
tuios set-config appearance.glyphs square-heavy
tuios set-config appearance.border_style glyphs
tuios list-glyphs square-heavy --json | jq -r '.problems[]?'
```

```text
glyph set mine: close is 2 cells wide and the layout budgets 1, so it keeps the default
```

That line is what a problem looks like. `problems` is present only when there
are any, so an empty result means every role drew.

### What the terminal can draw

When the config names no glyph set and `--ascii-only` is not given, each local
client reads its environment when it starts:

- **A locale that is not UTF-8.** The first of `LC_ALL`, `LC_CTYPE` and `LANG`
  that is set decides. A value such as `C`, `POSIX` or `en_US.ISO-8859-1`
  makes tuios run as if `--ascii-only` were given. None of the three set at
  all is not read as the C locale.
- **`TERM=linux`.** The Linux console has box drawing and no Nerd Font icons,
  so the chrome takes the `unicode` set and the dock, notification and
  context-menu icons take their ASCII forms.

A glyph set in the config, or `--ascii-only`, always wins. `tuios list-glyphs`
says what the terminal it runs in would pick and why. Clients served by
`tuios ssh` and `tuios-web` are not detected this way, since the server's
environment says nothing about the remote terminal.

### ASCII mode

`--ascii-only` says the terminal cannot draw beyond 7-bit ASCII. It overrides
a glyph set **per role**: a set keeps each role it spelled in ASCII and gives up
the rest. It also replaces the dock's semantic icons (the mode chip, the
counts, the session controls), which no glyph set can change.

```sh
tuios --ascii-only
tuios list-glyphs ascii --json | jq .set.ascii    # true: drawable anywhere
```

::: note
The upstream glyph documentation mentions an `ascii_only` config key, but the
v0.8.5 config struct has no such field. Use the `--ascii-only` flag, or
`glyphs = "ascii"` for the shapes alone.
:::

## Hooks

A hook runs a shell command when something happens, with `TUIOS_*`
environment variables carrying the facts. Hooks are configured in `[hooks]`
and are not in the registry. Upstream reference:
[HOOKS.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/HOOKS.md).

### The table

Each event takes one command or a list of commands, each run with `sh -c`:

```toml
[hooks]
after-new-window  = "notify-send 'tuios' \"new window $TUIOS_WINDOW_NAME\""
after-agent-state = ["sh ~/.config/tuios/hooks/phone.sh", "tuios refresh-dock agents"]
```

### Events

| Event | Fires when | Runs in | Fires with nobody attached |
|---|---|---|---|
| `after-new-window` | A window is created | daemon | yes |
| `after-close-window` | A window is closed | daemon | yes |
| `after-focus-change` | The focused window changes | daemon | yes |
| `after-workspace-switch` | The current workspace changes | daemon | yes |
| `after-agent-state` | A pane's agent state changes, for the transitions `[notifications.agent]` alerts on | daemon | yes |
| `after-command-finished` | A pane's shell reports a finished command through OSC 133 marks | daemon | yes |
| `after-attach` | This client attaches | client | no |
| `after-detach` | This client detaches | client | no |
| `after-resize` | This client's terminal is resized | client | no |
| `after-layout-change` | The layout the client computes changes | client | no |

A daemon hook fires once however many clients are attached; a client hook
fires once per client (three clients attaching is three attaches). A tuios
with no daemon runs every hook itself, except `after-command-finished`, which
only the daemon can follow.

`after-agent-state` follows the alert policy: only the states in
`[notifications.agent.states]` (`needs_input`, `errored` and `done` by
default), after `settle_seconds`, outside `quiet_hours`, and not for the pane an
attached client is showing while `suppress_focused` is on. When every attached
client's terminal has reported losing focus, nobody counts as looking, and the
hook fires for the shown pane too (`tuios session-info` shows this as
`host focus`).

### Environment

Every hook gets every variable. One that does not describe the event is empty,
or `0` for a number:

| Variable | Holds | Set for |
|---|---|---|
| `TUIOS_EVENT` | The event name | all |
| `TUIOS_SESSION_ID` | The session's name | all |
| `TUIOS_WINDOW_ID` | The window's id | window and agent events |
| `TUIOS_WINDOW_NAME` | The window's name | window and agent events |
| `TUIOS_WORKSPACE` | The workspace number | all that have one |
| `TUIOS_PREV_WORKSPACE` | The workspace before the switch | `after-workspace-switch` |
| `TUIOS_LAYOUT` | The layout after the change | `after-layout-change` |
| `TUIOS_WIDTH`, `TUIOS_HEIGHT` | The size after the change | `after-resize` |
| `TUIOS_AGENT_STATE`, `TUIOS_AGENT_PREV_STATE` | The state moved to and from | `after-agent-state` |
| `TUIOS_AGENT_HARNESS` | The harness, such as `claude-code` | `after-agent-state` |
| `TUIOS_AGENT_MESSAGE` | The message that came with the state | `after-agent-state` |
| `TUIOS_COMMAND` | The command line, cut to 512 bytes, likely secrets masked | `after-command-finished` |
| `TUIOS_EXIT_CODE` | The exit status; empty when the shell sent none | `after-command-finished` |
| `TUIOS_DURATION_MS` | How long it ran, in milliseconds | `after-command-finished` |

::: warning
A daemon hook runs with the daemon's environment, not your current shell's.
A daemon started by `tuios new` keeps the environment of that first shell.
Use full paths to programs when in doubt. `TUIOS_AGENT_MESSAGE` is the agent's
own text: think before a hook sends it off the machine.
:::

### When hooks are read

The daemon reads `[hooks]` when it starts and does not reload it. After you
change a daemon hook, restart the daemon:

```sh
tuios kill-server     # ends every session; saved sessions are restored on the next start
tuios
```

Client hooks are read when the client starts, so detach and attach again.

### Five example hooks

::: example
**Example: a phone alert when an agent needs you**

The daemon runs `after-agent-state` with nobody attached, so this reaches you
away from the desk. It sends the pane's name and state, not its message.

```sh
#!/bin/sh
# ~/.config/tuios/hooks/phone.sh
curl -s -m 5 -H "Title: tuios: $TUIOS_AGENT_STATE" \
  -d "$TUIOS_SESSION_ID/$TUIOS_WINDOW_NAME is $TUIOS_AGENT_STATE" \
  https://ntfy.sh/your-private-topic > /dev/null
```

```toml
[hooks]
after-agent-state = ["sh ~/.config/tuios/hooks/phone.sh"]

[notifications.agent]
suppress_focused = true
quiet_hours = "23:00-07:00"
```
:::

::: example
**Example: tell me when a long command fails**

`after-command-finished` needs shell integration that sends OSC 133 marks
(`tuios doctor shell` says which panes have it). This notifies only for
commands that ran over a minute and exited non-zero.

```sh
#!/bin/sh
# ~/.config/tuios/hooks/long-fail.sh
[ -n "$TUIOS_EXIT_CODE" ] || exit 0
[ "$TUIOS_EXIT_CODE" -ne 0 ] || exit 0
[ "${TUIOS_DURATION_MS:-0}" -ge 60000 ] || exit 0
secs=$((TUIOS_DURATION_MS / 1000))
msg="exit $TUIOS_EXIT_CODE after ${secs}s: $TUIOS_COMMAND"
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$msg\" with title \"tuios $TUIOS_WINDOW_NAME\""
else
  notify-send "tuios $TUIOS_WINDOW_NAME" "$msg"
fi
```

```toml
[hooks]
after-command-finished = "sh ~/.config/tuios/hooks/long-fail.sh"
```
:::

::: example
**Example: keep a dock cell current without polling**

A custom component with `refresh = "once"` runs only when asked, and a hook
asks at exactly the right moment.

```toml
[dock]
right = ["notifications", "copy-help", "custom/agents", "clock", "session-controls"]

[dock.custom.agents]
command = "~/.config/tuios/dock/agents.sh"
refresh = "once"

[hooks]
after-agent-state = "tuios refresh-dock agents"
after-close-window = "tuios refresh-dock agents"
```
:::

::: example
**Example: a time log of workspace switches**

Each line records when you moved between workspaces, for a later report.

```toml
[hooks]
after-workspace-switch = '''printf '%s\t%s\t%s\t%s\n' "$(date +%FT%T)" "$TUIOS_SESSION_ID" "$TUIOS_PREV_WORKSPACE" "$TUIOS_WORKSPACE" >> ~/.local/state/tuios-workspaces.tsv'''
```

```sh
# how many times each workspace was switched to
awk -F'\t' '{print $4}' ~/.local/state/tuios-workspaces.tsv | sort | uniq -c
```
:::

::: example
**Example: a status file for a desktop bar**

Client hooks run in the client, so they act on the machine you sit at. This
keeps a file a desktop bar (waybar, SketchyBar) can read. Only `after-resize`
carries the size; the other two leave `TUIOS_WIDTH` and `TUIOS_HEIGHT` at 0.

```toml
[hooks]
after-attach = "echo \"attached $TUIOS_SESSION_ID\" > ~/.cache/tuios-status"
after-detach = "echo detached > ~/.cache/tuios-status"
after-resize = "echo \"attached $TUIOS_SESSION_ID ${TUIOS_WIDTH}x${TUIOS_HEIGHT}\" > ~/.cache/tuios-status"
```
:::

### When a hook does not fire

```sh
tuios list-hooks
tuios list-hooks --event after-agent-state
tuios list-hooks --json | jq '.hooks[] | select(.last_error != "")'
```

`list-hooks` lists every registered command with its side, how many times it
ran, its last exit code, when it last ran and its last error. Client hooks are
listed only while a client is attached.

| What you see | What it means |
|---|---|
| No row | The hook was never loaded: check the event name, and restart the daemon for a daemon hook |
| `RUNS` is 0 | The command is registered and the event never happened |
| Non-zero exit | The command ran and failed; the error says why |

The daemon also logs a warning for every failing hook, with the exit code and
the last 1 KiB of stderr. `tuios daemon --log-level=basic` adds one line per
firing.

## A complete annotated config.toml

This file is a sane starting point for daily work with coding agents. Every
major table is present, every value is valid for v0.8.5 (it loads with no
errors and no warnings), and the comments say why each value differs from the
default. The scripts it names are the hook examples above and the upstream
`git-branch.sh` dock recipe.

```toml
# ~/.config/tuios/config.toml
# A complete, working configuration for daily use with coding agents.
# Note: the settings page and `tuios set-config` rewrite this file and drop
# comments. Keep this annotated copy in your dotfiles.

# Appearance: colour, shape, spacing
[appearance]
theme = "catppuccin_mocha"        # any id from `tuios list-themes`; "" for terminal colours
glyphs = "default"                # default, unicode, heavy, ascii, or a file in glyphs/
border_style = "rounded"          # "glyphs" draws the glyph set's border
background = "off"                # let the terminal's own background show through
dock_background = "theme"         # but give the dock the theme's ground
session_colors = true             # one colour per session on the rail and switcher
session_border = true             # and on every pane border
gap = 1                           # one cell between tiled panes
panel_padding = 2
dim_unfocused = 10                # fade panes you are not in by 10%
modal_dim = 15                    # darken the screen behind overlays a little
motion = "full"                   # none, basic, full

# Titles and window controls
window_title_position = "top"
window_title_format = "{index}: {title}"
window_button_style = "dots"
window_button_position = "left"

# Dock
dockbar_position = "top"
dock_workspace_tab_format = "{index} {name}"
show_clock = true
clock_format = "15:04"
show_cpu = true
show_ram = true

# Mouse and focus
click_to_type = "single"          # one click on a pane starts typing in it
focus_follows_mouse = false
copy_on_select = true
confirm_quit = true

# Terminal
preferred_shell = "/bin/zsh"
scrollback_lines = 50000
new_window_inherit_cwd = true

[appearance.scrollbar]
style = "thin"
tint = "quiet"

[appearance.selection]
copy_entry = "center"             # copy mode starts on the middle row
osc52_write = "focused"           # only the focused pane may set the clipboard silently
flash = true

[appearance.sidebar]
enabled = true
position = "left"
width = 28
sections = "sessions:25,terminals,files:25,agents:34"
editor = "nvim"                   # Shift+Enter on a text file opens it here
file_delete = "trash"
agent_rest_fold = "1h"

[appearance.sidebar.agent_row]
tokens = ["session", "need", "harness", "name", "elapsed", "$model", "context", "subagents", "now", "message"]

[[appearance.sidebar.agent_row.elapsed.rule]]
gt = 30                           # an agent in one state for 30+ minutes
fg = "warning"

# Dock components (lists are not settable from the CLI)
[dock]
left   = ["mode", "workspaces", "trail", "tape", "custom/branch"]
center = ["windows"]
right  = ["notifications", "copy-help", "cpu", "ram", "clock", "session-controls"]

[dock.clock]
format = "Mon 15:04"

[dock.custom.branch]
command  = "~/.config/tuios/dock/git-branch.sh"
refresh  = "event:after-focus-change"
on-click = "tuios new-window log -- git log --oneline -20"
max-width = 24

# Notifications
[notifications]
duration = 0                      # 0: built-in default
error_sticky = true

[notifications.agent]
enabled = true
notify = true
dock = true
sound = true
sound_mode = "audio"              # use "bell" when you mostly attach over ssh
sound_cooldown_seconds = 3
settle_seconds = 2
suppress_focused = true
quiet_hours = "23:00-07:00"

[notifications.agent.states]
needs_input = true
errored = true
done = true
idle = false
working = false

[notifications.agent.sounds]
needs_input = "~/.config/tuios/sounds/attention.wav"
done = ""                         # empty: the built-in cue

[notifications.mail]
sound = false                     # mail never makes a noise
between_agents = false

# Daemon and startup
[daemon]
log_level = "off"
agent_autodetect = true
agent_binaries = []
resume_agents = "ask"
persist_scrollback = true
persist_scrollback_lines = 1000
window_size = "latest"            # the client that typed last sets the size

[startup]
daemon = true                     # write both: missing means false
tiled = true
layout = "bsp"
open_default_window = true
start_in_terminal_mode = false

[tape]
autorun = "ask"
auto_review = false

# Hooks (daemon hooks need `tuios kill-server` to reload)
[hooks]
after-agent-state = ["sh ~/.config/tuios/hooks/phone.sh"]
after-command-finished = "sh ~/.config/tuios/hooks/long-fail.sh"

# Tools
[screenshot]
format = "png"
directory = "~/Pictures/tuios"
frame = "window"
scale = 2

[hints]
builtins = "all"
patterns = ['\b[A-Z]{2,}-\d+\b']  # ticket ids such as ABC-123
all_panes = false

[scratch]
width = "80%"
height = "80%"

[pip]
width = 40
height = 12
corner = "bottom-right"

[spotlight]
enabled = false

[screensaver]
enabled = false
idle_minutes = 10
effect = "random"

[debug]
show_key_events = false

# Other machines
[hosts.build]
addr = "build"                    # an ssh_config alias
allow = ["list", "mail"]

[hosts."*"]
allow = ["list", "mail"]

# Agents: approvals, permissions, queue
[agents]
herdr_protocol = "always"

[agents.approvals]
enabled = ["claude-code"]
hold_seconds = 120

[agents.permissions]
mode = "strict"                   # panes may read, type in their own session, and fan out
grants = ["read", "write", "fan"]

[agents.queue]
max = 8

# Keys (full reference in the Keybindings chapter)
[keybindings]
leader_key = "ctrl+a"

[keybindings.prefix_mode]
copy_mode_search_backward = ["/"]
```

What this file does, table by table:

| Table | Choice | Why |
|---|---|---|
| `[appearance]` | A theme, `gap = 1`, light dimming | Clear focus without heavy chrome |
| `[appearance.sidebar]` | Rail on the left, `nvim` as the file editor | Matches a left-to-right reading order |
| `[appearance.sidebar.agent_row]` | Adds `$model`, warns after 30 minutes | Shows which model each agent runs and which is stuck |
| `[dock]` | Adds a git branch cell | Event-driven, so it costs nothing at idle |
| `[notifications.agent]` | Sound on, quiet hours at night | Hear an agent that needs you, but not at 3 a.m. |
| `[notifications.mail]` | No sound for mail | Mail can wait for the next look at the dock |
| `[daemon]` | `window_size = "latest"` | A laptop and a desktop attached to one session each get full use of their screen |
| `[startup]` | Both `daemon` and `tiled` written | A file that leaves them out reads them as false |
| `[hooks]` | Phone alert, long-failure notice | Reach you away from the desk; catch a failed build |
| `[hosts]` | Other machines may only list and mail | Nothing can type here unless you say so |
| `[agents.permissions]` | `strict` with `read`, `write`, `fan` | A pane cannot answer prompts for you or change other sessions |
| `[keybindings]` | `ctrl+a` leader | A common choice for former screen users; see [Keybindings](keybindings.md) |

After you install it:

```sh
tuios config path                     # confirm where it belongs
cp config.toml "$(tuios config path)"
tuios kill-server && tuios            # hooks and [startup] need a fresh daemon
tuios list-hooks                      # both hooks registered
tuios list-dock-components            # custom/branch drawn
tuios keybinds doctor                 # no key problems
```

## Glossary

Chrome
: Everything tuios draws itself: borders, title bars, the dock, the rail and
  overlay panels. A theme colours it and a glyph set shapes it.

Cue
: One of the two alert sounds, attention or done. A cue file replaces one.

Daemon hook
: A hook the daemon runs. It fires with nobody attached and needs a daemon
  restart to reload.

Dock
: The bar at the top or bottom of the screen, made of components in three
  regions.

Glyph set
: A named set of characters for the chrome's roles, built in or a JSON file in
  `glyphs/`.

Option registry
: The list of every scalar config path, with type, default and accepted values,
  shared by `list-options`, `get-config`, `set-config` and the settings page.

Quiet hours
: A daily local-time window during which agent and mail alerts are silent.

Rail
: The sidebar of sessions, terminals, files and agents, configured in
  `[appearance.sidebar]`.

Role
: One place a glyph set can fill, such as `close`, `focus` or
  `border.top_left`.

Surface
: A region a background option can paint: panes, desktop, window chrome, dock,
  rail. Also the base grey of the dialog ramp in a theme's `chrome`.

Theme
: Sixteen ANSI colours plus foreground, background and cursor, and optional
  chrome colours, built in or a JSON file in `themes/`.
