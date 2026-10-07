---
title: "TUIOS: Core Concepts and the Screen"
template: tuios-manual
manual: tuios
chapter: 2
summary: The tuios mental model of daemon, sessions, workspaces and windows, its input modes, its tiling layouts, and every part of the screen from the dock and the rail to overlays, copy mode, images and the mouse.
tags:
  - tuios
  - concepts
  - tiling
  - interface
  - mouse
---

This chapter explains how tuios is put together and what everything on its
screen means. It starts with the object model (the daemon, sessions,
workspaces, windows and panes), moves on to the input modes and the tiling
layouts, and then walks the screen from the outside in: the dock, the rail,
title bars and borders, the overlays, copy mode, images and the mouse. Read it
once from top to bottom to build the mental model, then come back to a section
when you need its details.

::: note
Every key in this chapter is the **shipped default** of tuios v0.8.5, read from
the defaults in `internal/config/userconfig.go`. The leader key is
<kbd>Ctrl</kbd>+<kbd>b</kbd> and the command palette is
<kbd>Ctrl</kbd>+<kbd>p</kbd>. If your `config.toml` changes them (for example
`leader_key = "ctrl+a"`), `tuios keybinds list` shows your own bindings, and
`tuios keybinds explain <key>` tells you what one key does. The full key
reference is [Keybindings](keybindings.md); the options mentioned here are in
[Configuration](configuration.md).
:::

On macOS the defaults that use <kbd>Alt</kbd> are written with
<kbd>Opt</kbd> (`opt+1`, `opt+h`). tuios reads `opt+` as `alt+`, so the two
spellings are the same key. See [Keybindings](keybindings.md) for the
Option-as-Alt setup that macOS terminals need.

## Quick reference

| Concept | What it is | Default key or command |
|---|---|---|
| Daemon | The background process that owns every shell | `tuios daemon`, started on demand by `tuios` |
| Session | A named set of workspaces and windows inside the daemon | `tuios new NAME`, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>S</kbd> |
| Workspace | One of nine numbered screens in a session | <kbd>Alt</kbd>+<kbd>1</kbd> to <kbd>Alt</kbd>+<kbd>9</kbd> |
| Window | A terminal with one pane, a title bar and a border | <kbd>n</kbd> (window mode), <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>c</kbd> |
| Window management mode | Keys drive tuios, not the shell | <kbd>Esc</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Esc</kbd>, <kbd>Alt</kbd>+<kbd>Esc</kbd> |
| Terminal mode | Keys go to the program in the focused pane | <kbd>i</kbd> or <kbd>Enter</kbd> |
| Prefix mode | One chord after the leader key | <kbd>Ctrl</kbd>+<kbd>b</kbd> |
| Copy mode | Vim-style movement over the scrollback | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>[</kbd> |
| Tiling | Automatic layout of the windows on a workspace | <kbd>t</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Space</kbd> |
| Command palette | Fuzzy search over every action, session and pane | <kbd>Ctrl</kbd>+<kbd>p</kbd> |
| Launcher | Fuzzy search over the programs you can start | <kbd>Alt</kbd>+<kbd>Space</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>a</kbd> |
| Dock | The one-row bar at the top of the screen | `appearance.dockbar_position` |
| Rail | The sidebar of sessions, terminals, files and agents | <kbd>s</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>e</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>b</kbd> |
| Settings | The in-app option editor | <kbd>,</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>,</kbd> |
| Help | The key reference overlay | <kbd>?</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>?</kbd> |

## The object model

tuios is a terminal window manager. It draws windows inside your existing
terminal, the way a desktop window manager draws windows on a monitor, and it
keeps them alive in a background process the way tmux does. Five nouns describe
everything it manages.

```text
daemon (one per user, per XDG_RUNTIME_DIR)
└── session "work"                    (named; many per daemon)
    ├── workspace 1                   (numbered 1-9)
    │   ├── window 3a42ab8f "editor"  (one pane each)
    │   └── window 98db8226 "build"
    ├── workspace 2
    │   └── window 5c0e1d77 "logs"
    └── scratch workspace 1000+       (the scratch terminal, see below)
```

The same structure as data, roughly what `tuios list-windows --json` and
`tuios list-workspaces --json` describe:

```js
session = {
  name: "work",
  current_workspace: 1,
  workspaces: [
    { number: 1, name: "1", windows: ["3a42ab8f", "98db8226"] },
    { number: 2, name: "logs", windows: ["5c0e1d77"] },
  ],
  windows: {
    "3a42ab8f": { name: "editor", title: "nvim main.go", workspace: 1, focused: true },
    "98db8226": { name: "",       title: "~/dev/api - fish", workspace: 1 },
    "5c0e1d77": { name: "logs",   title: "tail -f app.log", workspace: 2, minimized: true },
  },
}
```

### The daemon

The daemon is a `tuios` process running in the background. It owns every shell
process (every PTY) and runs a terminal emulator for each one, so output keeps
being parsed while nobody is looking. A client, the `tuios` you see in your
terminal, is only a viewer: it subscribes to the PTY output, draws it, and
forwards your keys back.

Running plain `tuios` attaches to a daemon-backed session and starts the
daemon first if none is running. This is the `startup.daemon` option, and it
ships on.

```sh
tuios                     # attach to a daemon session, starting the daemon if needed
tuios daemon              # run the daemon in the foreground, for debugging
tuios kill-server         # stop the daemon and every session in it
tuios --standalone        # no daemon for this one run: the session dies with the process
```

Because the daemon holds the shells, closing your terminal window, losing an
ssh connection or pressing <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>d</kbd> (detach)
leaves every program running. More than one client can attach to the same
session at once, and every attached client has full control. Detach,
reattach, multiple clients and resurrection after a reboot are covered in
[Sessions](sessions.md).

::: tip
Inside a daemon pane `TUIOS_ENV=1` is set, along with `TUIOS_SESSION`,
`TUIOS_PANE_ID` and `TUIOS_SOCKET`. A script can test `[ "$TUIOS_ENV" = 1 ]`
to know it runs in tuios. A `--standalone` tuios has no daemon and no socket.
:::

### Sessions

A session is a named, independent desktop inside the daemon: its own nine
workspaces, its own windows, its own layout state. You can have many sessions
and switch between them without detaching.

```sh
tuios new work            # make the session "work" and attach to it
tuios new scratch --detach
tuios ls                  # list the live sessions
tuios attach work         # attach to "work"
tuios attach              # attach to the most recent session
```

In the client, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>S</kbd> opens the session
switcher, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>(</kbd> and
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>)</kbd> move to the previous and next
session, and <kbd>N</kbd> in window mode makes a new session. The rail lists
every session at its top.

#### The most recently active session

Nearly every `tuios` subcommand takes `-s NAME` to pick its session. When you
leave `-s` out, the command goes to the **most recently active session**. With
one session that is always right. With several live sessions it is a guess,
so scripts and agents running inside a pane should name their own session:

```sh
tuios list-windows                         # the most recently active session
tuios list-windows -s work                 # exactly "work"
tuios list-windows -s "$TUIOS_SESSION"     # the session this pane belongs to
```

::: default
`-s` omitted means "the most recently active session". `tuios attach` with no
name attaches to the most recent session.
:::

A session has a **name**, which is its address (`-s`, `tuios attach`), and may
have a **display label** and an **accent colour**, which only change how it
looks:

```sh
tuios rename-session work payments        # changes the address
tuios set-session-name "Payments API"     # changes only the label
tuios set-session-accent cyan
```

### Workspaces

Each session has nine numbered workspaces, 1 to 9. A workspace is one screen
of windows, like a virtual desktop. Exactly one workspace is shown at a time;
the windows on the others keep running. Each workspace keeps its own layout
data (its BSP tree, its column strip, its master side and count) and its own
remembered focus.

| Keys | Action |
|---|---|
| <kbd>Alt</kbd>+<kbd>1</kbd> to <kbd>Alt</kbd>+<kbd>9</kbd> | Show workspace N (`switch_workspace_N`) |
| <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>1</kbd> to <kbd>9</kbd> | Move the focused window to workspace N and follow it (`move_and_follow_N`) |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> then <kbd>1</kbd> to <kbd>9</kbd> | Show workspace N (workspace prefix) |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> then <kbd>!</kbd> <kbd>@</kbd> <kbd>#</kbd> ... <kbd>(</kbd> | Move the focused window to workspace 1 to 9 |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>r</kbd> | Rename the current workspace |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>W</kbd> | Open the workspace switcher |

On macOS the first two rows are <kbd>Opt</kbd>+<kbd>1</kbd> and
<kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>1</kbd>. They work on a stock macOS
terminal because tuios reads the composed characters back into the chord.

A workspace's **number** is its identity. Its **name** is a label you give it,
and the dock shows the name. You can also drag the workspace pills in the dock
into a different order; that changes only the display order, never the numbers
the keys and commands use.

```sh
tuios list-workspaces -s work
tuios select-workspace 2 -s work
tuios set-workspace-name 2 review
tuios move-window -s work 2 -w build --follow
```

::: note
The scratch terminal lives on workspaces numbered from 1000 up. They are not
part of the 1-9 range, the session's current workspace is never one of them,
and `list-windows` marks their panes `"scratch": true`.
:::

### Windows and panes

A **window** is one terminal: a PTY running a program (your shell by default),
drawn with a border and a title bar. Every window owns exactly one **pane**,
the area that shows the terminal's content. tuios uses the two words almost
interchangeably: "window" when talking about the object with a title, a
position and an id, "pane" when talking about the terminal content or about a
tile in a layout. There is no tmux-style window that holds several panes; a
split in tuios makes a second window.

| Keys (window mode) | Prefix chord | Action |
|---|---|---|
| <kbd>n</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>c</kbd> | New window |
| <kbd>w</kbd> or <kbd>x</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>x</kbd> | Close the focused window |
| <kbd>r</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>r</kbd> | Rename the focused window |
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>n</kbd> / <kbd>p</kbd> | Next / previous window |
| <kbd>1</kbd> to <kbd>9</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>0</kbd> to <kbd>9</kbd> | Focus window N on the workspace |

A new window starts in the focused pane's working directory
(`appearance.new_window_inherit_cwd`, default `true`). From a shell:

```sh
tuios new-window -s work docs --cwd ~/dev/docs --no-focus
# prints the short id and the name, for example:
# 3a42ab8f  docs
```

### Focus

One window per workspace has the **focus**. It is drawn with the focused
border colour, it receives your keys in terminal mode, and every
window-management action (close, rename, split, zoom, swap) acts on it. Focus
moves with:

| Direction | Window mode | Terminal mode | After the prefix |
|---|---|---|---|
| Left | <kbd>h</kbd> | <kbd>Alt</kbd>+<kbd>Left</kbd> | <kbd>Left</kbd> |
| Down | <kbd>j</kbd> | <kbd>Alt</kbd>+<kbd>Down</kbd> | <kbd>Down</kbd> |
| Up | <kbd>k</kbd> | <kbd>Alt</kbd>+<kbd>Up</kbd> | <kbd>Up</kbd> |
| Right | <kbd>l</kbd> | <kbd>Alt</kbd>+<kbd>Right</kbd> | <kbd>Right</kbd> |

Directional focus goes to the nearest window that lies in that direction and
faces the focused one. At the edge of a tiled layout it stays where it is.
With tiling off, <kbd>h</kbd> and <kbd>l</kbd> snap the window to the left or
right half instead (`snap_left`, `snap_right`); <kbd>j</kbd> and <kbd>k</kbd>
always move focus. In terminal mode <kbd>Alt</kbd>+<kbd>n</kbd> and
<kbd>Alt</kbd>+<kbd>p</kbd> cycle to the next and previous window (on macOS
also <kbd>Opt</kbd>+<kbd>Tab</kbd> and <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>Tab</kbd>).

The prefix stays armed for half a second after a repeatable command, so
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Left</kbd> <kbd>Left</kbd> <kbd>Left</kbd>
walks three panes on one prefix press (`appearance.prefix_repeat_time`, `0`
turns it off).

```sh
tuios focus-window -s work build              # by name, on any workspace
tuios focus-window -s work --relative next
tuios focus-window -s work --direction left
```

::: tip
`appearance.focus_follows_mouse = true` focuses the pane under the pointer as
the mouse moves. `appearance.auto_enter_terminal_on_focus` (`off`,
`targeted`, `all`) decides whether a keyboard focus change also starts typing
in the pane.
:::

### Floating and tiled windows

A window is either **tiled** or **floating**.

- A **tiled** window has its rectangle chosen by the layout (BSP,
  master-stack or scrolling). You never place it by hand; you split, swap,
  rotate and resize the layout.
- A **floating** window has a position and size of its own. You drag it,
  resize it by its edges and stack it over other windows, like a window on a
  desktop. Floating windows draw above the tiles.

Tiling is a per-session switch: with tiling **on**, new windows join the
layout; with tiling **off**, every window floats. New sessions start tiled
(`startup.tiled = true`).

| Keys | Action |
|---|---|
| <kbd>t</kbd> (window mode), <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Space</kbd> | Toggle tiling for the session |
| Palette: "Toggle floating" | Lift only the focused window out of the layout, or put it back |

"Toggle floating" leaves the rest of the layout tiled and shows the dock
message `Window: floating` or `Window: tiled`. A popup and a scratch pane are
always floating and cannot be tiled.

With tiling off, the snap keys place a floating window:

| Keys | Action |
|---|---|
| <kbd>h</kbd> / <kbd>l</kbd> | Snap to the left / right half |
| <kbd>f</kbd> | Snap to the full screen |
| <kbd>u</kbd> | Unsnap the window from its snapped position |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>1</kbd> to <kbd>4</kbd> | Snap to a corner quarter |

With tiling on, <kbd>f</kbd>, <kbd>u</kbd> and the corner snaps do nothing
except say that they need tiling off, because the tiler owns the rectangles.

### Minimize, zoom and fullscreen

**Minimizing** hides a window without closing it. Its program keeps running
and it shows up as an entry in the middle of the dock.

| Keys | Action |
|---|---|
| <kbd>m</kbd> (window mode) | Minimize the focused window |
| <kbd>M</kbd> | Restore every minimized window |
| <kbd>Shift</kbd>+<kbd>1</kbd> to <kbd>Shift</kbd>+<kbd>9</kbd> (also <kbd>!</kbd> ... <kbd>(</kbd>) | Restore minimized window N |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>m</kbd> | Minimize the focused window (minimize prefix) |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>1</kbd> to <kbd>9</kbd> | Restore minimized window N |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>M</kbd> | Restore all |
| Click a dock entry | Restore that window |

```sh
tuios set-window -s work -w build --minimize
tuios set-window -s work -w build --restore
```

**Zooming** is tuios's maximize. A zoomed pane takes 95% of the screen by
default, centred over the layout, and the dock's mode pill gains a ` Z`. The
layout underneath is untouched, and zoom again puts the pane back in its tile.

| Keys | Action |
|---|---|
| <kbd>z</kbd> (window mode) | Toggle zoom on the focused pane |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>z</kbd> | Toggle zoom (`prefix_fullscreen`; the dock says `ZOOM`) |
| The third title-bar button | Toggle zoom |

```toml
[appearance]
zoom_size = 100            # percent of the screen; 100 is true fullscreen (default 95)
zoom_max_width = 120       # cap the zoom box at 120 columns, centred (0 = no cap)
zoom_follows_focus = true  # moving focus hands the zoom to the newly focused pane
zoom_animation = true      # slide between the tile and the zoom box
```

A zoomed pane cannot be dragged or resized. A fullscreen zoom hides the shared
borders.

::: note
"Fullscreen" has two meanings. <kbd>f</kbd> with tiling off is a **snap**: it
moves a floating window to fill the screen. <kbd>z</kbd> or
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>z</kbd> is a **zoom**, which works in every
layout and leaves the layout alone.
:::

### Window names and program titles

A window has two labels:

- Its **name**, which you give it with <kbd>r</kbd>,
  <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>r</kbd>, `tuios new-window NAME`,
  `tuios set-window --name` or `tuios split-window --name`.
- Its **title**, which the program inside sets with the terminal title escape
  (a shell typically sets `~/dev/api - fish`, an editor its file name).

The name wins. The title bar, the dock, the rail, the palette and
`list-windows` show the name when there is one and the program's title
otherwise. Clearing the name brings the title back:

```sh
tuios set-window -s work -w build --name "api tests"
tuios set-window -s work -w build --name ""     # back to the program's title
```

The name is also an address: `-w build` finds the window you named `build`,
whatever its program calls itself. `appearance.window_title_format` decides
what the title bar prints, with the tokens `{title}` (the name or the
program's title), `{index}` (the window's 1-based position on its workspace,
the number the digit keys use) and `{cwd}`:

```toml
[appearance]
window_title_format = "{index}: {title}"
window_title_position = "top"   # top, bottom or hidden (default top)
```

### Window ids, indexes and prefixes

Every window has a UUID, such as `98db8226-1829-468e-89a8-41a2baa0ddab`. Inside
a pane it is `TUIOS_PANE_ID` (and the same value in `TUIOS_WINDOW_ID`).
Listings and command output show the first eight characters, `98db8226`.

`-w` accepts, in this order of precedence:

| Form | Example | Notes |
|---|---|---|
| Full UUID | `-w 98db8226-1829-468e-89a8-41a2baa0ddab` | Always exact |
| Index | `-w 2` | All digits: the index `list-windows` prints. It shifts when an earlier window closes |
| Exact name | `-w build` | A name you gave, not a program title |
| Unique id prefix | `-w 98db` | Any unambiguous prefix of the UUID |

A name beats a prefix, so a window named `db` is never mistaken for a window
whose id starts with `db`. An ambiguous name or prefix is an error that lists
the candidates; tuios never guesses. Scripts should hold the id or the name,
never the index.

```sh
id=$(tuios new-window -s work worker --print-id)
tuios send-text -s work -w "$id" 'make test
'
```

### Popups, the scratch terminal and picture in picture

Three window kinds sit outside the normal layout.

- A **popup** is a floating pane centred over the layout that closes when its
  command exits: `tuios popup -- fzf`. It is never tiled, never in the window
  cycle and cannot join multifocus. See [Overlays](#popups).
- The **scratch terminal** (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>g</kbd>) is a
  small layout of panes in a box over the current workspace. The key shows and
  hides the box; the shells keep running. Inside the box the window keys act
  on its panes. `[scratch]` sets the box size. See
  [Sessions](sessions.md#the-scratch-terminal-and-picture-in-picture).
- **Picture in picture** (<kbd>p</kbd> in window mode) pins the focused pane as
  a small live copy in a corner of the screen. <kbd>p</kbd> again, on any pane,
  unpins it, and a click on the view focuses that pane. It belongs to your
  client only. `[pip]` sets the size and corner.

```sh
tuios popup -s work --width 60 --height 20 -- gum choose one two three
tuios pip -s work agent     # pin the pane named agent
tuios pip -s work --off
```

## Modes

tuios is modal, like vim. The same key means one thing when you are managing
windows and another when you are typing into a shell. Knowing which mode you
are in, and how to leave it, is the single most important habit.

### Window management mode

In **window management mode** (window mode for short, WM in some docs) the
keyboard drives tuios. <kbd>n</kbd> makes a window, <kbd>h</kbd> moves focus
left, <kbd>z</kbd> zooms, and nothing reaches the shells. A fresh session
starts here unless `startup.start_in_terminal_mode = true`.

### Terminal mode

In **terminal mode** every key goes to the program in the focused pane,
except the few that tuios keeps for itself:

| Keys | Why tuios keeps them |
|---|---|
| The leader, <kbd>Ctrl</kbd>+<kbd>b</kbd> | Starts a prefix chord |
| <kbd>Ctrl</kbd>+<kbd>p</kbd>, <kbd>Alt</kbd>+<kbd>Space</kbd> | `[keybindings.global]`: the palette and the launcher, in both modes |
| <kbd>Alt</kbd>+arrows | Move focus between panes |
| <kbd>Alt</kbd>+<kbd>n</kbd>, <kbd>Alt</kbd>+<kbd>p</kbd> | Next and previous window |
| <kbd>Alt</kbd>+<kbd>Esc</kbd> | Leave terminal mode |
| <kbd>Shift</kbd>+<kbd>Up</kbd>, <kbd>Shift</kbd>+<kbd>Down</kbd> | Scroll the pane's scrollback |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>v</kbd>, <kbd>Super</kbd>+<kbd>v</kbd> | Paste from the host clipboard |
| <kbd>Alt</kbd>+<kbd>1</kbd> ... <kbd>Alt</kbd>+<kbd>9</kbd> | Switch workspace |

A bare <kbd>Esc</kbd> in terminal mode goes to the program, as vim needs. To
send the leader itself to the program, press it twice:
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Ctrl</kbd>+<kbd>b</kbd>.

::: warning
The global and terminal-mode bindings take keys away from your shell:
<kbd>Ctrl</kbd>+<kbd>p</kbd> is history-back in many shells and
<kbd>Alt</kbd>+<kbd>Left</kbd>/<kbd>Right</kbd> are word motions in readline,
fish and zsh. To give a key back, set its action to `[]` or run
`tuios keybinds free <key>`:

```toml
[keybindings.global]
command_palette = ["ctrl+shift+p"]

[keybindings.terminal_mode]
terminal_focus_left = []
terminal_focus_right = []
```
:::

### Switching between them

| From | To | Keys |
|---|---|---|
| Window mode | Terminal mode | <kbd>i</kbd> or <kbd>Enter</kbd> |
| Window mode | Terminal mode | Double-click a pane's content (`appearance.click_to_type = "double"`, the default; `single` or `off`) |
| Terminal mode | Window mode | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Esc</kbd> |
| Terminal mode | Window mode | <kbd>Alt</kbd>+<kbd>Esc</kbd> (on macOS <kbd>Opt</kbd>+<kbd>Esc</kbd>) |
| Window mode | Terminal mode, temporarily reversed | `hold_window_mode`: window mode for as long as a key is held (no default key) |
| Any | Window mode | Palette: "Window management mode" |

```sh
tuios run-command -s work TerminalMode
tuios run-command -s work WindowManagementMode
```

::: note
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>d</kbd> **detaches** in a daemon session. Only
in a standalone session, where there is nothing to detach from, does it drop
you back to window mode. Use <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Esc</kbd> to
change mode.
:::

### Prefix mode and the leader key

The **leader key** (<kbd>Ctrl</kbd>+<kbd>b</kbd>, `keybindings.leader_key`)
arms **prefix mode** for one following key, the way tmux's prefix does. It
works from both modes, which is why every important action has a prefix
chord: you can reach it while typing in a shell without leaving terminal mode.

While the prefix is armed a badge reading `PREFIX | <time>` lights up, and if
you wait 500 ms the which-key panel opens with every key you can press next
(see [Which-key](#which-key)). In terminal mode, a key that is not bound after
the prefix is typed into the focused pane.

The common prefix chords:

| Chord | Action |
|---|---|
| <kbd>c</kbd> | New window |
| <kbd>x</kbd> / <kbd>X</kbd> | Close the window / close the session and its panes |
| <kbd>r</kbd> | Rename the window |
| <kbd>n</kbd> <kbd>p</kbd> (or <kbd>Tab</kbd> <kbd>Shift</kbd>+<kbd>Tab</kbd>) | Next / previous window |
| <kbd>0</kbd> to <kbd>9</kbd> | Jump to window N |
| arrows | Focus the pane in that direction |
| <kbd>-</kbd> / <kbd>\|</kbd> or <kbd>\\</kbd> | Split top/bottom / left/right |
| <kbd>R</kbd> / <kbd>=</kbd> | Rotate the split / equalize all splits |
| <kbd>Space</kbd> | Toggle tiling |
| <kbd>z</kbd> | Zoom the window |
| <kbd>[</kbd> | Copy mode (multi copy mode on a multifocus set) |
| <kbd>s</kbd> | Scrollback browser |
| <kbd>F</kbd> | Hints |
| <kbd>V</kbd> | Paste the clipboard image as a file path |
| <kbd>g</kbd> | Show or hide the scratch terminal |
| <kbd>f</kbd> | Search file names below the focused pane's directory |
| <kbd>C</kbd> | Screenshot (capture mode) |
| <kbd>P</kbd> | Command palette |
| <kbd>a</kbd> | Launcher |
| <kbd>,</kbd> | Settings |
| <kbd>k</kbd> | Keybind manager |
| <kbd>?</kbd> | Help |
| <kbd>b</kbd> | Show or hide the rail |
| <kbd>e</kbd> | Focus the rail, or leave it |
| <kbd>j</kbd> | Jump to the pane the newest dock message came from |
| <kbd>S</kbd> / <kbd>W</kbd> | Session switcher / workspace switcher |
| <kbd>(</kbd> / <kbd>)</kbd> | Previous / next session |
| <kbd>d</kbd> | Detach |
| <kbd>q</kbd> | Quit (in a daemon session this kills the session) |
| <kbd>Esc</kbd> | Leave terminal mode |
| <kbd>i</kbd> <kbd>o</kbd> <kbd>O</kbd> <kbd>M</kbd> <kbd>v</kbd> | Inbox, oldest waiting item, newest finished turn, mail, review (see [Agents](agents.md)) |

Seven chords open a **sub-prefix**, a second menu of one-key commands. Each
one closes on <kbd>Esc</kbd>.

| Chord | Sub-prefix | Its keys |
|---|---|---|
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> | Workspace | <kbd>1</kbd>-<kbd>9</kbd> switch, <kbd>!</kbd>-<kbd>(</kbd> move the window there, <kbd>r</kbd> rename |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> | Minimize | <kbd>m</kbd> minimize, <kbd>1</kbd>-<kbd>9</kbd> restore N, <kbd>M</kbd> restore all |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> | Window | <kbd>n</kbd> new, <kbd>x</kbd> close, <kbd>r</kbd> rename, <kbd>Tab</kbd>/<kbd>Shift</kbd>+<kbd>Tab</kbd> cycle, <kbd>t</kbd> tiling |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> | Layout | <kbd>l</kbd> load, <kbd>s</kbd> save, <kbd>1</kbd>-<kbd>4</kbd> corner snap, <kbd>5</kbd>-<kbd>9</kbd> width 50-90%, <kbd>Shift</kbd>+<kbd>5</kbd>-<kbd>9</kbd> height 50-90%, <kbd>o</kbd> <kbd>Enter</kbd> <kbd>m</kbd> <kbd>i</kbd> <kbd>d</kbd> master-stack |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> | Tape | <kbd>m</kbd> manager, <kbd>t</kbd> review the project tape, <kbd>r</kbd> record, <kbd>s</kbd> stop |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> | Debug | <kbd>l</kbd> logs, <kbd>c</kbd> cache stats, <kbd>a</kbd> animations, <kbd>k</kbd> showkeys |

### Who has the keyboard

Besides the two main modes, several states take the keyboard for a while.
Each one says so on screen and each one leaves on <kbd>Esc</kbd> (or
<kbd>q</kbd>).

| State | Entered with | Owns |
|---|---|---|
| Prefix | the leader | One key |
| Copy mode | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>[</kbd>, or turning the wheel | The focused pane's scrollback |
| Multi copy mode | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>[</kbd> on a multifocus pane | Every pane in the set |
| Rail focus | <kbd>s</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>e</kbd> | The rail's rows |
| Hints | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>F</kbd> | All input to the pane |
| Capture mode | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>C</kbd> | Keyboard and mouse |
| An overlay | the palette, settings, a picker, a dialog | Keyboard, and the mouse over it |

### The mode indicator

The leftmost cell of the dock is the **mode pill**. Its colour and its glyph
tell you who has the keyboard. With the Nerd Font glyph set the icons are a
window, a terminal and a grid; with an ASCII glyph set they are the letters
below.

| Pill shows | Meaning |
|---|---|
| ` W ` (window icon), window colour | Window mode, tiling off |
| ` T ` (terminal icon), terminal colour | Terminal mode, tiling off |
| ` # ` + `V` or `H`, window colour | Window mode, tiling on; `V`/`H` is how the next new window will split the focused pane |
| ` # ` + `V` or `H`, terminal colour | Terminal mode, tiling on |
| `12:40`, copy colour | Copy mode, with the copy cursor's row and column |
| `MULTI 3` or `MULTI 2/3` | Multi copy mode on 3 panes; after a search, 2 of them matched |
| `SIDEBAR`, accent colour | The rail has the keyboard |
| window icon + `HOLD` | Window mode held by `hold_window_mode`; it ends when the key is let go |
| ... ` Z` | Appended while a pane on the workspace is zoomed |

Right after the pill the dock prints the **trail**, ` 2:3 `: the current
workspace and how many windows it holds.

::: example
**Example: reading the pill.** You see `# V` in the terminal colour followed
by ` 1:2 `. You are typing into a shell (terminal mode), tiling is on, the next
window will open side by side with the focused pane, and workspace 1 holds two
windows.
:::

## BSP tiling

BSP (binary space partitioning) is the default tiling layout. It is the model
bspwm uses: the screen is a binary tree, every internal node is a split into
two halves, and every leaf is one window. Upstream keeps its tiling guide on
the docs site at <https://tuios.dev/docs/bsp-tiling>; this section describes
the behaviour of v0.8.5 as the source implements it.

### The tree

Each workspace has its own BSP tree. A leaf holds one window. An internal node
holds a **split type** and a **split ratio**:

- A **vertical** split puts its two children side by side, with a vertical
  divider between them (left/right).
- A **horizontal** split stacks its children, with a horizontal divider
  (top/bottom).
- The **ratio** is where the divider sits, from 0.0 to 1.0. Every new split
  starts at 0.5, the middle.

```text
workspace 1, three windows                tree

+-------------+-------------+             vertical 0.5
|             |   B         |             ├── A
|   A         +-------------+             └── horizontal 0.5
|             |   C         |                 ├── B
+-------------+-------------+                 └── C
```

As data:

```js
tree = {
  split: "vertical", ratio: 0.5,
  left:  { window: "A" },
  right: { split: "horizontal", ratio: 0.5,
           left: { window: "B" }, right: { window: "C" } },
}
```

When a window opens it **splits the focused pane**: the focused leaf becomes an
internal node, the old window becomes its first child and the new window its
second. When a window closes, its sibling takes over the parent's whole space,
so the tree collapses by one level.

### Turning tiling on and off

| Keys | Action |
|---|---|
| <kbd>t</kbd> (window mode) | Toggle tiling |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Space</kbd> | Toggle tiling |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> <kbd>t</kbd> | Toggle tiling (window sub-prefix) |
| Palette: "Layout: BSP tiling" | Use BSP, turning tiling on if it was off |

```sh
tuios set-layout -s work --tiling true
tuios run-command -s work ToggleTiling      # also EnableTiling, DisableTiling
```

Turning tiling off leaves every window floating where it was. Turning it on
again retiles the workspace. The layout **mode** (BSP, master-stack,
scrolling) is remembered across the toggle.

::: default
`startup.tiled = true`: new sessions start tiled. `startup.layout = "bsp"`: the
mode a new session starts in.
:::

### Insertion schemes

When nothing says which way to split, the workspace's **tiling scheme**
decides the axis of the next automatic split:

| Scheme | How it picks the axis |
|---|---|
| `spiral` (default) | Alternates by the depth of the window being split, bspwm style, which spirals inward |
| `longest_side` | Splits across the focused window's longer side |
| `alternate` | Alternates by the total number of splits in the tree |
| `smart_split` | From the focused window's shape: wider than twice its height splits side by side, taller than wide stacks, otherwise depth parity |

```toml
[appearance]
tiling_scheme = "longest_side"   # the scheme a NEW workspace starts with
```

The scheme is per workspace. Change the one on screen from the palette
("Cycle tiling scheme", "Set tiling scheme: spiral", and so on) or bind the
actions `cycle_tiling_scheme` and `set_tiling_scheme_spiral`,
`_longest_side`, `_alternate`, `_smart_split`, which have no default key.

The mode pill always shows the axis of the next split: `V` for side by side,
`H` for stacked. "Smart split" in the palette (tiling on) splits the focused pane once, on the
axis its aspect ratio suggests.

### Splitting on purpose

An explicit split chooses the axis for you:

| Keys (window mode) | Prefix chord | Action |
|---|---|---|
| <kbd>\|</kbd> or <kbd>\\</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>\|</kbd> | `split_vertical`: new window to the right (left/right) |
| <kbd>-</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>-</kbd> | `split_horizontal`: new window below (top/bottom) |

```sh
tuios split-window -s work vertical
tuios split-window -s work horizontal -w build --name logs
tuios split-window -s work vertical --json | jq -r .window_id
```

The right-click pane menu has "Split right" and "Split down" for the same two
splits.

::: note
tmux users: tuios names the split after the **divider**, like vim. A
"vertical" split draws a vertical line and gives you two panes side by side.
:::

### Preselection

Preselection says where the **next** window goes, relative to the focused
pane, before you open it. Press a preselect key, then make a window with
<kbd>n</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>c</kbd> or any other new-window
command. The new window lands on that side and the preselection is used up.

| Keys (window mode) | macOS | Places the next window |
|---|---|---|
| <kbd>Alt</kbd>+<kbd>h</kbd> | <kbd>Opt</kbd>+<kbd>h</kbd> | Left of the focused pane (vertical split, new window first) |
| <kbd>Alt</kbd>+<kbd>l</kbd> | <kbd>Opt</kbd>+<kbd>l</kbd> | Right of it (vertical split, new window second) |
| <kbd>Alt</kbd>+<kbd>k</kbd> | <kbd>Opt</kbd>+<kbd>k</kbd> | Above it (horizontal split, new window first) |
| <kbd>Alt</kbd>+<kbd>j</kbd> | <kbd>Opt</kbd>+<kbd>j</kbd> | Below it (horizontal split, new window second) |

While a preselection is pending, the mode pill shows its axis (`V` for left
and right, `H` for up and down) instead of the scheme's guess. A preselection
belongs to the pane focused when you set it.

::: example
**Example: an editor with a narrow terminal on its left.** Focus the editor,
press <kbd>Alt</kbd>+<kbd>h</kbd>, then <kbd>n</kbd>. The shell opens to the
left of the editor. Press <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd>
<kbd>7</kbd> on the editor to give it 70% of the width.
:::

In a tape script the `Preselect` command does the same (see
[Automation](automation.md)).

### Resizing and split ratios

Every resize in BSP is written into the ratios of the tree, so it survives a
retile, a new window elsewhere, and a reattach.

| Keys (window mode) | Action |
|---|---|
| <kbd>&gt;</kbd> / <kbd>&lt;</kbd> | Move the focused pane's right edge right / left (grow / shrink width) |
| <kbd>.</kbd> | Move the focused pane's left edge left (grow width from the left) |
| <kbd>}</kbd> / <kbd>{</kbd> | Move the bottom edge down / up (grow / shrink height) |
| <kbd>]</kbd> / <kbd>[</kbd> | Move the top edge (grow / shrink height from the top) |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>5</kbd> ... <kbd>9</kbd> | Set the focused pane's width to 50% ... 90% |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Shift</kbd>+<kbd>5</kbd> ... <kbd>9</kbd> | Set its height to 50% ... 90% |
| Drag a divider | Move that one divider |

The percentage actions exist for every step from 10 to 90
(`resize_width_10` ... `resize_width_90`, `resize_height_10` ...); only 50-90
have default keys. The layout still enforces a minimum pane size, the gap and
the neighbours, so you get the requested size wherever the layout allows it.
Dragging a divider moves only the split that owns that edge, so unrelated
panes stay still.

### Swapping

Swapping exchanges two windows' places in the tree. The tree's shape and its
ratios stay; only which window sits in which leaf changes.

| Keys (window mode) | Action |
|---|---|
| <kbd>H</kbd> or <kbd>Ctrl</kbd>+<kbd>Left</kbd> | Swap with the neighbour on the left |
| <kbd>L</kbd> or <kbd>Ctrl</kbd>+<kbd>Right</kbd> | Swap right |
| <kbd>K</kbd> or <kbd>Ctrl</kbd>+<kbd>Up</kbd> | Swap up |
| <kbd>J</kbd> or <kbd>Ctrl</kbd>+<kbd>Down</kbd> | Swap down |
| Drag a tiled pane by its title bar onto another | Swap the two |

### Rotating

Rotating flips the split that holds the focused pane between vertical and
horizontal. Its two children stay in order, so side by side becomes stacked
and back.

| Keys | Action |
|---|---|
| <kbd>R</kbd> (window mode), <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>R</kbd> | `rotate_split` |

```sh
tuios set-layout -s work --rotate
tuios run-command -s work RotateSplit
```

### Equalizing

Equalizing resets every split ratio on the workspace to 0.5, undoing all
resizes at once.

| Keys | Action |
|---|---|
| <kbd>=</kbd> (window mode), <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>=</kbd> | `equalize_splits` |

```sh
tuios set-layout -s work --equalize
tuios run-command -s work EqualizeSplits
```

::: note
Equalizing sets each split to half of its parent, which is not the same as
giving every pane the same area. Three panes made by splitting one pane twice
end up as one half and two quarters.
:::

### Gaps and shared borders

Two settings change the space between tiles:

```toml
[appearance]
gap = 1               # cells of empty ground between neighbouring panes (default 0)
shared_borders = true # one divider line between adjacent panes, tmux style (default false)
```

- **`gap`** leaves empty cells between panes, in every tiling mode.
- **`shared_borders`** drops each pane's own border box and draws one
  separator between neighbours, which gives each pane two more columns and
  rows. It applies to BSP and master-stack only; the scrolling layout always
  draws its own borders. The palette has "Toggle shared borders", and the flag
  `tuios --shared-borders` turns it on for one run.

`gap`, `master_ratio`, `scroll_column_width` and `shared_borders` decide how
many cells a pane gets, so they are settled across the session: change one on
any client and every client attached to the session follows. Purely visual
settings (theme, border style, glyphs, dimming) stay per client.

## Layout modes

Tiling has three layout modes. Tiling on or off is one switch
(<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Space</kbd>); which mode it uses when it
is on is a second choice, made from the command palette. Choosing a mode turns
tiling on if it was off. Upstream:
<https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/LAYOUT_MODES.md>.

| Palette command | Mode |
|---|---|
| Layout: BSP tiling | Binary space partitioning, the default |
| Layout: master-stack | Master panes on one side, the rest stacked beside them |
| Layout: scrolling (niri-style) | An endless horizontal strip of columns |
| Layout: disable tiling | Turn tiling off; every window floats |

"Next layout" and "Previous layout" in the palette are different: they cycle through your saved layout templates, not through these modes. The mode is per
session and lives in the daemon's session state, so a scrolling session comes
back scrolling after a reattach. The layout data itself (the tree, the strip,
the master side and count) is per workspace.

```toml
[startup]
layout = "master-stack"   # bsp, master-stack or scrolling, for NEW sessions
```

### Master-stack

The first pane or panes of the workspace form the **master** area; the rest
form the **stack** beside it. It is the dwm tile layout and Hyprland's master
layout: give the pane you work in most (an editor) the big area and keep the
helpers in the stack.

```text
master_position = "left"             master_position = "center"
+-----------------+--------+         +------+------------+------+
|                 |   B    |         |  C   |            |  B   |
|      A          +--------+         |      |     A      |      |
|   (master)      |   C    |         |      |  (master)  |      |
+-----------------+--------+         +------+------------+------+
```

| Setting | Default | Meaning |
|---|---|---|
| `appearance.master_position` | `left` | `left`, `right`, `top`, `bottom` or `center` |
| `appearance.master_count` | `1` | How many panes are masters, 1-9; masters share the area equally |
| `appearance.master_ratio` | `50` | The master area's share of the screen, percent (10-90) |
| `appearance.master_grid` | `true` | With one master on the left, show four or more panes as an equal grid |

With `center`, stack panes go right, then left, then right; with only one stack
pane the master goes left. Two panes on a screen taller than wide stack
vertically. The settings are where a workspace **starts**; the keys change the
workspace on screen, and it keeps the change (in the daemon, for every client):

| Keys | Action |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>o</kbd> | Move the masters to the next side: left, right, top, bottom, center |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Enter</kbd> | Swap the focused pane with the master (on the master: with the first stack pane) |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>m</kbd> | Focus the master |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>i</kbd> / <kbd>d</kbd> | One more / one fewer master |
| <kbd>&lt;</kbd> <kbd>&gt;</kbd> (and drag the divider) | Move the master/stack divider (width keys for left, right, center; height keys for top, bottom) |

```sh
tuios set-layout -s work --master-position center
tuios set-layout -s work --masters 2
tuios run-command -s work SwapWithMaster
```

The default grid (one master on the left, four or more panes) has no ratio to
keep, so a resize there lasts only until the next retile.

### Scrolling (niri-style)

The scrolling layout, modelled on the niri window manager, arranges windows as
**columns** on a strip wider than the screen; the screen is a viewport onto the
strip. A new window becomes a new column right after the focused one and the
viewport scrolls to it, instead of every pane shrinking to make room. A column
can hold several windows stacked vertically, sharing its height evenly.

```text
          viewport (the screen)
       +-------------------------+
 ...[ col 1 ][   col 2   ][ col 3 ]...[ col 4 ]
       +-------------------------+
```

| Input | Action |
|---|---|
| <kbd>h</kbd> / <kbd>l</kbd>, <kbd>Alt</kbd>+<kbd>Left</kbd> / <kbd>Right</kbd> | Focus the column left / right |
| <kbd>j</kbd> / <kbd>k</kbd>, <kbd>Alt</kbd>+<kbd>Down</kbd> / <kbd>Up</kbd> | Focus the window below / above in a column |
| <kbd>Alt</kbd>+<kbd>p</kbd> / <kbd>Alt</kbd>+<kbd>n</kbd> | Focus the column left / right |
| <kbd>H</kbd> / <kbd>L</kbd>, <kbd>Ctrl</kbd>+<kbd>Left</kbd> / <kbd>Right</kbd> | Move the focused column along the strip |
| <kbd>&lt;</kbd> / <kbd>&gt;</kbd> | Shrink / grow the focused column by four cells |
| <kbd>Alt</kbd>+wheel or <kbd>Shift</kbd>+wheel | Scroll the viewport sideways |
| Palette: "Scroll: cycle column width" | 33%, 50%, 55%, 67%, 90% of the screen |
| Palette: "Scroll: move window into the column below" | `scroll_consume`: pull the next column's window into this one |
| Palette: "Scroll: move window out to its own column" | `scroll_expel`: push the bottom window out to a new column |

Keyboard focus scrolls the focused column into view, centred, with its
neighbours peeking in at the edges. A plain wheel belongs to the pane under
the pointer; only <kbd>Alt</kbd> or <kbd>Shift</kbd> moves the strip, so a
trackpad's sideways drift cannot walk the layout.

| Setting | Default | Meaning |
|---|---|---|
| `appearance.scroll_column_width` | `55` | A new column's width, percent of the screen (20-90) |
| `appearance.scroll_column_max` | `90` | Highest width the column may be set to (up to 100) |
| `appearance.niri_scroll_cells` | `8` | Cells one wheel event moves the strip (1-200) |
| `appearance.niri_reverse_scroll` | `false` | Invert the wheel direction |
| `appearance.niri_click_reveals` | `true` | Bring a clicked column fully on screen |

The default 55% is just over half on purpose: two columns never quite fit, so
the strip reads as something you scroll. Limits: shared borders are never
drawn here, the column arrangement is rebuilt on reattach (only the mode and
the scroll offset are session state), height percentage resizes do nothing,
and the viewport slide always animates.

### The aggregate view

The aggregate view ("All windows" in the palette, no default key) is a
searchable list of every window on every workspace of the session. Each row
shows the window's name, its agent state glyph, its workspace and its working
directory. Minimized and floating windows are listed and marked.

| Key | Action |
|---|---|
| type | Fuzzy-filter by title, workspace or directory |
| <kbd>Up</kbd> / <kbd>Down</kbd>, <kbd>Ctrl</kbd>+<kbd>p</kbd> / <kbd>Ctrl</kbd>+<kbd>n</kbd> | Move |
| <kbd>Enter</kbd> or a click | Jump: switch workspace, restore if minimized, focus |
| <kbd>Ctrl</kbd>+<kbd>u</kbd> | Clear the query |
| <kbd>Esc</kbd>, <kbd>Ctrl</kbd>+<kbd>c</kbd> | Close |

It is also what the dock opens when you click the marker for minimized windows
that did not fit on the bar.

::: note
Upstream `LAYOUT_MODES.md` describes a three-line content preview per row. The
v0.8.5 renderer (`render_aggregate_view.go`) deliberately dropped the preview
in favour of name, state, workspace and directory on the row itself.
:::

### Multifocus

Multifocus broadcasts your typing to several panes at once, like tmux's
`synchronize-panes`. Panes in the set are drawn with a distinct border colour.

| Input | Action |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+click a window | Add it to the set or remove it |
| Palette: "Toggle multifocus" (`toggle_multifocus_active`) | Add or remove the focused window |
| Palette: "Toggle multifocus on all panes" (`toggle_multifocus_all`) | Add every visible pane on the workspace, or remove them all |
| Palette: "Clear multifocus" | Empty the set |

```toml
[keybindings.prefix_mode]
toggle_multifocus_active = ["y"]
toggle_multifocus_all = ["Y"]
```

```sh
tuios xpanes --ssh web1 web2 web3            # one pane per host, tiled, all in the set
tuios run-command -s work SetMultifocus api worker
tuios run-command -s work SetMultifocus      # empty the set
```

In **terminal mode** every key and every paste that would reach the focused
pane also goes to each pane in the set that is on the current workspace and
not minimized. tuios's own keys (the leader and its chords, overlays,
workspace switches, copy mode) are never broadcast. The set is client-side:
it does not survive a detach, other clients do not share it, and switching
sessions clears it. <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>[</kbd> on a pane in the
set starts [multi copy mode](#multi-copy-mode).

### When to use which

| You want | Use |
|---|---|
| A few panes you resize and rearrange freely | BSP, with preselection for placement |
| One main pane (editor, agent) and helpers | Master-stack |
| Many panes at a readable width, no shrinking | Scrolling |
| To find a pane among many workspaces | The aggregate view, or the palette |
| To type the same thing into several hosts | Multifocus |
| Free placement, overlapping windows | Tiling off (floating) |
| A temporary floating window over a tiled layout | "Toggle floating", or a popup |

## The chrome

The **chrome** is everything tuios draws that is not a pane's content: the
dock, the rail, the title bars, the borders and the scrollbar. With the
defaults the screen looks like this:

```text
+--------------------------------------------------------------------------+
| # V  1:3  [1 code][2 logs][+]   [build] [htop]     ! saved  12:40  [<-][x]|  <- dock
+------------------------------------------------+-------------------------+
| (o)(o)(o) nvim main.go ------------------------| sessions             +  |
|                                                |  > work            3    |
|                                                |    scratch         1    |
|        focused pane                            | terminals            +  |
|                                                |  > nvim main.go         |  <- rail
+------------------------+-----------------------+    fish                 |
| (o)(o) fish            | (o)(o) cargo test     | files                   |
|                        |                       |    src/                 |
+------------------------+-----------------------+ agents                  |
+--------------------------------------------------------------------------+
```

### The dock

The **dock** is one row at the top of the screen
(`appearance.dockbar_position`: `top`, `bottom` or `hidden`; default `top`).
It has a left block, a centre block and a right block, each an ordered list of
named **components**. The defaults are:

```toml
[dock]
left   = ["mode", "workspaces", "trail", "tape"]
center = ["windows"]
right  = ["notifications", "copy-help", "cpu", "ram", "clock", "session-controls"]
```

| Component | What it shows |
|---|---|
| `mode` | The mode pill (see [The mode indicator](#the-mode-indicator)) |
| `workspaces` | The workspace strip: one pill per occupied workspace plus the current one, and a trailing `+` |
| `trail` | ` workspace:windows `, such as ` 2:3 ` |
| `tape` | A passive badge when the focused pane's directory holds a project tape (`.tuios.tape`) |
| `windows` | The minimized windows of the current workspace, always in the centre |
| `notifications` | The message block: the latest dock message, always at the right |
| `copy-help` | Copy mode's key help while copy mode is on, always at the right |
| `cpu`, `ram` | Meters, drawn only when `show_cpu` / `show_ram` is on |
| `clock` | The time, drawn only when `show_clock` is on; `[dock.clock] format` sets the layout |
| `session-controls` | Leave (detach) and close-session controls, always the bar's last columns |
| `custom/NAME` | A command of yours whose first line of output becomes a cell |

Naming a component makes it eligible to draw, not certain to: the meters still
need their switches, and the workspace strip shows only when there are at
least two pills to click. How to reorder, add custom components and refresh
them is in [Configuration](configuration.md#the-dock-table).

```sh
tuios list-dock-components --json
tuios refresh-dock agents
```

#### The workspace strip

Each pill is a workspace's name (`appearance.dock_workspace_tab_format`,
default `{name}`; `{index}` is the number). The current workspace is lit. A
long name is truncated and pops up in full on hover
(`dock_workspace_tooltip`). Clicking a pill switches to it; dragging a pill
reorders the strip for every client of the session. The `+` opens the next
empty workspace. When the strip has more pills than room, arrows at its ends
scroll it.

#### Minimized windows

The centre block lists the minimized windows of the current workspace by name.
Clicking one restores it. When they do not all fit, a marker stands for the
rest; clicking it opens the aggregate view, which lists them.

#### Messages

tuios reports what it did (`Yanked 42 chars`, `Window: floating`, a config
error) in the **message block** at the dock's right end, never over a pane.
Programs in panes can raise messages too: a desktop notification escape
(OSC 9, OSC 777, OSC 99) or a bell becomes a dock message, rate-limited so a
flood cannot fill the stack. A thin rule above the block lights in the
severity colour and burns down as the message ages; a sticky error stays lit.

| Action | Result |
|---|---|
| Click the message body | Jump to the pane it came from |
| Click its right-hand end | Dismiss it |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>j</kbd> | Jump to the pane the newest message came from |

```toml
[notifications]
duration = 3          # seconds an info message stays (see configuration.md)
error_sticky = true
```

```sh
tuios run-command -s work ShowNotification "deploy finished" success
```

#### Session controls

The last columns of the dock hold two controls. **Leave** (prominent) detaches
this client and leaves the session running. **Close** (muted until hovered)
ends the session and everything in it, and always asks first in a dialog that
names what would die. Hovering either shows its label.

### The rail

The **rail** is the sidebar: a column of sessions, terminals, files, git state
and agents, on by default on the right edge (`appearance.sidebar.enabled`,
`appearance.sidebar.position`: `left`, `right` or `hidden`). The docs call it
both "the rail" and "the sidebar"; they are the same thing.

#### Sections

The rail stacks **sections**, top to bottom, from one string:

```toml
[appearance.sidebar]
sections = "sessions:25,terminals,files:25,agents:34"   # the default
```

| Section | Shows |
|---|---|
| `sessions` | Every session on this daemon (and on configured machines), with a window count; a `+` on the header makes a new session |
| `terminals` | The windows of the session being shown, with their state glyphs; `+` makes a window |
| `files` | A listing of the focused pane's working directory |
| `git` | The repository the focused pane is in: its branch, how far it is ahead or behind its upstream, and (with `git_dirty`) a count of changed paths. Not in the default list |
| `agents` | Panes running a coding agent, most urgent first (see [Agents](agents.md)) |
| `spacer` | An empty block; with no share it pushes what follows to the bottom |

A section left out is not drawn. The number after a colon is a **ceiling**,
not a reservation: a section takes only as many lines as it has rows, and the
section without a share (by default `terminals`) gets the rest.

The current session and the focused pane carry an accent mark in the rail's
one-cell gutter. A row that needs you (an agent waiting on input, an error)
puts the same mark in its severity colour and is the rail's only bold text.

#### Width

| Screen width | Rail |
|---|---|
| 90 columns or more | Full width (`appearance.sidebar.width`, default 24) |
| 60-89 | Narrow, 16 columns: glyph and short name |
| 40-59 | Glyph strip, 3 columns |
| under 40 | Hidden |

The rail never squeezes the panes below 30 columns; it steps down a variant
first. You can also fold it to the 3-column strip and back, and drag its inner
edge to resize it (up to about two fifths of the screen). The strip keeps the
same lists, with one-letter headers (`s`, `t`, `a`); hovering a strip cell
shows a tooltip. Width, fold state and your session order are saved in a
small state file of their own, not in `config.toml`.

| Keys | Action |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>b</kbd> | Show or hide the rail |
| <kbd>s</kbd> (window mode), <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>e</kbd> | Give the rail the keyboard; the same key gives it back |
| Palette: "Toggle sidebar" | Show or hide |

#### Rail keys

While the rail has the keyboard the mode pill says `SIDEBAR`. These are the
defaults in `[keybindings.sidebar]`:

| Keys | Action |
|---|---|
| <kbd>j</kbd> <kbd>k</kbd>, <kbd>Down</kbd> <kbd>Up</kbd> | Move the cursor |
| <kbd>g</kbd> <kbd>G</kbd>, <kbd>Home</kbd> <kbd>End</kbd> | First / last row |
| <kbd>Enter</kbd> | Activate: switch to the session, focus the pane, open the folder |
| <kbd>l</kbd> <kbd>h</kbd>, <kbd>Right</kbd> <kbd>Left</kbd> | Expand / collapse |
| <kbd>J</kbd> <kbd>K</kbd>, <kbd>Shift</kbd>+<kbd>Down</kbd> <kbd>Up</kbd> | Move the row down / up (reorder sessions) |
| <kbd>Tab</kbd>, <kbd>Shift</kbd>+<kbd>Tab</kbd> | Next / previous section |
| <kbd>1</kbd> to <kbd>9</kbd> | Jump to row N |
| <kbd>n</kbd> / <kbd>t</kbd> | New session / new window |
| <kbd>r</kbd> | Rename the session or window under the cursor |
| <kbd>c</kbd> | Accent colour |
| <kbd>x</kbd> | Kill the row's session or window |
| <kbd>m</kbd> | The row's context menu |
| <kbd>f</kbd> / <kbd>o</kbd> | Agents section: filter (all/here) / sort (priority/recent) |
| <kbd>i</kbd> | Mail |
| <kbd>/</kbd> | Command palette |
| <kbd>Ctrl</kbd>+<kbd>f</kbd> | Search file names below the folder the files section shows |
| <kbd>&lt;</kbd> <kbd>&gt;</kbd> | Narrow / widen the rail |
| <kbd>?</kbd> | Rail help |
| <kbd>Esc</kbd>, <kbd>s</kbd> | Give the keyboard back |

On an agent row, `[keybindings.sidebar_agents]` is consulted first:
<kbd>u</kbd> mark unread, <kbd>z</kbd> snooze, <kbd>r</kbd> reply,
<kbd>v</kbd> review, <kbd>x</kbd> drop the newest queued message. These are
described in [Agents](agents.md).

#### The files section and file operations

The files section lists the folder the focused pane's shell reports (through
OSC 7). It follows the pane as you `cd`. Six file actions work on the row
under the cursor, from `[keybindings.sidebar_files]`, which is consulted only
while the cursor is on a file row:

| Key | Action | Notes |
|---|---|---|
| <kbd>Enter</kbd> | Open | A folder navigates into it; a file copies its path |
| <kbd>Shift</kbd>+<kbd>Enter</kbd> | Edit | Opens a text file in a new pane with the editor from Settings, Sidebar, File editor (else `$EDITOR`) |
| <kbd>a</kbd> | Create | A new file, or a folder when the name ends in `/` |
| <kbd>r</kbd> | Rename | |
| <kbd>d</kbd> | Delete | To the trash by default (`file_delete = "trash"`) |
| <kbd>D</kbd> | Delete for good | Permanent, after confirmation |
| <kbd>y</kbd> / <kbd>x</kbd> | Copy / cut | Into the rail's own file clipboard |
| <kbd>p</kbd> | Paste | Into the folder shown |

Every prompt is a centred dialog, not a cramped line in the rail, and every
delete confirmation opens on **Cancel**, so <kbd>Enter</kbd> on an untouched
dialog destroys nothing. File operations run off the UI thread, so a large
paste does not freeze the screen. Right-clicking a file row opens the same
actions as a menu (Open, Edit, Copy path, Copy, Cut, Paste, Rename, Delete,
Delete for good, New file or folder).

```toml
[appearance.sidebar]
folder_click = "navigate"   # navigate (default), cd (type cd into the pane), both
file_actions = true         # false turns the six actions off
file_delete = "trash"       # trash (default) or permanent
editor = "nvim"             # the File editor setting
```

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>f</kbd> searches file names below the
focused pane's directory from anywhere, even while you type in a pane. Type a
name or a relative path and press <kbd>Enter</kbd>: the rail shows, opens that
folder and selects the file. The search skips `.git`, `node_modules`, `.venv`
and `target`, and stops after about 2.5 seconds (its title says `partial`).

::: warning
The folder comes from a string the pane printed. Where `/proc` shows that the
pane's shell is really somewhere else, tuios refuses the file actions rather
than act on a folder the pane chose. On a remote session the editor must exist
on that machine; tuios says so in the dock if it does not.
:::

### Title bars and window buttons

Each window's border carries a **title bar** with its name or title
(`window_title_position`: `top`, `bottom`, `hidden`) and up to three
**controls**:

| Control | Action |
|---|---|
| Close | Close the window |
| Minimize | Minimize it to the dock |
| Zoom | Toggle zoom (on tiled panes too, unless `window_button_zoom = false`) |

```toml
[appearance]
window_button_style = "dots"      # dots (macOS traffic lights, default) or pill
window_button_position = "left"   # left (default) or right
hide_window_buttons = false
```

The `dots` style draws its symbols only while the pointer is over them.
Dragging the title bar moves a floating window, or swaps a tiled one.

### Borders

| Option | Values | Default |
|---|---|---|
| `appearance.border_style` | `rounded`, `normal`, `thick`, `double`, `hidden`, `block`, `ascii`, `outer-half-block`, `inner-half-block`, `glyphs` | `rounded` |
| `appearance.border_focused_color`, `border_unfocused_color` | `#RRGGBB` | from the theme |
| `appearance.session_border` | carry the session's accent colour on every border | `false` |
| `appearance.zen_mode` | `disabled`, `always` (no borders), `mouse` | `disabled` |
| `appearance.dim_unfocused` | percent an unfocused pane's content fades (0 = off) | `0` |
| `appearance.modal_dim` | percent the screen behind a modal overlay darkens | `30` |

The focused window's border uses the focused colour; multifocus panes use a
colour of their own. With `shared_borders` on, tiled panes share one divider
instead of each drawing a box (see [Gaps and shared borders](#gaps-and-shared-borders)).

### The scrollbar

While a pane is scrolled back into its history, a **scrollbar thumb** appears
in the pane's last content column. At the live tail there is nothing to read,
so there is no thumb. The bottom border shows the scroll position as
offset/total.

| Mouse | Action |
|---|---|
| Click on the bar | Jump to that position |
| Drag the thumb | Scroll |

```toml
[appearance.scrollbar]
style = "track"   # track (default) or thin
tint  = "quiet"   # quiet, border, muted or #RRGGBB
thumb = "█"       # one-cell glyph
track = "none"    # one-cell glyph or none
```

`appearance.hide_scrollbar = true` hides the thumb entirely.

## Overlays

An **overlay** is a panel drawn over the panes: the palette, a picker, a menu,
a dialog. A modal overlay darkens the screen behind it (`modal_dim`) and owns
the keyboard until it closes. Every list in every overlay moves the same way:

| Keys | Action |
|---|---|
| <kbd>Up</kbd> <kbd>Down</kbd>, <kbd>Ctrl</kbd>+<kbd>p</kbd> <kbd>Ctrl</kbd>+<kbd>n</kbd> | Move one row (wrapping at the ends; `appearance.wrap_lists = false` stops instead) |
| <kbd>Home</kbd> <kbd>End</kbd> | First / last row |
| <kbd>PgUp</kbd> <kbd>PgDn</kbd> | A page |
| <kbd>k</kbd> <kbd>j</kbd> <kbd>g</kbd> <kbd>G</kbd> | Up, down, first, last, in a list with no filter to type into |
| <kbd>Ctrl</kbd>+<kbd>u</kbd> | Clear the typed filter |
| wheel | Scroll the list under the pointer |
| <kbd>Esc</kbd> | Close |

With the mouse you can click a row, scroll with the wheel, click outside to
dismiss, and move a floating panel by dragging its title bar or with a right
drag. The key hints at the foot of a panel shorten to fit (`ctrl+` becomes
`^`, `alt+` becomes `M-`, `shift+` becomes `S-`). An empty list says why it is
empty and names the one key worth pressing.

### The command palette

<kbd>Ctrl</kbd>+<kbd>p</kbd> (also <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>P</kbd>,
and <kbd>/</kbd> on the rail) opens the **command palette**: one fuzzy search
over every tuios command, every session and pane, your settings and your
keybindings. It works in both modes.

With nothing typed, commands are grouped under category headers (Window,
Layout, Navigation, Session, Sessions, Workspaces, Copy Mode, Clipboard, View,
Files, Settings, Agents, Commands, Debug, Tape Scripting, and so on); the
cursor steps over the headers. Once you type, rows are ranked by how well they
match and each row names its category in a quiet column on the right.

| Footer | Meaning |
|---|---|
| `↑↓ move` | Move the selection |
| `⏎ run` | Run the selected row |
| `@ state` | Type `@` to filter panes by agent state |
| `esc close` | Close |

What you can find:

| Type | Finds |
|---|---|
| Plain words | Commands ("split", "zoom", "toggle sidebar", "all windows", "reload config") |
| A session or pane name | The **Sessions** rows: every session and the panes inside each, including sessions you are not attached to |
| `settings: ...` | Any row of the settings page, by name ("settings: pane background") |
| `#word` | Every action whose name, key or description contains `word`; selecting one opens the keybind manager on it |
| `run` | "Run a program", which opens the launcher |
| `@state` | Only panes in that agent state |

#### The `@` state filter

A leading `@` token keeps only the panes whose agent is in a given state, and
drops every static command. It is resolved by prefix, so one letter is enough:

| Token | Keeps panes that are |
|---|---|
| `@` alone | running an agent at all |
| `@a`, `@attention` | waiting on input or errored (what the rail marks as needing you) |
| `@w`, `@working` | working |
| `@n`, `@needs_input` | waiting on input |
| `@d`, `@done` | done |
| `@i`, `@idle` | idle |
| `@e`, `@errored` | errored |

Text after the token is matched as usual, so `@a api` finds the panes needing
you whose name matches `api`. An `@` naming no state matches nothing rather
than silently matching everything.

#### The cross-session terminal picker

The palette's Sessions rows are tuios's cross-session terminal picker. They
list every session in the daemon (and on configured machines) and the panes in
each, built from cached state when the palette opens, so it opens instantly.
Selecting a pane in the session you are attached to focuses it. Selecting a
pane in **another** session switches the client to that session first, which
rebuilds the whole view; such rows say so in their hint slot, and the palette
never switches silently. Unread mail threads also appear here (`Mail #3 ...`),
and selecting one opens it.

::: example
**Example: jump to a build pane in another session.** Press
<kbd>Ctrl</kbd>+<kbd>p</kbd>, type `build`, move to the row naming session
`ci`, press <kbd>Enter</kbd>. The client switches to `ci` and focuses the
build pane. `@e` instead of `build` lists only the panes whose agent errored.
:::

### The launcher

<kbd>Alt</kbd>+<kbd>Space</kbd> (also <kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>a</kbd>) opens the **launcher**: a fuzzy search over every program on
`$PATH` and your installed desktop applications, ranked by match and by how
often you launch each one. It is separate from the palette on purpose: palette
rows are things tuios does, launcher rows are things you start.

| Keys | Action |
|---|---|
| type | Filter; desktop-entry keywords match too ("browser" finds Firefox) |
| <kbd>Enter</kbd> or a click | Start the program in a new pane |
| <kbd>Tab</kbd> | Open a new pane with the command typed at the prompt but not run, so you can add arguments |
| <kbd>Esc</kbd> | Close |

The program list is scanned in the background, so the launcher is typeable at
once. Application icons are drawn where the terminal supports kitty graphics.

### The settings page

<kbd>,</kbd> in window mode or <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>,</kbd> opens
the **settings page**, a live editor for `config.toml`. Its tabs are
Appearance, Backgrounds, Sidebar, Selection, Dock, Behavior, Alerts, Startup,
Screenshot, Saver, Spotlight, Advanced, Daemon, the machines tab and Tape. It
reopens on the tab, row and search you left it on.

| Keys | Action |
|---|---|
| <kbd>Left</kbd> <kbd>Right</kbd>, <kbd>h</kbd> <kbd>l</kbd> | Change the row's value |
| <kbd>Enter</kbd>, <kbd>Space</kbd> | Toggle, cycle, or open the row's picker or editor |
| <kbd>Tab</kbd> <kbd>Shift</kbd>+<kbd>Tab</kbd>, <kbd>[</kbd> <kbd>]</kbd> | Next / previous tab |
| <kbd>1</kbd> to <kbd>9</kbd> | Go to that tab |
| <kbd>/</kbd>, or a letter the page does not use | Search every tab |
| <kbd>Backspace</kbd>, <kbd>Delete</kbd> | Reset the row to its default |
| <kbd>Ctrl</kbd>+<kbd>z</kbd> | Undo the last change |
| <kbd>Esc</kbd>, <kbd>q</kbd> | Close |

A row changed from its default carries a dot after its name. The search ranks
every row of every tab by name, config key, value and description. The same
search runs from a shell:

```sh
tuios list-options --search background
```

Changes are written back to `config.toml`, and tuios watches that file: a save
in your editor takes effect at once, and a file with an error is not applied
(the error shows in the dock). See [Configuration](configuration.md).

### Which-key

Press the leader and wait. After 500 ms the **which-key** panel opens with
every key you can press next, in sections (Windows, Panes, Sessions, Modes,
Menus, Tools, and Agents once an agent has run), laid out in as many columns as
the screen holds. A key marked `+` opens a further menu (the sub-prefixes).
Press a key to run it, or <kbd>Esc</kbd> to cancel. If you press the next key
within 500 ms, the panel never appears.

```toml
[appearance]
whichkey_enabled = true            # default true
whichkey_position = "bottom-right" # bottom-right, bottom-left, top-right, top-left, center
```

### Help and the keybind manager

<kbd>?</kbd> in window mode or <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>?</kbd>
toggles the **help overlay**, a reference of the keys read from your own
config, with an Agents section once agents have run.

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>k</kbd> opens the **keybind manager**: every
action, the keys bound to it in each scope, and conflicts. Search it, rebind
an action, press <kbd>Ctrl</kbd>+<kbd>d</kbd> to remove one binding or
<kbd>Ctrl</kbd>+<kbd>x</kbd> to take a key off every action. The palette rows
"Keybind manager", "Rebind a key" and "Unbind a key" open it too. From a shell:

```sh
tuios keybinds list
tuios keybinds explain ctrl+b
tuios keybinds doctor
tuios keybinds unbind close_window w
tuios keybinds free alt+left
```

### Hints

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>F</kbd> starts **hints mode**, which works
like tmux-fingers or kitty's hints kitten. Short labels appear on the useful
text in the focused pane (URLs, paths, git hashes, IP addresses, UUIDs,
colours, hex numbers, numbers of four or more digits, e-mail addresses,
Kubernetes-style ids, files in a diff) and the rest of the pane dims. Upstream:
<https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/HINTS.md>.

| Keys | Action |
|---|---|
| a label, such as `a` or `ls` | Copy that text and close |
| the label with <kbd>Shift</kbd> (`A`) | Copy it and type it into the pane |
| the label with <kbd>Ctrl</kbd> | Open it: a URL in the browser, a path in a new pane with `$EDITOR` |
| <kbd>Backspace</kbd> | Remove the last letter typed |
| <kbd>Esc</kbd>, the leader | Close |
| <kbd>q</kbd> | Close, when `q` is not a label letter |

The nearest text to the cursor gets the shortest label, and the same text gets
the same label every time. Hints mode takes all input while the labels show; a
click or the wheel closes it first. `hints_all_panes` (no default key, or the
palette entry "Hints: label text on all panes to copy it") labels every
visible pane at once.

```toml
[hints]
builtins = "all"                 # or names such as "url,path,sha", or "none"
patterns = ['JIRA-\d+', 'branch: (?P<match>\S+)']
alphabet = "asdfghjkl"
open = true                      # let Ctrl+label open
dim = 60                         # percent (10-90)
all_panes = false                # make Ctrl+B F label every pane
```

::: warning
<kbd>Ctrl</kbd>+label opens a file only when it is on this machine and the
pane is not running `ssh`, `mosh`, `docker`, `kubectl` and similar; otherwise
it copies the path and says why. Only `http`, `https`, `mailto`, `ftp` and
`ftps` URLs open, and the text is never handed to a shell.
:::

### The context menu

Right-click opens a **context menu** for whatever is under the pointer. Opening
it on a pane focuses that pane first, so "Close" closes the pane you pointed
at; the mode is left alone.

| Right-click on | Menu rows |
|---|---|
| A pane (window mode) | Close pane, Copy selection, Paste, Split right, Split down, Rename, Accent color, Zoom, Screenshot this window, Minimize |
| A pane with a text selection (terminal mode) | Copy selection, Paste, Clear selection |
| A minimized entry in the dock | Restore, Restore all |
| A workspace pill | Switch to, Rename |
| The dock | New window, Toggle tiling, Restore all |
| The empty desktop | New window, Toggle tiling, Command palette, Settings, Help |
| A session on the rail | Rename, Session color, Detach, Switch session..., Switch workspace..., Move up, Move down, Kill session, Kill session, go to next, Kill session and quit |
| A file on the rail | Open / Open folder / Go up, Edit, Copy path, Copy, Cut, Paste, New file or folder, Rename, Delete, Delete for good |

In terminal mode the plain right button belongs to the program, so over a
pane the menu needs <kbd>Ctrl</kbd> or <kbd>Shift</kbd> held (that also works
over programs that track the mouse). Set
`appearance.right_click_opens_menu = true` to let a plain right-click open the
pane menu in terminal mode. On a touch client a long press opens it. Disabled
rows are dimmed.

### Dialogs

A **dialog** is a small centred question. tuios uses them for anything
destructive or anything that needs a name:

| Dialog | Opened by | Notes |
|---|---|---|
| Rename | <kbd>r</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>r</kbd>, workspace and session renames | Anchored to what it renames; a click elsewhere cancels |
| Quit | <kbd>q</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>q</kbd> | Shown when a window runs a foreground process, or always with `confirm_quit = true` |
| Close session | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>X</kbd>, the dock's close control | Names what would die |
| Close workspace | Palette: "Close workspace" | Says how many panes and agents close; scratch panes stay |
| File prompts | The rail's file actions | Create, rename, delete |

Confirmation dialogs open on **Cancel** and never wrap, so <kbd>Up</kbd> from
Cancel cannot land on the answer that deletes.

### Popups

A **popup** is a floating pane centred over the layout for one command. It
closes when the command exits, is never tiled, and is not in the window cycle.

```sh
tuios popup -s work -- htop                              # q closes it
tuios popup -s work --width 90% --height 80% -- lazygit
file=$(tuios popup -s work --capture-stdout -- fzf)      # use the answer
tuios popup -s work --wait -- gum confirm "Deploy?" && ./deploy.sh
```

The default size is 80% by 60% of the pane region. A popup closed by hand
exits 130. A `[[keybindings.command]]` entry of `type = "popup"` binds one to
a key (see [Keybindings](keybindings.md)).

### Switchers and pickers

| Overlay | Opened by | Keys beyond the list keys |
|---|---|---|
| Session switcher | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>S</kbd>, palette "Switch session" | <kbd>Enter</kbd> switch (or create a session named by an unmatched query), <kbd>Ctrl</kbd>+<kbd>r</kbd> rename, <kbd>Ctrl</kbd>+<kbd>d</kbd> delete (never the current session) |
| Workspace switcher | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>W</kbd> | <kbd>Enter</kbd> switch, <kbd>Ctrl</kbd>+<kbd>r</kbd> rename |
| Aggregate view | Palette "All windows" | See [The aggregate view](#the-aggregate-view) |
| Machine picker | "New window on another machine", a new session with hosts configured | Pick where the process runs |
| Layout picker | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>l</kbd> | <kbd>Enter</kbd> load, <kbd>Ctrl</kbd>+<kbd>d</kbd> delete; <kbd>L</kbd> <kbd>s</kbd> saves |
| Theme and glyph pickers | Palette "Theme picker", the settings rows | Preview live as you move |
| Tape manager | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>m</kbd> | See [Automation](automation.md) |
| Log viewer | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> <kbd>l</kbd>, palette "Show logs" | |
| Inbox, mailbox | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>i</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>M</kbd> | See [Agents](agents.md) |

Switching sessions is not a detach: the client tears down its view of the
current session and builds one of the target in place, and the session you
left keeps running.

### The review overlay and the diff view

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>v</kbd> opens the **review overlay** on the
focused pane: the git diff of the changes under that pane's directory, over
the whole screen. It exists for reviewing what a coding agent changed without
leaving tuios, and for sending the agent notes on specific lines. With no git
repository under the pane, the dock says so and nothing opens. It is also
reached with <kbd>v</kbd> on an Inbox item or a rail agent row.

The layout is a **file list** on the left and the **diff view** of the
selected file on the right. The diff view (`internal/diffview`) colours code
by file type in the active theme's colours, puts added and removed lines on
green and red grounds, marks the words that changed inside a changed line, and
can show the old and new sides next to each other when the column is wide
enough (about 120 columns). Your notes are drawn under the lines they are on.

| Keys | Action |
|---|---|
| <kbd>j</kbd> <kbd>k</kbd>, arrows | Move by line (in the file list: by file) |
| <kbd>Space</kbd> <kbd>PgDn</kbd> <kbd>Ctrl</kbd>+<kbd>d</kbd> / <kbd>PgUp</kbd> <kbd>Ctrl</kbd>+<kbd>u</kbd> | Page |
| <kbd>g</kbd> <kbd>G</kbd> | First / last line |
| <kbd>]</kbd> <kbd>[</kbd> / <kbd>}</kbd> <kbd>{</kbd> | Next / previous hunk / file |
| <kbd>s</kbd> | One column, or side by side |
| <kbd>h</kbd> <kbd>l</kbd> | Scroll the code sideways |
| <kbd>Tab</kbd> | Focus the file list or the diff |
| <kbd>c</kbd> / <kbd>C</kbd> | A note on this line / on the whole hunk |
| <kbd>e</kbd> / <kbd>x</kbd> | Edit / resolve the note under the cursor |
| <kbd>S</kbd> | Send every unsent note to the pane's agent as one message |
| <kbd>u</kbd> | Changes since the base, or uncommitted changes only |
| <kbd>b</kbd> | Diff from another base |
| <kbd>w</kbd> | The compare view, for a pane in a fan of attempts |
| <kbd>r</kbd> | Read the diff again |
| <kbd>Esc</kbd>, <kbd>q</kbd> | Close |

These are the overlay's own keys, not rebindable bindings. Keys from
`send-keys` or a tape can move around but never save a note or send. The
compare view, fans and the review workflow are covered in
[Agents](agents.md).

## Copy mode, scrollback and the clipboard

### Scrollback

Every pane keeps a **scrollback** of lines that scrolled off its top:
`appearance.scrollback_lines`, 10,000 by default (100 to 1,000,000), kept on
both sides of the daemon socket. You can look back through it three ways:

| Way | How | What it is |
|---|---|---|
| Wheel | Turn the wheel over a pane | The view scrolls; typing, or scrolling back to the bottom, returns to live output |
| Keys | <kbd>Shift</kbd>+<kbd>Up</kbd> / <kbd>Shift</kbd>+<kbd>Down</kbd> in terminal mode | Scroll into the scrollback and back down |
| Copy mode | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>[</kbd> | Vim-style cursor, search and selection |

The wheel scrolls `appearance.scroll_lines` lines per notch (default 3). It
borrows copy mode's machinery silently: no notification, no change to the
mode pill, no keys to learn. A program that turned on mouse tracking (vim,
less, htop) gets the wheel itself instead, and a pane with no history is left
alone.

```toml
[appearance]
scrollback_lines = 50000
scroll_lines = 5
```

The palette's "Edit scrollback in $EDITOR" opens the pane's scrollback in
your editor.

### Copy mode

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>[</kbd> (or palette "Enter copy mode")
starts **copy mode** on the focused pane. The copy cursor starts on the
terminal cursor, usually the prompt line, as in tmux;
`appearance.selection.copy_entry = "center"` starts it on the middle row. The
mode pill shows the cursor's `row:col` and the dock shows copy mode's key
help. A digit prefix repeats a motion (`5j`, `10G`).

| Keys | Motion or action |
|---|---|
| <kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd>, arrows | Left, down, up, right |
| <kbd>w</kbd> <kbd>b</kbd> <kbd>e</kbd> / <kbd>W</kbd> <kbd>B</kbd> <kbd>E</kbd> | Word / WORD motions |
| <kbd>0</kbd> <kbd>^</kbd> <kbd>$</kbd> | Line start, first non-blank, line end |
| <kbd>Ctrl</kbd>+<kbd>u</kbd> / <kbd>Ctrl</kbd>+<kbd>d</kbd> | Half page up / down |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>PgUp</kbd> / <kbd>Ctrl</kbd>+<kbd>f</kbd> <kbd>PgDn</kbd> | Page up / down |
| <kbd>g</kbd> <kbd>g</kbd> / <kbd>G</kbd> | Top of the scrollback / bottom; `N G` goes to line N |
| <kbd>H</kbd> <kbd>M</kbd> <kbd>L</kbd> | Top, middle, bottom of the screen |
| <kbd>{</kbd> <kbd>}</kbd> | Previous / next paragraph |
| <kbd>%</kbd> | Matching bracket |
| <kbd>f</kbd> <kbd>F</kbd> <kbd>t</kbd> <kbd>T</kbd> + char, <kbd>;</kbd> <kbd>,</kbd> | Find a character on the line, repeat, repeat backward |
| <kbd>/</kbd> / <kbd>?</kbd> | Search forward (toward newer output) / backward (into the scrollback) |
| <kbd>n</kbd> / <kbd>N</kbd> | Next match in the last search's direction / the opposite one |
| <kbd>Ctrl</kbd>+<kbd>l</kbd> | Clear the search highlighting |
| <kbd>v</kbd> / <kbd>V</kbd> | Start a character / line selection |
| <kbd>i</kbd> | Leave copy mode and enter terminal mode |
| <kbd>q</kbd>, <kbd>Esc</kbd> | Leave copy mode |

With a selection active, the motions extend it, <kbd>y</kbd> or
<kbd>c</kbd> yanks it to the clipboard (the dock says `Yanked 42 chars`) and
returns to the copy cursor, and <kbd>Esc</kbd> or <kbd>q</kbd> drops the
selection.

A search starts at the copy cursor and wraps to the other end of the buffer
when it finds nothing, saying so in the dock. More than 1000 matches show as
`1000+`. <kbd>Esc</kbd> in the search prompt cancels it and puts the cursor
back.

```toml
[keybindings.prefix_mode]
copy_mode_search_backward = ["/"]   # Ctrl+B / : copy mode straight into a ? search
```

::: note
In copy mode the leader is <kbd>Ctrl</kbd>+<kbd>b</kbd> page up, so prefix
chords do not work there. Keys from `[keybindings.global]`,
`[keybindings.terminal_mode]` and `[keybindings.window_management]` still do.
:::

A yank can go through a command first: `appearance.selection.copy_command`
pipes every copy-mode yank, and `[[keybindings.copy_pipe]]` binds a key in
copy mode to a command of its own (tmux's `copy-pipe`). See
[Keybindings](keybindings.md).

### Multi copy mode

With two or more panes in the multifocus set, <kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>[</kbd> on one of them starts **multi copy mode**: copy mode on every
pane of the set at once, each with its own cursor and selection, every key
moving all of them. The pill says `MULTI 3`, and after a search `MULTI 2/3`
(found in 2 of 3 panes). A pane where the search found nothing loses the
multifocus colour and sits out motions until a later search finds text in it.

| Key | Action |
|---|---|
| motions, <kbd>/</kbd> <kbd>?</kbd> <kbd>n</kbd> <kbd>N</kbd> | As in copy mode, in every pane |
| <kbd>v</kbd> <kbd>V</kbd> | Start a selection in every pane that has a match |
| <kbd>y</kbd> | Copy every pane's selection as one block |
| <kbd>Y</kbd> | Save every pane's selection to a file (default `~/tuios-copy-<date>-<time>.<ext>`) |
| <kbd>Tab</kbd> | Change the format: plain, markdown, json |
| <kbd>Shift</kbd>+<kbd>Up</kbd> <kbd>Down</kbd> | Scroll every pane one line |
| <kbd>Esc</kbd> twice, <kbd>q</kbd> | Leave multi copy mode |

The json format is an array of `{"pane": N, "window_id": "...", "title": "...", "lines": [...]}`.
`appearance.selection.multi_format` sets the starting format.

### The scrollback browser

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>s</kbd> (palette "Toggle scrollback
browser") opens the **scrollback browser**, which understands shell
integration (OSC 133 prompt marks). Instead of a wall of text it lists the
**commands** you ran, each with its output, so you can copy one command's
output without selecting it by hand. <kbd>Tab</kbd> switches between its
views of commands, JSON and paths found in the output.

| Keys | Action |
|---|---|
| <kbd>j</kbd> <kbd>k</kbd> | Move between entries |
| <kbd>l</kbd> | Enter the selected entry's output (vim motions, <kbd>v</kbd> <kbd>V</kbd>, <kbd>y</kbd> there) |
| <kbd>J</kbd> <kbd>K</kbd> | Scroll the preview |
| <kbd>y</kbd> | Copy the entry's output |
| <kbd>c</kbd> | Copy the command line |
| <kbd>Enter</kbd> | Paste the command back into the pane |
| <kbd>/</kbd> | Search |
| <kbd>Tab</kbd> | Change view |
| <kbd>?</kbd> | Help |
| <kbd>q</kbd>, <kbd>Esc</kbd> | Close |

### Mouse selection

In a pane whose program does not track the mouse:

| Gesture | Selects |
|---|---|
| Drag | From the press to the release; dragging past the pane's top or bottom edge scrolls |
| Double-click | A word (`appearance.word_characters`, default `@-./_~?&=%+#`, counts as part of a word) |
| Triple-click | A line |

With `appearance.copy_on_select = true` (the default) the selection is copied
when you release the button, once per gesture. Otherwise press <kbd>c</kbd> in
window mode (`copy_selection`) or use "Copy selection" in the context menu. A
copy flashes the copied text briefly (`appearance.selection.flash`).

### The clipboard

A copy goes to your terminal's clipboard with **OSC 52**, and on a local
client also through the system clipboard tool. Programs inside panes can set
the clipboard with OSC 52 too; `appearance.selection.osc52_write` decides
whether they may:

| Value | Programs may set the clipboard |
|---|---|
| `focused` (default) | From the focused pane; the dock says so when the text holds a line break or control character. Other panes wait for you to allow it |
| `ask` | Only after you allow it, from any pane |
| `on` | Always |
| `off` | Never |

Whatever the mode, a pane keeps its own copy, so the program that set it can
read it back. Some terminals cut long OSC 52 writes; multi copy mode warns
above 100 KB.

### Pasting, and pasting images

| Keys | Pastes |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>v</kbd>, <kbd>Super</kbd>+<kbd>v</kbd> (terminal mode) | The host clipboard (text, or an image as a path when it holds only an image) |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>V</kbd> | The clipboard **image**, always, as a file path |
| Context menu "Paste" | The clipboard |
| <kbd>Ctrl</kbd>+<kbd>v</kbd> | Nothing: it goes to the program (vim's visual block, Claude Code's own image paste) |

`paste_image` (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>V</kbd>) reads the image with
your system's clipboard tool (`wl-paste`, `xclip`, `osascript` or `pngpaste`,
PowerShell), saves it to a private file on the machine where the pane runs,
and pastes that file's path. Coding agents such as Claude Code and Codex read
an image from a path in the prompt, so this works even for a pane on another
machine. Files are PNG, JPEG, GIF, WebP, BMP or TIFF up to 8 MB and are
deleted after an hour. It does not work from the browser client, from
`tuios ssh`, or inside ssh without X forwarding.

## Images

tuios passes images from programs in panes through to your terminal, clipped
to the pane like text. What you see depends on what your **host terminal**
supports, because every client draws images for its own terminal.

| Program writes | Host has kitty graphics (kitty, Ghostty, WezTerm) | Host has sixel only (foot, xterm, mlterm, Konsole, Windows Terminal) | Host has neither |
|---|---|---|---|
| Kitty graphics (`kitten icat`, `mpv --vo=kitty`, `chafa`, `timg`, `yazi`) | Drawn | Not drawn | Not drawn |
| Kitty Unicode placeholders | Drawn where the terminal is known to support them | Not drawn | Not drawn |
| Sixel (`img2sixel`, `lsix`, `chafa`) | Drawn, converted to a kitty image | Drawn as sixel | A dim box reading `image` |

### Kitty graphics

Kitty graphics are the best supported path. tuios intercepts each image,
works out where the program's placement lands on your screen from the pane's
position and scroll, and re-emits it there. Image ids are reused across
frames and output is batched with the render cycle inside synchronized output
(mode 2026), so video plays without flicker: `mpv --vo=kitty` works in both
its shared-memory and base64 modes. A program's animation frame edits
(`a=f`) are forwarded as rectangles rather than whole bitmaps.

- **Overlap.** A window drawn over part of an image crops the image to what is
  still clear, in up to several rectangles, instead of hiding it.
- **Resizes and full-screen overlays** hide placed images while they last,
  because the host paints images over the finished frame.
- **Unicode placeholders** (the image lives in special text cells) scroll and
  clip exactly like text. tuios asks the terminal who it is (XTVERSION) and
  keeps placeholder cells only for terminals known to draw them;
  `appearance.kitty_placeholders` (`auto`, `on`, `off`) or
  `TUIOS_KITTY_PLACEHOLDERS=1`/`0` overrides that. They need a truecolor host
  and do not show in `tuios-web`.
- **File transmission** (`t=f`, `t=t`, `t=s`): a path a program sends is
  checked before anything reads it (absolute, regular file, your own, `t=s`
  inside `/dev/shm`), and a program on another machine is told to send bytes
  instead.

### Sixel

A sixel image has no id and no way to be cropped, so tuios does what a sixel
terminal does internally: it decodes the image and marks every cell it covers.
On each frame it finds the marked cells that are actually visible and sends
just that part, as sixel on a sixel host or as a kitty image on a kitty host.
The picture therefore scrolls into the scrollback with its cells and
disappears when text is written over it or it is cleared.

A pane is told it can draw sixel only when its picture will really be shown,
so tools such as chafa, timg and yazi fall back to text on a plain terminal.
`TUIOS_SIXEL_GRAPHICS=1`/`0` overrides detection. A pane holds at most 16 MiB
and 4096 sixel images; copies, searches, `capture-pane` and hints see blanks
where image cells are.

::: note
The kitty text sizing protocol (OSC 66) passes through but is experimental,
with known issues in the scrollback and when windows move.
:::

## The mouse

Every mouse interaction, by where it lands. "Window mode" and "terminal mode"
matter only where noted.

### On a pane

| Gesture | Action |
|---|---|
| Left click | Focus the pane and raise it |
| Double-click (window mode) | Focus and enter terminal mode (`click_to_type = "double"`; `single` makes one click enough, `off` never switches) |
| Left drag on the content | Select text (programs that track the mouse get the event instead) |
| Double / triple click (terminal mode) | Select a word / a line |
| Left drag on the title bar | Move a floating window; drop a tiled pane on another to swap them |
| <kbd>Alt</kbd>+left drag | Move the pane, even over a mouse-tracking program (`appearance.alt_drag`, default `true`) |
| <kbd>Ctrl</kbd>+left drag on the content | Move the pane |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+click | Add the pane to the multifocus set, or remove it |
| Left drag on a border or a divider | Resize: a floating window's edge, or a tiled divider |
| Right drag (window mode) | Resize the window from the nearest corner |
| Right click (window mode) | The pane's context menu |
| Right click with a selection (terminal mode) | The selection menu |
| <kbd>Ctrl</kbd>+right or <kbd>Shift</kbd>+right click | The pane's context menu, in any mode, over any program |
| <kbd>Shift</kbd>+left click on a link | Open the link (`appearance.links`: `off`, `marked`, `all`) |
| Wheel | Scroll the scrollback, or pass the wheel to a mouse-tracking program |
| <kbd>Alt</kbd>/<kbd>Shift</kbd>+wheel (scrolling layout) | Scroll the column strip |
| Click or drag the scrollbar | Jump or scroll through the history |
| Click a title-bar control | Close, minimize or zoom |
| Hover (with `focus_follows_mouse = true`) | Focus the pane under the pointer |

A zoomed pane is focused by a click but cannot be dragged or resized.

### On the dock

| Gesture | Action |
|---|---|
| Click a workspace pill | Switch to that workspace |
| Drag a workspace pill | Reorder the strip |
| Click `+` | Open the next empty workspace |
| Click a minimized entry | Restore that window |
| Click the overflow marker | Open the aggregate view |
| Click a message | Jump to the pane it came from; its right end dismisses it |
| Click a custom component | Run its `on-click` command |
| Click Leave / Close | Detach / close the session (with confirmation) |
| Right click | The dock's menu, or the menu of the item under the pointer |

### On the rail and elsewhere

| Gesture | Action |
|---|---|
| Click a rail row | Switch session, focus a pane, open a folder or file |
| Right click a rail row | That row's menu (session, machine, file) |
| Drag a session row | Reorder the sessions |
| Drag the rail's inner edge | Resize the rail; dragging a folded rail out expands it |
| Wheel over the rail | Scroll the section under the pointer |
| Click the picture-in-picture view | Jump to the pane it shows |
| Right click the empty desktop (window mode) | The desktop menu |
| Click a row in an overlay | Select or run it; a click outside dismisses the overlay |
| Drag an overlay's title bar, or right drag it | Move the panel |

## Screenshots

tuios renders screenshots from a pane's own cells, so colours, styles and
links are exact and no pixels are scraped from your terminal. The files are
written by the daemon, so a screenshot works on a detached session.

### Capture mode

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>C</kbd> enters **capture mode**, which owns
the keyboard and mouse until it ends. Hovering lifts the window under the
pointer so you can see what a click would capture.

| Input | Captures |
|---|---|
| Click a window | That window |
| Drag | A region of the screen |
| <kbd>f</kbd> | The full screen |
| <kbd>Enter</kbd> / <kbd>Space</kbd> | The highlighted window |
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> (also arrows, <kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd>) | Move the highlight to the next / previous window |
| <kbd>Esc</kbd>, <kbd>q</kbd>, <kbd>Ctrl</kbd>+<kbd>c</kbd> | Cancel |

Over an open panel (the palette, settings, a menu, the Inbox) capture mode
keeps the panel in the picture; then <kbd>Enter</kbd>, <kbd>f</kbd> or a click
takes the whole screen and a drag takes a region.

After a capture the **preview panel** opens (`screenshot.preview`, default
`true`): <kbd>Enter</kbd> done, <kbd>c</kbd> copy, <kbd>o</kbd> open,
<kbd>r</kbd> retake, <kbd>Esc</kbd> discard. The palette has "Screenshot this
window", "Screenshot a region" and "Screenshot the screen", and the pane's
context menu has "Screenshot this window".

### From a shell

```sh
tuios screenshot                                   # focused window, PNG in screenshot.directory
tuios screenshot -s work -w build                  # a named window; detached is fine
tuios screenshot --scrollback --lines 200          # with history above the screen
tuios screenshot --format svg --out demo.svg
tuios screenshot --theme catppuccin_mocha          # re-render in another palette
tuios run-command -s work Screenshot
```

Formats are `png`, `svg`, `ansi`, `html` and `txt`. PNG and SVG carry a frame
(padding, a background wash from your theme, rounded corners, a shadow and a
title bar with window controls); `ansi` and `txt` are the bare stream.

```toml
[screenshot]
format = "png"              # png, svg, ansi, html, txt
directory = "~/Pictures/tuios"
frame = "window"            # window, plain, none
padding = 48                # px, 0-128
radius = 10                 # px, 0-32
shadow = true
controls = "auto"           # auto (macOS lights), macos, glyphs, none
scale = 2                   # PNG raster scale, 1-4
copy = true                 # try to put the image on the clipboard
```

::: note
With no theme set, basic and indexed colours fall back to the xterm defaults,
because only your terminal knows its own palette. The result says so. Use
`--theme` to render in a named palette.
:::

## The performance model

tuios is built to cost nothing while nothing happens. Upstream measures this
in <https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/perf.md>.

- **Event-driven rendering.** Each pane's PTY reader signals the UI through a
  channel when output arrives. There is no fixed-rate redraw of terminal
  content; a frame is drawn only when output, input or an animation changed
  something, and an unchanged frame is skipped.
- **An idle maintenance tick** runs at a low rate (10 per second) and skips its
  scans behind a cheap check, so idle shells cost a few hundred nanoseconds per
  tick and send nothing to your terminal. The measured target is zero
  timer-driven renders and idle CPU under about 0.5% with the rail on.
- **Dock components arm no timer** unless one is configured to poll. The clock
  redraws once a second only when its format shows seconds.
- **Culling and caching.** Off-screen and minimized panes are not rendered;
  unchanged windows reuse their cached layer; styles come from an LRU cache;
  buffers are pooled. Unfocused panes use the emulator's fast render unless
  `dim_unfocused` needs every cell.
- **Synchronized output.** Frames and image data go out inside mode 2026, so
  your terminal never shows half a frame.

```toml
[appearance]
max_fps = 60     # 0 means 60; otherwise 10 to 120
motion = "basic" # none, basic or full: how much animates (default full)
```

The daemon and the client split the work: the daemon parses every pane's
output all the time (so nothing is lost while detached), and the client only
draws what is on screen.

## Glossary

| Term | Meaning |
|---|---|
| Aggregate view | The "All windows" list of every window on every workspace of a session. |
| Client | A `tuios` process that draws a session in your terminal and sends your input to the daemon. Several clients can attach to one session. |
| Chrome | Everything tuios draws besides pane content: dock, rail, title bars, borders, scrollbar. |
| Copy mode | The vim-style cursor mode over a pane's scrollback, entered with <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>[</kbd>. |
| Daemon | The background `tuios` process that owns every PTY and session. |
| Dock | The one-row bar (top by default) with the mode pill, workspace strip, minimized windows, messages and session controls. |
| Floating window | A window with its own position and size, outside the tiling layout. |
| Focus | The one window per workspace that receives keys and window actions. |
| Leader key | The key that starts a prefix chord, <kbd>Ctrl</kbd>+<kbd>b</kbd> by default (`keybindings.leader_key`). |
| Master-stack | The layout mode with master panes on one side and a stack beside them. |
| Mode pill | The leftmost dock cell, which shows the input mode and tiling state. |
| Most recently active session | The session a `tuios` command targets when `-s` is omitted. |
| Multifocus | A set of panes that all receive your typing in terminal mode. |
| Pane | The terminal content area of a window. Each window has exactly one. |
| Picture in picture | A small live copy of one pane pinned in a screen corner (<kbd>p</kbd>). |
| Popup | A floating pane for one command that closes when the command exits. |
| Prefix mode | The one-key state after the leader, shown by the `PREFIX` badge and the which-key panel. |
| Preselection | Choosing the side of the focused pane where the next window will open. |
| Rail | The sidebar of sessions, terminals, files, git and agents. Also called the sidebar. |
| Ratio | Where a BSP split's divider sits, 0.0 to 1.0; 0.5 by default. |
| Scratch terminal | A box of panes over the current workspace, shown and hidden with <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>g</kbd>, living on workspaces 1000 and up. |
| Scrolling layout | The niri-style layout of columns on a strip wider than the screen. |
| Session | A named set of nine workspaces and their windows inside the daemon. |
| Split | A BSP node dividing its area between two children: vertical (side by side) or horizontal (stacked). |
| Terminal mode | The mode in which keys go to the program in the focused pane. |
| Tiling scheme | The rule BSP uses to pick the axis of an automatic split: spiral, longest_side, alternate or smart_split. |
| Title | The label a program sets for its window; a window's name overrides it. |
| Trail | The ` workspace:windows ` count printed after the mode pill. |
| Which-key | The panel listing the keys available after the leader, shown after 500 ms. |
| Window | One terminal with its pane, border, title bar and UUID. |
| Window management mode | The mode in which keys drive tuios rather than the shell. |
| Workspace | One of nine numbered screens in a session. |
| Zoom | Showing one pane over the layout at 95% of the screen (by default) without changing the layout.  |
