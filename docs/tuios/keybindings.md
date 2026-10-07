---
title: "TUIOS: Keybindings and the Command Palette"
template: tuios-manual
manual: tuios
chapter: 3
summary: Every default key in tuios v0.8.5, how modes, the leader and chords work, how to rebind or free a key, and how to drive the command palette, hints and copy mode.
tags:
  - tuios
  - keybindings
  - config
  - palette
  - cli
---

tuios is driven from the keyboard. Every key it reacts to belongs to an
*action* (such as `new_window` or `prefix_split_vertical`), every action lives
in one of the 23 `[keybindings.*]` sections of `config.toml`, and every one of
them can be rebound, unbound or handed back to the program in the pane. This
chapter explains the model (modes, the leader, chords, scopes and precedence),
lists every default binding section by section, shows how to change them, and
then covers the surfaces that sit on top of the keymap: command keys, the
command palette, hints, copy mode, the rail and the Inbox.

::: note
All tables in this chapter show the **defaults** of v0.8.5, with the default
leader <kbd>Ctrl</kbd>+<kbd>b</kbd>. Your own config can differ. To see what
*your* tuios does, ask the binary: `tuios keybinds list`, `tuios keybinds
doctor` and `tuios keybinds explain <key>` (see
[Inspecting your bindings](#inspecting-your-bindings)). The capture used while
writing this chapter came from a machine whose `config.toml` moves the leader
to <kbd>Ctrl</kbd>+<kbd>a</kbd> and the palette to
<kbd>Ctrl</kbd>+<kbd>Space</kbd>, so its `tuios keybinds list` shows `ctrl+a a`
for the launcher and `ctrl+space` for the palette. Those are overrides, not
defaults.
:::

## How keys reach tuios

### Two modes

tuios has two input modes, and which one you are in decides who sees a key
first.

| Mode | Who gets an ordinary key | How you enter it | How you leave it |
|---|---|---|---|
| Window mode (window management) | tuios. Letters such as <kbd>n</kbd>, <kbd>x</kbd> and <kbd>h</kbd> are commands | <kbd>Esc</kbd> is `enter_window_mode`; from terminal mode, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Esc</kbd>, or <kbd>Opt</kbd>+<kbd>Esc</kbd> (macOS) / <kbd>Alt</kbd>+<kbd>Esc</kbd> (others) | <kbd>i</kbd> or <kbd>Enter</kbd> (`enter_terminal_mode`) |
| Terminal mode | The program in the focused pane. Only the leader, the `terminal_mode` and `global` bindings and a few reserved chords are taken | <kbd>i</kbd> or <kbd>Enter</kbd> in window mode | `terminal_exit_mode` or the prefix chord <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Esc</kbd> |

Window mode is where you arrange things: move focus with <kbd>h</kbd>
<kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd>, split with <kbd>&#45;</kbd> and
<kbd>&#124;</kbd>, close with <kbd>x</kbd>. Terminal mode is where you type into a
shell, an editor or an agent. The dock's mode indicator shows which mode you
are in.

::: default
tuios starts in window mode. `startup.start_in_terminal_mode = true` starts it
focused in terminal mode when a window is present (default `false`).
:::

::: example
**Example: open a shell, type into it, and come back**

1. In window mode press <kbd>n</kbd>. A new window opens.
2. Press <kbd>i</kbd> (or <kbd>Enter</kbd>). You are in terminal mode; type
   `ls` and <kbd>Enter</kbd>, which go to the shell.
3. Press <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Esc</kbd>. You are back in window
   mode, and <kbd>x</kbd> now closes the window instead of typing an `x`.
:::

### The leader (prefix) key

The leader, <kbd>Ctrl</kbd>+<kbd>b</kbd> by default, is the tmux-style prefix.
It works in **both** modes. Press it, release it, then press a second key: the
pair is a *prefix chord*, written in this manual as
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>c</kbd> (a space separates the steps). The
second key is looked up in `[keybindings.prefix_mode]`.

The leader is not an entry in a table. It is the scalar
`keybindings.leader_key`:

```toml
[keybindings]
leader_key = "ctrl+a"   # default: "ctrl+b"
```

Moving the leader moves every prefix chord with it: after the change above,
<kbd>Ctrl</kbd>+<kbd>a</kbd> <kbd>c</kbd> creates a window, and the which-key
panel, the help overlay and `tuios keybinds list` all spell chords with
`ctrl+a`.

Rules that follow from the leader being read before everything else:

- **Leader twice sends the leader.** In terminal mode, pressing the leader a
  second time while the prefix is armed forwards the leader itself to the pane
  (tmux's `prefix prefix`). The pane gets it encoded as it expects: CSI u for a
  pane using the Kitty keyboard protocol, legacy bytes otherwise. A leader
  with no legacy encoding is dropped.
- **An unbound key after the leader goes to the pane.** In terminal mode, a key
  pressed after the leader that `prefix_mode` does not bind is typed into the
  focused pane, so a stray chord never eats a letter.
- **A command key can never take the leader.** An entry in
  `[[keybindings.command]]` on the leader key never runs, and `tuios keybinds
  doctor` reports it as dead.
- **`tuios keybinds free` cannot take the leader.** It is moved, not unbound.

::: example
**Example: send a literal Ctrl+B to the program in the pane**

In terminal mode, with the default leader, press
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Ctrl</kbd>+<kbd>b</kbd>. `less` and `vim` then
see one <kbd>Ctrl</kbd>+<kbd>b</kbd> and page up.
:::

### Sub-prefixes (multi-step chords)

Six keys after the leader open a further menu instead of running an action.
Each sub-prefix has its own section:

| Chord | Opens | Section | Action that opens it |
|---|---|---|---|
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> | Window prefix | `[keybindings.window_prefix]` | `prefix_window` |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> | Minimize prefix | `[keybindings.minimize_prefix]` | `prefix_minimize` |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> | Workspace prefix | `[keybindings.workspace_prefix]` | `prefix_workspace` |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> | Layout prefix | `[keybindings.layout_prefix]` | `prefix_layout` |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> | Tape prefix | `[keybindings.tape_prefix]` | `prefix_tape` |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> | Debug prefix | `[keybindings.debug_prefix]` | `prefix_debug` |

A sub-prefix chord has three steps, for example
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>2</kbd> (switch to workspace 2)
or <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>s</kbd> (save the layout).
<kbd>Esc</kbd> cancels any sub-prefix.

The key that opens a sub-prefix is an ordinary `prefix_mode` binding
(`prefix_layout = ["y"]` moves the layout prefix to <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>y</kbd>).

### Prefix repeat

After a prefix command worth pressing again, the prefix stays armed for a
short window so you can repeat the second key without pressing the leader.
This is tmux's `repeat-time` (tmux marks such bindings `-r`).

The repeatable actions are the directional and stepping ones: focusing a pane
in a direction, next and previous window, next and previous workspace,
resizing, the scrolling layout's column moves and width cycle, and the two
agent walkers `prefix_next_attention` (<kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>o</kbd>) and `prefix_next_finished` (<kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>O</kbd>). Nothing destructive repeats, and nothing that opens a panel.

```toml
[appearance]
prefix_repeat_time = 500   # milliseconds; 0 turns repeat off; range 0 to 5000
```

::: example
**Example: walk three panes with one leader press**

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Left</kbd> <kbd>Left</kbd> <kbd>Left</kbd>
moves focus three panes to the left, as long as each arrow follows the
previous one within 500 ms.
:::

### Which-key

After you press the leader, a *which-key* panel appears if you do not press a
second key straight away (the delay is 500 ms). It lists the keys after the
leader in sections: **Windows**, **Panes**, **Sessions**, **Modes**,
**Menus**, **Tools**, and **Agents** (shown only once an agent has run in the
session). A key marked with `+` opens a further menu (the sub-prefixes). The
panel lays itself out in as many columns as the screen holds; on a screen too
narrow for every column, descriptions are cut before any key is left out.
Pressing a sub-prefix key shows that sub-prefix's own panel.

| Option | Type | Default | Meaning |
|---|---|---|---|
| `appearance.whichkey_enabled` | bool | `true` | Show the panel after the leader |
| `appearance.whichkey_position` | string | `bottom-right` | One of `bottom-right`, `bottom-left`, `top-right`, `top-left`, `center` |

```sh
tuios set-config appearance.whichkey_position center
```

What the leader's panel lists, in v0.8.5 with the default leader:

| Section | Lines |
|---|---|
| Windows | `c` create, `x` close, `r` rename, `n/p` next/prev, `0-9` jump, `z` zoom |
| Panes | arrows focus, `space` tiling, `-` split horizontal, <kbd>&#124;</kbd> or <kbd>&#92;</kbd> split vertical|` or `\` split vertical, `R` rotate, `=` equalize, `F` hints |
| Sessions | `(/)` prev/next session, `S` sessions, `W` workspaces, `X` close session, `g` scratch, then `d` detach and `q` quit menu (daemon session) or `q` quit (standalone) |
| Modes | `Esc` window mode (standalone: `d/Esc`), `[`/`V` copy mode or paste image, `s` scrollback browser, `b` toggle sidebar, `e` focus sidebar, `f` search files |
| Menus | `w+` Workspace, `m+` Minimize, `t+` Window, `L+` Layout, `T+` Tape, `D+` Debug |
| Tools | `P` palette, `a` launcher, `,` settings, `k` keybindings, `C` screenshot, `j` newest message, `?` help |
| Agents | `i` Inbox, `o` oldest waiting, `M` Inbox mail, `O` newest done, `v` review |

::: note
The which-key lines are fixed labels for the default layout. After rebinding,
trust `tuios keybinds list`, the help overlay and the keybind manager, which
read your config.
:::

### Holding window mode

`hold_window_mode` (in `[keybindings.mode_control]`, unbound by default) puts
tuios in window mode only while a key is physically held, and hands the
previous mode back on release:

```toml
[keybindings.mode_control]
hold_window_mode = ["f13"]
```

It needs a terminal that speaks the Kitty keyboard protocol (Ghostty, kitty,
WezTerm, foot, Alacritty; not Terminal.app), because nothing else reports key
release. Naming a modifier key (`leftalt`, `rightalt`, `leftctrl`,
`leftsuper`) also makes every keystroke in the session arrive as an escape
code; an ordinary key such as `f13` to `f63`, `scrolllock` or a spare letter
avoids that.

## Key notation in config.toml

Every binding is a TOML array of strings. Each string is one key, optionally
with modifiers joined by `+`.

```toml
[keybindings.layout]
split_vertical = ["|", "\\"]          # two keys, one action
swap_left      = ["H", "ctrl+left"]   # a letter and a chord
```

### Modifiers

| Write | tuios reads it as | Where it is valid |
|---|---|---|
| `ctrl+`, `control+` | `ctrl+` | everywhere |
| `alt+` | `alt+` | everywhere |
| `opt+`, `option+` | `alt+` | macOS only |
| `shift+` | `shift+` | everywhere |
| `super+`, `cmd+`, `command+` | `super+` | everywhere (needs a terminal that sends Super) |

- **Order does not matter.** `shift+ctrl+x` is `ctrl+shift+x`. tuios puts
  modifiers in one canonical order (ctrl, alt, shift, super) before comparing.
  This applies to `leader_key`, every table, and the arguments of `tuios
  keybinds explain`, `free` and `unbind`.
- **A repeated modifier is dropped**, so `ctrl+ctrl+x` is `ctrl+x`.
- **`super+` chords** need a terminal that forwards them. Most macOS terminals
  keep Command for their menus; Ghostty and kitty send an unbound Command chord
  under the Kitty keyboard protocol.
- On macOS, the validator suggests `opt+` over a hand-written `alt+` (an
  advisory warning, never for the shipped defaults).

```sh
tuios keybinds explain opt+f12
```

```text
opt+f12 (tuios reads it as alt+f12)
  free: nothing in tuios claims it, and the pane receives it
```

### Base keys

| Kind | Spelling | Notes |
|---|---|---|
| A single character | `a`, `M`, `1`, `-`, <kbd>&#124;</kbd> or <kbd>&#92;</kbd> split vertical|`-`, <kbd>&#124;</kbd>, `é` | Case is kept: `m` and `M` are different keys. Any single rune is valid, including AZERTY letters |
| Shifted digits and symbols | `shift+1` and `!`, `shift+[` and `{` | Terminals report these either way, so the defaults list both (see `restore_minimized_1 = ["shift+1", "!"]`) |
| Named keys | `enter` (`return`), `esc` (`escape`), `tab`, `space`, `backspace`, `delete`, `insert`, `up`, `down`, `left`, `right`, `home`, `end`, `pgup` (`pageup`), `pgdown` (`pagedown`) | Lowercase |
| Function keys | `f1` to `f63` | F13 and above need a terminal that sends them; above F24 needs the Kitty keyboard protocol |
| Kitty-only keys | `capslock`, `scrolllock`, `numlock`, `printscreen`, `pause`, `menu` | Reported only under the Kitty keyboard protocol |
| Single modifier keys | `leftalt`, `rightalt`, `leftctrl`, `rightctrl`, `leftshift`, `rightshift`, `leftsuper`, `rightsuper`, `leftmeta`, `rightmeta`, `lefthyper`, `righthyper` | Meant for held-key bindings such as `hold_window_mode` |
| The plus key | `ctrl++` | A trailing `++` is the plus key itself |

A compound key is compared lowercased, so `ctrl+B` is `ctrl+b`. A key the
validator cannot read (for example `ctrl+` or `ctrl+foo`) is reported as an
error naming it (`unknown special key: foo`), and `tuios keybinds doctor`
lists it under `key_problems`.

::: warning
Some chords are the same byte on most terminals: <kbd>Ctrl</kbd>+<kbd>i</kbd>
is <kbd>Tab</kbd>, <kbd>Ctrl</kbd>+<kbd>m</kbd> is <kbd>Enter</kbd>, and
<kbd>Ctrl</kbd>+<kbd>&#91;</kbd> is <kbd>Esc</kbd>, unless the terminal
disambiguates them (the Kitty keyboard protocol does). `tuios keybinds doctor`
reports this under OBSERVED for the terminal you run it in.
:::

### Platform-dependent defaults

A few defaults differ by platform. On macOS they are written with `opt+`; on
Linux and other systems with `alt+`:

| Action | macOS default | Linux and others |
|---|---|---|
| `switch_workspace_1` to `_9` | `opt+1` to `opt+9` | `alt+1` to `alt+9` |
| `move_and_follow_1` to `_9` | `opt+shift+1` to `opt+shift+9` | `alt+shift+1` to `alt+shift+9` |
| `preselect_left/right/up/down` | `opt+h/l/k/j` | `alt+h/l/k/j` |
| `terminal_next_window` | `opt+tab`, `alt+n` | `alt+n` |
| `terminal_prev_window` | `opt+shift+tab`, `alt+p` | `alt+p` |
| `terminal_exit_mode` | `opt+esc` | `alt+esc` |

On macOS, `opt+1` also matches the `¡` a composing Option key produces, so
<kbd>Opt</kbd> digits work with no terminal setup (on a US layout).

### macOS Option and Command

Option is a compose key on macOS unless the terminal is told otherwise, so an
Option chord usually arrives as a character. tuios reads most composed
characters back into the chord they stand for, but two kinds cannot be
recovered:

- **Dead keys.** Option with <kbd>e</kbd>, <kbd>i</kbd>, <kbd>n</kbd>,
  <kbd>u</kbd> and backtick emit nothing until a second key ends the
  composition. `alt+n` (next window in terminal mode) takes two presses on a
  stock macOS terminal.
- **Rewritten chords.** Option+Left and Option+Right are sent as the readline
  word motions `ESC b` and `ESC f`; nothing says an arrow was pressed.

Command chords never reach a program inside a terminal; macOS routes them to
the menu bar. The fix is the terminal's Option-as-Alt setting:

| Terminal | Setting |
|---|---|
| Ghostty | `macos-option-as-alt = true` in `~/.config/ghostty/config` |
| Terminal.app | Settings, Profiles, Keyboard, tick "Use Option as Meta Key" |
| iTerm2 | Settings, Profiles, Keys, set Left Option key to "Esc+" |
| kitty | `macos_option_as_alt yes` in `~/.config/kitty/kitty.conf` |
| WezTerm | `send_composed_key_when_left_alt_is_pressed = false` |
| Alacritty | `option_as_alt = "Both"` under `[window]` |
| VS Code | turn on `terminal.integrated.macOptionIsMeta` |

Ghostty also needs its own arrow rewrites removed:

```text
keybind = alt+left=unbind
keybind = alt+right=unbind
```

tuios says this on screen the first time it sees a chord that did not arrive
as it was meant to. Without any change, the prefix still works: every
navigation command has a prefix binding, and <kbd>Ctrl</kbd>+<kbd>b</kbd> is an
ordinary control chord no terminal interferes with.

### Other keyboard layouts

On a layout for a non-Latin script (Cyrillic, Greek, Hebrew, Arabic), a key
with no binding on its typed character runs the binding of the US key at the
same position: on a Ukrainian layout, <kbd>Ctrl</kbd>+<kbd>b</kbd> then the key
that types `ш` opens the Inbox (US <kbd>i</kbd>). A binding on `ш` itself wins.
Latin layouts (AZERTY, QWERTZ, Dvorak) use the letter on the key, so Dvorak's
<kbd>Ctrl</kbd> with the key that types `b` is the leader. This needs a
terminal that sends the US key through the Kitty keyboard protocol (Ghostty,
kitty, WezTerm, foot).

::: warning
In window mode tuios asks the terminal to send every key as a code. If tuios
dies without restoring it (`kill -9`, a dropped ssh connection), the shell
shows codes such as `[97u` as you type. Reset the terminal with:

```sh
printf '\033[=0;1u'
```
:::

## Scopes, conflicts and precedence

### Scopes

A *scope* is one keyboard context: a set of keys looked up together. Two
actions on one key only collide when they share a scope. The 23 sections map
onto 17 scopes:

| Scope (id) | Sections | Entered by | Effect on the pane's program |
|---|---|---|---|
| Global (`global`) | `global` | always, in both modes and on the rail | Takes the key from the pane |
| Window mode (`window`) | `window_management`, `workspaces`, `layout`, `mode_control`, `system`, `navigation`, `restore_minimized` | being in window mode | None: tuios owns the keyboard |
| Terminal mode (`terminal`) | `terminal_mode` | being in terminal mode | Takes the key from the pane |
| Sidebar (`sidebar`) | `sidebar` | the rail has focus | None |
| Sidebar files (`sidebar.files`) | `sidebar_files` | rail cursor on a file row | None |
| Sidebar agents (`sidebar.agents`) | `sidebar_agents` | rail cursor on an agent row | None |
| Inbox (`inbox`) | `inbox` | the Inbox is open | None |
| Inbox prompt (`inbox.peek`) | `inbox_peek` | a prompt is open over the Inbox | None |
| Mailbox (`mail`) | `mail` | the mailbox is open | None |
| Prefix (`prefix`) | `prefix_mode` | the leader | Costs only the leader |
| Window prefix (`prefix.window`) | `window_prefix` | leader, <kbd>t</kbd> | Chorded |
| Minimize prefix (`prefix.minimize`) | `minimize_prefix` | leader, <kbd>m</kbd> | Chorded |
| Workspace prefix (`prefix.workspace`) | `workspace_prefix` | leader, <kbd>w</kbd> | Chorded |
| Debug prefix (`prefix.debug`) | `debug_prefix` | leader, <kbd>D</kbd> | Chorded |
| Tape prefix (`prefix.tape`) | `tape_prefix` | leader, <kbd>T</kbd> | Chorded |
| Layout prefix (`prefix.layout`) | `layout_prefix` | leader, <kbd>L</kbd> | Chorded |
| Script playback (`script`) | `script` | a `.tape` is playing | None |

Because the scopes are separate, the same key can mean different things in
different places without a conflict: <kbd>d</kbd> dismisses in the Inbox list
and denies in the Inbox prompt; <kbd>r</kbd> renames on a rail row, renames a
file on a file row, and replies on an agent row; <kbd>Ctrl</kbd>+<kbd>p</kbd>
is the palette globally and pauses a tape during playback.

### Lookup order

**In window mode**, a key is tried in this order:

1. the leader (starts a prefix chord);
2. the window-mode scope (the seven flattened sections);
3. the `terminal_mode` section (so <kbd>Alt</kbd>+<kbd>Left</kbd> focuses left
   in window mode too);
4. the `global` section;
5. <kbd>Ctrl</kbd>+<kbd>c</kbd>, which asks to quit.

**In terminal mode**:

1. the leader (or, if the prefix is already armed, the leader goes to the pane);
2. an armed sub-prefix or the prefix itself;
3. the `terminal_mode` section;
4. workspace and session navigation from the window-mode scope
   (`switch_workspace_*`, `move_and_follow_*`, `next_workspace`,
   `prev_workspace`, `next_session`, `prev_session`), but only for a key with
   a real <kbd>Alt</kbd> or <kbd>Ctrl</kbd> modifier or a macOS Option glyph,
   so a bare letter never stops reaching the shell;
5. the `global` section;
6. host paste (`terminal_paste_host`);
7. everything else is forwarded to the pane.

### Who wins a contested key

Within the window-mode scope, the seven sections are merged into one map, so
a key bound in two of them is a real collision even though the TOML shows it
in two tables. The rules:

- **Across sections, the later section wins.** The merge order is
  `window_management`, `workspaces`, `layout`, `mode_control`, `system`,
  `navigation`, `restore_minimized`. A key in `layout` beats the same key in
  `window_management`.
- **Inside one section, the first action in alphabetical order wins.**
- **The same action on the same key twice** is a duplicate, not a contest.
- **Command keys never win.** A `[[keybindings.command]]` entry on a key
  already taken is dead; two command entries on one key run the first one in
  the file.

The losing binding is *shadowed*: it is still in the file, but pressing the key
runs the other action. The validator warns about each one on load, naming the
winner and how to fix it:

```toml
[keybindings.system]
toggle_spotlight = ["x"]   # x is also close_window in window_management
```

`system` is merged after `window_management`, so <kbd>x</kbd> now toggles the
spotlight and `close_window` keeps only <kbd>w</kbd>. The warning has this
shape:

```text
x runs <winner>. These never run: <losers>. Run `tuios keybinds unbind <action> x` to take the key off one of them.
```

::: example
**Example: why the corner snaps are not on 1-4 in window mode**

`snap_corner_1` to `_4` would be <kbd>1</kbd> to <kbd>4</kbd> in `layout`, and
`layout` is merged after `window_management`, so they would win those keys and
`select_window_1` to `_4` would never fire. That is why v0.8.5 ships them under
the layout prefix instead: <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd>
<kbd>1</kbd> to <kbd>4</kbd>.
:::

### Defaults that yield to you

When tuios loads your config, an action your file does not mention gets its
default back. That is how new defaults reach old configs. A handful of newer
defaults *yield* instead: if their default key is already bound to something
else in the same table, the new action is left unbound rather than stealing
your key, and `tuios keybinds doctor` says so. The yielding actions in v0.8.5
are `hints`, `toggle_scratch`, `toggle_pip`, `paste_image`, `focus_down` and
`focus_up`. Free the key and the default comes back on the next load.

For example, if your `prefix_mode` already binds <kbd>F</kbd> to another
action, `hints` gets no key until you bind it elsewhere (`hints = ["f"]`, after
moving `prefix_file_search` off <kbd>f</kbd>).

### Keys tuios takes from the pane

In terminal mode only these reach tuios rather than the program in the pane:
the leader, every `terminal_mode` and `global` binding, workspace and session
navigation chords, and the command keys in the global scope. `tuios keybinds
doctor` lists them under "KEYS TUIOS TAKES FROM THE PANE". Everything else is
forwarded, including:

- the keypad keys with Num Lock on or off (keypad <kbd>Enter</kbd> sends
  Enter), and `Begin`, the keypad centre key;
- F13 and higher (a legacy-encoding program gets them in xterm's form);
- <kbd>Insert</kbd>, <kbd>Delete</kbd>, <kbd>PgUp</kbd> and <kbd>PgDn</kbd>
  with their modifiers (<kbd>Ctrl</kbd>+<kbd>Delete</kbd> stays
  <kbd>Ctrl</kbd>+<kbd>Delete</kbd>);
- plain <kbd>Ctrl</kbd>+<kbd>v</kbd>, deliberately left for vim's visual
  block. Host paste is <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>v</kbd> or
  <kbd>Super</kbd>+<kbd>v</kbd>.

A program on the Kitty keyboard protocol gets each key with the number the
protocol gives it. Caps Lock, Num Lock and a lone modifier reach it only when
it asks for every key.

::: tip
The two default costs most people notice are the global
<kbd>Ctrl</kbd>+<kbd>p</kbd> (fish history-back, readline previous-line) and
<kbd>Alt</kbd>+<kbd>Left</kbd>/<kbd>Alt</kbd>+<kbd>Right</kbd> (word motion in
readline, fish and zsh). Hand them back with
`tuios keybinds free alt+left` or with the config shown in
[Unbinding](#unbinding). <kbd>Alt</kbd>+<kbd>Up</kbd> and
<kbd>Alt</kbd>+<kbd>Down</kbd> are unclaimed by the common shells.
:::


## Default keybindings, section by section

This is every default binding of v0.8.5, generated from the defaults in the
source, in the order the scopes are consulted. The first column is the action
name to use in `config.toml`; the second is what to press (prefix sections
show the whole chord with the default leader); the third says what it does.
Where a platform changes the default, both are shown.

Quick map of the 23 sections:

| Section | Scope | Actions bound by default |
|---|---|---|
| [`global`](#keybindings.global) | Global | 2 |
| [`window_management`](#keybindings.window_management) | Window mode | 24 |
| [`workspaces`](#keybindings.workspaces) | Window mode | 18 |
| [`layout`](#keybindings.layout) | Window mode | 26 |
| [`mode_control`](#keybindings.mode_control) | Window mode | 5 |
| [`system`](#keybindings.system) | Window mode | 1 |
| [`navigation`](#keybindings.navigation) | Window mode | 0 |
| [`restore_minimized`](#keybindings.restore_minimized) | Window mode | 9 |
| [`terminal_mode`](#keybindings.terminal_mode) | Terminal mode | 10 |
| [`prefix_mode`](#keybindings.prefix_mode) | Prefix | 59 |
| [`window_prefix`](#keybindings.window_prefix) | Window prefix | 7 |
| [`minimize_prefix`](#keybindings.minimize_prefix) | Minimize prefix | 12 |
| [`workspace_prefix`](#keybindings.workspace_prefix) | Workspace prefix | 20 |
| [`layout_prefix`](#keybindings.layout_prefix) | Layout prefix | 22 |
| [`tape_prefix`](#keybindings.tape_prefix) | Tape prefix | 5 |
| [`debug_prefix`](#keybindings.debug_prefix) | Debug prefix | 5 |
| [`sidebar`](#keybindings.sidebar) | Sidebar | 34 |
| [`sidebar_files`](#keybindings.sidebar_files) | Sidebar files | 9 |
| [`sidebar_agents`](#keybindings.sidebar_agents) | Sidebar agents | 5 |
| [`inbox`](#keybindings.inbox) | Inbox | 23 |
| [`inbox_peek`](#keybindings.inbox_peek) | Inbox prompt | 7 |
| [`mail`](#keybindings.mail) | Mailbox | 9 |
| [`script`](#keybindings.script) | Script playback | 1 |

### [keybindings.global]

Consulted in window mode, terminal mode and on the rail, so these keys act
wherever you are. Each key bound here is a key the program in the pane never
sees.

| Action | Default key(s) | What it does |
|---|---|---|
| `command_palette` | <kbd>Ctrl</kbd>+<kbd>p</kbd> | Open the command palette |
| `launcher` | <kbd>Alt</kbd>+<kbd>Space</kbd> | Open the app launcher |

```toml
# Move the palette off ctrl+p and drop the launcher's alt+space
[keybindings.global]
command_palette = ["ctrl+shift+p"]
launcher = []
```

### [keybindings.window_management]

Window mode. Creating, closing, focusing, minimizing and selecting windows,
plus session stepping. <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>n</kbd> and
<kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>p</kbd> also work from terminal mode,
because session navigation is allowed through from there.

| Action | Default key(s) | What it does |
|---|---|---|
| `close_window` | <kbd>w</kbd>, <kbd>x</kbd> | Close window |
| `copy_selection` | <kbd>c</kbd> | Copy selection to clipboard |
| `focus_sidebar` | <kbd>s</kbd> | Focus sidebar |
| `minimize_window` | <kbd>m</kbd> | Minimize window |
| `new_session` | <kbd>N</kbd> | Make a session, asking which machine |
| `new_window` | <kbd>n</kbd> | New window |
| `next_session` | <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>n</kbd> | Next session |
| `next_window` | <kbd>Tab</kbd> | Next window |
| `prev_session` | <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>p</kbd> | Previous session |
| `prev_window` | <kbd>Shift</kbd>+<kbd>Tab</kbd> | Previous window |
| `rename_window` | <kbd>r</kbd> | Rename window |
| `restore_all` | <kbd>M</kbd> | Restore all minimized |
| `select_window_1` | <kbd>1</kbd> | Select window 1 |
| `select_window_2` | <kbd>2</kbd> | Select window 2 |
| `select_window_3` | <kbd>3</kbd> | Select window 3 |
| `select_window_4` | <kbd>4</kbd> | Select window 4 |
| `select_window_5` | <kbd>5</kbd> | Select window 5 |
| `select_window_6` | <kbd>6</kbd> | Select window 6 |
| `select_window_7` | <kbd>7</kbd> | Select window 7 |
| `select_window_8` | <kbd>8</kbd> | Select window 8 |
| `select_window_9` | <kbd>9</kbd> | Select window 9 |
| `start_screensaver` | <kbd>S</kbd> | Start the screen saver now |
| `toggle_pip` | <kbd>p</kbd> | Pin or unpin the picture-in-picture view |
| `toggle_zoom` | <kbd>z</kbd> | Toggle zoom (fullscreen) |

::: note
With tiling off,
<kbd>h</kbd> and <kbd>l</kbd> snap the window to a half of the screen
(`snap_left`, `snap_right` in `layout`) while <kbd>j</kbd> and <kbd>k</kbd>
only move focus.
:::

### [keybindings.workspaces]

Window mode, and also terminal mode for any key with a real modifier. Nine
workspaces are addressable by number.

| Action | Default key(s) | What it does |
|---|---|---|
| `move_and_follow_1` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>1</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>1</kbd> (Linux, others) | Move to workspace 1 and follow |
| `move_and_follow_2` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>2</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>2</kbd> (Linux, others) | Move to workspace 2 and follow |
| `move_and_follow_3` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>3</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>3</kbd> (Linux, others) | Move to workspace 3 and follow |
| `move_and_follow_4` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>4</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>4</kbd> (Linux, others) | Move to workspace 4 and follow |
| `move_and_follow_5` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>5</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>5</kbd> (Linux, others) | Move to workspace 5 and follow |
| `move_and_follow_6` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>6</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>6</kbd> (Linux, others) | Move to workspace 6 and follow |
| `move_and_follow_7` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>7</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>7</kbd> (Linux, others) | Move to workspace 7 and follow |
| `move_and_follow_8` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>8</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>8</kbd> (Linux, others) | Move to workspace 8 and follow |
| `move_and_follow_9` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>9</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>9</kbd> (Linux, others) | Move to workspace 9 and follow |
| `switch_workspace_1` | <kbd>Opt</kbd>+<kbd>1</kbd> (macOS); <kbd>Alt</kbd>+<kbd>1</kbd> (Linux, others) | Switch to workspace 1 |
| `switch_workspace_2` | <kbd>Opt</kbd>+<kbd>2</kbd> (macOS); <kbd>Alt</kbd>+<kbd>2</kbd> (Linux, others) | Switch to workspace 2 |
| `switch_workspace_3` | <kbd>Opt</kbd>+<kbd>3</kbd> (macOS); <kbd>Alt</kbd>+<kbd>3</kbd> (Linux, others) | Switch to workspace 3 |
| `switch_workspace_4` | <kbd>Opt</kbd>+<kbd>4</kbd> (macOS); <kbd>Alt</kbd>+<kbd>4</kbd> (Linux, others) | Switch to workspace 4 |
| `switch_workspace_5` | <kbd>Opt</kbd>+<kbd>5</kbd> (macOS); <kbd>Alt</kbd>+<kbd>5</kbd> (Linux, others) | Switch to workspace 5 |
| `switch_workspace_6` | <kbd>Opt</kbd>+<kbd>6</kbd> (macOS); <kbd>Alt</kbd>+<kbd>6</kbd> (Linux, others) | Switch to workspace 6 |
| `switch_workspace_7` | <kbd>Opt</kbd>+<kbd>7</kbd> (macOS); <kbd>Alt</kbd>+<kbd>7</kbd> (Linux, others) | Switch to workspace 7 |
| `switch_workspace_8` | <kbd>Opt</kbd>+<kbd>8</kbd> (macOS); <kbd>Alt</kbd>+<kbd>8</kbd> (Linux, others) | Switch to workspace 8 |
| `switch_workspace_9` | <kbd>Opt</kbd>+<kbd>9</kbd> (macOS); <kbd>Alt</kbd>+<kbd>9</kbd> (Linux, others) | Switch to workspace 9 |

### [keybindings.layout]

Window mode. Snapping, focus by direction, swapping, resizing, BSP splits and
preselection, and the tiling toggle.

| Action | Default key(s) | What it does |
|---|---|---|
| `equalize_splits` | <kbd>&#61;</kbd> | Equalize all split ratios |
| `focus_down` | <kbd>j</kbd> | Focus the window below |
| `focus_up` | <kbd>k</kbd> | Focus the window above |
| `preselect_down` | <kbd>Opt</kbd>+<kbd>j</kbd> (macOS); <kbd>Alt</kbd>+<kbd>j</kbd> (Linux, others) | Preselect down for next window |
| `preselect_left` | <kbd>Opt</kbd>+<kbd>h</kbd> (macOS); <kbd>Alt</kbd>+<kbd>h</kbd> (Linux, others) | Preselect left for next window |
| `preselect_right` | <kbd>Opt</kbd>+<kbd>l</kbd> (macOS); <kbd>Alt</kbd>+<kbd>l</kbd> (Linux, others) | Preselect right for next window |
| `preselect_up` | <kbd>Opt</kbd>+<kbd>k</kbd> (macOS); <kbd>Alt</kbd>+<kbd>k</kbd> (Linux, others) | Preselect up for next window |
| `resize_height_grow` | <kbd>&#125;</kbd>, <kbd>Shift</kbd>+<kbd>&#93;</kbd> | Increase focused window height |
| `resize_height_grow_top` | <kbd>&#93;</kbd> | Increase focused window height from top edge |
| `resize_height_shrink` | <kbd>&#123;</kbd>, <kbd>Shift</kbd>+<kbd>&#91;</kbd> | Decrease focused window height |
| `resize_height_shrink_top` | <kbd>&#91;</kbd> | Decrease focused window height from top edge |
| `resize_master_grow` | <kbd>&#62;</kbd>, <kbd>Shift</kbd>+<kbd>&#46;</kbd> | Increase master width |
| `resize_master_grow_left` | <kbd>&#46;</kbd> | Increase master width from left edge |
| `resize_master_shrink` | <kbd>&#60;</kbd>, <kbd>Shift</kbd>+<kbd>&#44;</kbd> | Decrease master width |
| `rotate_split` | <kbd>R</kbd> | Rotate split |
| `snap_fullscreen` | <kbd>f</kbd> | Fullscreen |
| `snap_left` | <kbd>h</kbd> | Snap or focus left |
| `snap_right` | <kbd>l</kbd> | Snap or focus right |
| `split_horizontal` | <kbd>&#45;</kbd> | Split window horizontally (top/bottom) |
| `split_vertical` | <kbd>&#124;</kbd>, <kbd>&#92;</kbd> | Split window vertically (left/right) |
| `swap_down` | <kbd>J</kbd>, <kbd>Ctrl</kbd>+<kbd>Down</kbd> | Swap down |
| `swap_left` | <kbd>H</kbd>, <kbd>Ctrl</kbd>+<kbd>Left</kbd> | Swap left |
| `swap_right` | <kbd>L</kbd>, <kbd>Ctrl</kbd>+<kbd>Right</kbd> | Swap right |
| `swap_up` | <kbd>K</kbd>, <kbd>Ctrl</kbd>+<kbd>Up</kbd> | Swap up |
| `toggle_tiling` | <kbd>t</kbd> | Toggle tiling mode |
| `unsnap` | <kbd>u</kbd> | Unsnap |

The four focus directions each have a binding in three places:

| Direction | Window mode | Terminal mode | After the prefix |
|---|---|---|---|
| Left | <kbd>h</kbd> | <kbd>Alt</kbd>+<kbd>Left</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Left</kbd> |
| Down | <kbd>j</kbd> | <kbd>Alt</kbd>+<kbd>Down</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Down</kbd> |
| Up | <kbd>k</kbd> | <kbd>Alt</kbd>+<kbd>Up</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Up</kbd> |
| Right | <kbd>l</kbd> | <kbd>Alt</kbd>+<kbd>Right</kbd> | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Right</kbd> |

Focus goes to the nearest window in that direction that faces the focused one;
at the edge of a tiled layout it stays put. In the scrolling layout, left and
right move between columns and up and down move within a column. In the
master-stack layout, the width keys (<kbd>&lt;</kbd>, <kbd>&gt;</kbd>) move the
divider between master and stack when the master is left, right or centre,
and the height keys (<kbd>&#123;</kbd>, <kbd>&#125;</kbd>) when it is top or bottom. See
[Concepts](concepts.md) for the layouts themselves.

::: note
`resize_master_shrink_left` has no default: its natural key, <kbd>&#44;</kbd>, is
`open_settings`. Bind it to a free key to get it back.
:::

### [keybindings.mode_control]

Window mode. Moving between the modes, settings, help and quit.

| Action | Default key(s) | What it does |
|---|---|---|
| `enter_terminal_mode` | <kbd>i</kbd>, <kbd>Enter</kbd> | Enter terminal mode |
| `enter_window_mode` | <kbd>Esc</kbd> | Enter window management mode |
| `open_settings` | <kbd>&#44;</kbd> | Open settings |
| `quit` | <kbd>q</kbd> | Quit |
| `toggle_help` | <kbd>&#63;</kbd> | Toggle help |

`hold_window_mode` also lives here, unbound by default (see
[Holding window mode](#holding-window-mode)).

### [keybindings.system]

Window mode. One action: the spotlight, a beam that picks out part of the
screen while you present (configured under `[spotlight]`).

| Action | Default key(s) | What it does |
|---|---|---|
| `toggle_spotlight` | <kbd>b</kbd> | Toggle spotlight |

### [keybindings.navigation]

Empty by default. The arrow keys belong to whatever overlay is open, and each
overlay takes them before any binding is consulted. The section exists so a
file that names it still parses; anything you bind in it joins the window-mode
scope (merged after `system`).

### [keybindings.restore_minimized]

Window mode. Shifted digits restore a minimized window by its position in the
dock. Both the shifted name and the symbol are bound because terminals report
the key either way.

| Action | Default key(s) | What it does |
|---|---|---|
| `restore_minimized_1` | <kbd>Shift</kbd>+<kbd>1</kbd>, <kbd>&#33;</kbd> | Restore minimized window 1 (the first in the dock) |
| `restore_minimized_2` | <kbd>Shift</kbd>+<kbd>2</kbd>, <kbd>&#64;</kbd> | Restore minimized window 2 |
| `restore_minimized_3` | <kbd>Shift</kbd>+<kbd>3</kbd>, <kbd>&#35;</kbd> | Restore minimized window 3 |
| `restore_minimized_4` | <kbd>Shift</kbd>+<kbd>4</kbd>, <kbd>&#36;</kbd> | Restore minimized window 4 |
| `restore_minimized_5` | <kbd>Shift</kbd>+<kbd>5</kbd>, <kbd>&#37;</kbd> | Restore minimized window 5 |
| `restore_minimized_6` | <kbd>Shift</kbd>+<kbd>6</kbd>, <kbd>&#94;</kbd> | Restore minimized window 6 |
| `restore_minimized_7` | <kbd>Shift</kbd>+<kbd>7</kbd>, <kbd>&#38;</kbd> | Restore minimized window 7 |
| `restore_minimized_8` | <kbd>Shift</kbd>+<kbd>8</kbd>, <kbd>&#42;</kbd> | Restore minimized window 8 |
| `restore_minimized_9` | <kbd>Shift</kbd>+<kbd>9</kbd>, <kbd>&#40;</kbd> | Restore minimized window 9 |

::: note
Window mode has four rows of digit bindings: plain digits select a window,
shifted digits restore a minimized one, <kbd>Alt</kbd>/<kbd>Opt</kbd> digits
switch workspace, and <kbd>Alt</kbd>/<kbd>Opt</kbd>+<kbd>Shift</kbd> digits
move the window there.
:::

### [keybindings.terminal_mode]

Terminal mode, and consulted in window mode after the window-mode scope.
These are direct chords, no prefix, so every key here is taken from the pane.

| Action | Default key(s) | What it does |
|---|---|---|
| `terminal_exit_mode` | <kbd>Opt</kbd>+<kbd>Esc</kbd> (macOS); <kbd>Alt</kbd>+<kbd>Esc</kbd> (Linux, others) | Exit terminal mode (to window mode) |
| `terminal_focus_down` | <kbd>Alt</kbd>+<kbd>Down</kbd> | Focus the pane below |
| `terminal_focus_left` | <kbd>Alt</kbd>+<kbd>Left</kbd> | Focus the pane to the left |
| `terminal_focus_right` | <kbd>Alt</kbd>+<kbd>Right</kbd> | Focus the pane to the right |
| `terminal_focus_up` | <kbd>Alt</kbd>+<kbd>Up</kbd> | Focus the pane above |
| `terminal_next_window` | <kbd>Opt</kbd>+<kbd>Tab</kbd>, <kbd>Alt</kbd>+<kbd>n</kbd> (macOS); <kbd>Alt</kbd>+<kbd>n</kbd> (Linux, others) | Next window (terminal mode) |
| `terminal_paste_host` | <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>v</kbd>, <kbd>Super</kbd>+<kbd>v</kbd>, <kbd>Shift</kbd>+<kbd>Super</kbd>+<kbd>v</kbd> | Paste from the host clipboard |
| `terminal_prev_window` | <kbd>Opt</kbd>+<kbd>Shift</kbd>+<kbd>Tab</kbd>, <kbd>Alt</kbd>+<kbd>p</kbd> (macOS); <kbd>Alt</kbd>+<kbd>p</kbd> (Linux, others) | Previous window (terminal mode) |
| `terminal_scroll_down` | <kbd>Shift</kbd>+<kbd>Down</kbd> | Scroll back down toward live output |
| `terminal_scroll_up` | <kbd>Shift</kbd>+<kbd>Up</kbd> | Scroll into the pane's scrollback |

`terminal_scroll_up` and `terminal_scroll_down` scroll the focused pane's
scrollback without entering copy mode. `terminal_paste_host` asks the host
terminal for its clipboard (OSC 52); when the clipboard holds an image and no
text, it pastes the image as a file path instead.

### [keybindings.prefix_mode]

The leader's table: every <kbd>Ctrl</kbd>+<kbd>b</kbd> chord. It works in
both modes.

| Action | Default key(s) | What it does |
|---|---|---|
| `hints` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>F</kbd> | Label the text on the pane to copy it |
| `launcher` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>a</kbd> | Open the app launcher |
| `next_session` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#41;</kbd> | Next session |
| `paste_image` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>V</kbd> | Paste the clipboard image as a file path |
| `prefix_close_session` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>X</kbd> | Close session and panes |
| `prefix_close_window` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>x</kbd> | Close current window |
| `prefix_command_palette` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>P</kbd> | Open the command palette |
| `prefix_debug` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> | Enter debug prefix |
| `prefix_detach` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>d</kbd> | Detach, leave running |
| `prefix_equalize_splits` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#61;</kbd> | Equalize all splits |
| `prefix_exit_mode` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Esc</kbd> | Leave terminal mode |
| `prefix_explore` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>e</kbd> | Focus/leave sidebar |
| `prefix_file_search` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>f</kbd> | Search files below the focused pane's directory |
| `prefix_fullscreen` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>z</kbd> | Fullscreen current window |
| `prefix_help` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#63;</kbd> | Toggle help |
| `prefix_inbox` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>i</kbd> | Open the Inbox |
| `prefix_jump_notif` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>j</kbd> | Jump to newest message |
| `prefix_keybinds` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>k</kbd> | Open the keybind manager |
| `prefix_layout` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> | Enter layout prefix |
| `prefix_mail` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>M</kbd> | Open the Inbox on its mail |
| `prefix_minimize` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> | Enter minimize prefix |
| `prefix_new_window` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>c</kbd> | Create new window |
| `prefix_next_attention` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>o</kbd> | Jump to the oldest item needing you |
| `prefix_next_finished` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>O</kbd> | Jump to the newest unseen finished turn |
| `prefix_next_window` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>n</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Tab</kbd> | Next window |
| `prefix_prev_window` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>p</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Shift</kbd>+<kbd>Tab</kbd> | Previous window |
| `prefix_quit` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>q</kbd> | Quit (daemon: kills session) |
| `prefix_rename_window` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>r</kbd> | Rename window |
| `prefix_review` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>v</kbd> | Review the focused pane's changes |
| `prefix_rotate_split` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>R</kbd> | Rotate split |
| `prefix_screenshot` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>C</kbd> | Take a screenshot |
| `prefix_scrollback` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>s</kbd> | Open the scrollback browser |
| `prefix_select_0` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>0</kbd> | Jump to window 0 |
| `prefix_select_1` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>1</kbd> | Jump to window 1 |
| `prefix_select_2` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>2</kbd> | Jump to window 2 |
| `prefix_select_3` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>3</kbd> | Jump to window 3 |
| `prefix_select_4` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>4</kbd> | Jump to window 4 |
| `prefix_select_5` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>5</kbd> | Jump to window 5 |
| `prefix_select_6` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>6</kbd> | Jump to window 6 |
| `prefix_select_7` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>7</kbd> | Jump to window 7 |
| `prefix_select_8` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>8</kbd> | Jump to window 8 |
| `prefix_select_9` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>9</kbd> | Jump to window 9 |
| `prefix_selection` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#91;</kbd> | Enter copy/scrollback mode |
| `prefix_session_switcher` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>S</kbd> | Open the session switcher |
| `prefix_settings` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#44;</kbd> | Open settings |
| `prefix_split_horizontal` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#45;</kbd> | Split window horizontally |
| `prefix_split_vertical` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#124;</kbd>, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#92;</kbd> | Split window vertically |
| `prefix_tape` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> | Enter tape manager prefix |
| `prefix_toggle_sidebar` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>b</kbd> | Toggle the session sidebar |
| `prefix_toggle_tiling` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Space</kbd> | Toggle tiling mode |
| `prefix_window` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> | Enter window prefix |
| `prefix_workspace` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> | Enter workspace prefix |
| `prefix_workspace_switcher` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>W</kbd> | Open the workspace switcher |
| `prev_session` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#40;</kbd> | Previous session |
| `terminal_focus_down` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Down</kbd> | Focus the pane below |
| `terminal_focus_left` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Left</kbd> | Focus the pane to the left |
| `terminal_focus_right` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Right</kbd> | Focus the pane to the right |
| `terminal_focus_up` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Up</kbd> | Focus the pane above |
| `toggle_scratch` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>g</kbd> | Show or hide the scratch terminal |

Notes on a few of these:

- <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>d</kbd> detaches in a daemon session and
  leaves everything running. <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>q</kbd> opens
  the quit menu in a daemon session (its description says it kills the
  session); in a standalone session it quits.
- <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>X</kbd> closes the session and its panes.
  To close only the panes of the current workspace, bind `close_workspace`
  (no default): `close_workspace = ["alt+x"]`.
- <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>o</kbd> is `o` because
  <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>a</kbd> is the launcher's.
- <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>O</kbd> acts like an unbound key until an
  agent has been seen in the session (in terminal mode the `O` is typed into
  the pane). <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>v</kbd> works either way, but
  only against a daemon that supports `review-diff`; on a pane with no git
  repository the dock says so and nothing opens.
- <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>V</kbd> always pastes the clipboard
  *image* (saved to a file on the pane's machine, path typed into the pane).
- <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>C</kbd> opens capture mode, including over
  an open panel (the panel is part of the shot).

### [keybindings.window_prefix]

After <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd>.

| Action | Default key(s) | What it does |
|---|---|---|
| `window_prefix_cancel` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> <kbd>Esc</kbd> | Leave the window prefix |
| `window_prefix_close` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> <kbd>x</kbd> | Close the focused window |
| `window_prefix_new` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> <kbd>n</kbd> | New window |
| `window_prefix_next` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> <kbd>Tab</kbd> | Next window |
| `window_prefix_prev` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> <kbd>Shift</kbd>+<kbd>Tab</kbd> | Previous window |
| `window_prefix_rename` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> <kbd>r</kbd> | Rename the focused window |
| `window_prefix_tiling` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>t</kbd> <kbd>t</kbd> | Toggle tiling mode |

### [keybindings.minimize_prefix]

After <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd>.

| Action | Default key(s) | What it does |
|---|---|---|
| `minimize_prefix_cancel` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>Esc</kbd> | Leave the minimize prefix |
| `minimize_prefix_focused` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>m</kbd> | Minimize the focused window |
| `minimize_prefix_restore_1` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>1</kbd> | Restore minimized window 1 |
| `minimize_prefix_restore_2` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>2</kbd> | Restore minimized window 2 |
| `minimize_prefix_restore_3` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>3</kbd> | Restore minimized window 3 |
| `minimize_prefix_restore_4` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>4</kbd> | Restore minimized window 4 |
| `minimize_prefix_restore_5` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>5</kbd> | Restore minimized window 5 |
| `minimize_prefix_restore_6` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>6</kbd> | Restore minimized window 6 |
| `minimize_prefix_restore_7` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>7</kbd> | Restore minimized window 7 |
| `minimize_prefix_restore_8` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>8</kbd> | Restore minimized window 8 |
| `minimize_prefix_restore_9` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>9</kbd> | Restore minimized window 9 |
| `minimize_prefix_restore_all` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>m</kbd> <kbd>M</kbd> | Restore every minimized window |

### [keybindings.workspace_prefix]

After <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd>. The prefix route to
workspaces works on every terminal, including a stock macOS terminal where
<kbd>Opt</kbd> digits may compose.

| Action | Default key(s) | What it does |
|---|---|---|
| `workspace_prefix_cancel` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>Esc</kbd> | Leave the workspace prefix |
| `workspace_prefix_move_1` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#33;</kbd> | Move the focused window to workspace 1 |
| `workspace_prefix_move_2` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#64;</kbd> | Move the focused window to workspace 2 |
| `workspace_prefix_move_3` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#35;</kbd> | Move the focused window to workspace 3 |
| `workspace_prefix_move_4` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#36;</kbd> | Move the focused window to workspace 4 |
| `workspace_prefix_move_5` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#37;</kbd> | Move the focused window to workspace 5 |
| `workspace_prefix_move_6` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#94;</kbd> | Move the focused window to workspace 6 |
| `workspace_prefix_move_7` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#38;</kbd> | Move the focused window to workspace 7 |
| `workspace_prefix_move_8` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#42;</kbd> | Move the focused window to workspace 8 |
| `workspace_prefix_move_9` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>&#40;</kbd> | Move the focused window to workspace 9 |
| `workspace_prefix_rename` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>r</kbd> | Rename workspace |
| `workspace_prefix_switch_1` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>1</kbd> | Switch to workspace 1 |
| `workspace_prefix_switch_2` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>2</kbd> | Switch to workspace 2 |
| `workspace_prefix_switch_3` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>3</kbd> | Switch to workspace 3 |
| `workspace_prefix_switch_4` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>4</kbd> | Switch to workspace 4 |
| `workspace_prefix_switch_5` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>5</kbd> | Switch to workspace 5 |
| `workspace_prefix_switch_6` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>6</kbd> | Switch to workspace 6 |
| `workspace_prefix_switch_7` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>7</kbd> | Switch to workspace 7 |
| `workspace_prefix_switch_8` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>8</kbd> | Switch to workspace 8 |
| `workspace_prefix_switch_9` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>9</kbd> | Switch to workspace 9 |

### [keybindings.layout_prefix]

After <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd>. Saved layouts, corner snaps,
percentage sizes and the master-stack controls. The master keys act on the
workspace on screen.

| Action | Default key(s) | What it does |
|---|---|---|
| `add_master` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>i</kbd> | Make one more pane a master pane |
| `cycle_master_position` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>o</kbd> | Move the master panes to the next side: left, right, top, bottom, center |
| `focus_master` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>m</kbd> | Focus the master pane |
| `layout_prefix_cancel` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Esc</kbd> | Cancel layout prefix |
| `layout_prefix_load` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>l</kbd> | Open the layout picker |
| `layout_prefix_save` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>s</kbd> | Save the current layout |
| `remove_master` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>d</kbd> | Make one pane fewer a master pane |
| `resize_height_50` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Shift</kbd>+<kbd>5</kbd> | Set focused window height to 50% |
| `resize_height_60` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Shift</kbd>+<kbd>6</kbd> | Set focused window height to 60% |
| `resize_height_70` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Shift</kbd>+<kbd>7</kbd> | Set focused window height to 70% |
| `resize_height_80` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Shift</kbd>+<kbd>8</kbd> | Set focused window height to 80% |
| `resize_height_90` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Shift</kbd>+<kbd>9</kbd> | Set focused window height to 90% |
| `resize_width_50` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>5</kbd> | Set focused window width to 50% |
| `resize_width_60` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>6</kbd> | Set focused window width to 60% |
| `resize_width_70` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>7</kbd> | Set focused window width to 70% |
| `resize_width_80` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>8</kbd> | Set focused window width to 80% |
| `resize_width_90` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>9</kbd> | Set focused window width to 90% |
| `snap_corner_1` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>1</kbd> | Snap to top-left |
| `snap_corner_2` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>2</kbd> | Snap to top-right |
| `snap_corner_3` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>3</kbd> | Snap to bottom-left |
| `snap_corner_4` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>4</kbd> | Snap to bottom-right |
| `swap_with_master` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>L</kbd> <kbd>Enter</kbd> | Swap the focused pane with the master pane |

The `set_master_position_*` actions (`left`, `right`, `top`, `bottom`,
`center`) and `resize_width_10` to `_40` / `resize_height_10` to `_40` have no
default key; bind them here if you want them:

```toml
[keybindings.layout_prefix]
set_master_position_center = ["c"]
resize_width_30 = ["alt+3"]
```

### [keybindings.tape_prefix]

After <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd>. Tape recording and the tape
manager (see [Automation](automation.md)).

| Action | Default key(s) | What it does |
|---|---|---|
| `tape_prefix_cancel` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>Esc</kbd> | Cancel tape prefix |
| `tape_prefix_manager` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>m</kbd> | Open tape manager |
| `tape_prefix_record` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>r</kbd> | Start recording |
| `tape_prefix_review` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>t</kbd> | Review project tape |
| `tape_prefix_stop` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>s</kbd> | Stop recording |

### [keybindings.debug_prefix]

After <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd>. The showkeys overlay
(<kbd>k</kbd>) is the quickest way to see what spelling tuios receives for a
key you want to bind.

| Action | Default key(s) | What it does |
|---|---|---|
| `debug_prefix_animations` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> <kbd>a</kbd> | Toggle animations |
| `debug_prefix_cache` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> <kbd>c</kbd> | Toggle cache statistics |
| `debug_prefix_cancel` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> <kbd>Esc</kbd> | Cancel debug prefix |
| `debug_prefix_logs` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> <kbd>l</kbd> | Toggle log viewer |
| `debug_prefix_showkeys` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> <kbd>k</kbd> | Toggle showkeys overlay |

### [keybindings.sidebar]

Live only while the rail owns the keyboard (<kbd>s</kbd> in window mode, or
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>e</kbd>). These keys are deliberately kept
out of the window-mode map, so <kbd>j</kbd>/<kbd>k</kbd>/<kbd>h</kbd>/<kbd>l</kbd>
on the rail never leak onto panes.

| Action | Default key(s) | What it does |
|---|---|---|
| `accent` | <kbd>c</kbd> | Recolor the window under the cursor |
| `activate` | <kbd>Enter</kbd> | Activate the row: attach, or focus the pane |
| `agents_filter` | <kbd>f</kbd> | Agents section: all sessions, or this one |
| `agents_sort` | <kbd>o</kbd> | Agents section: sort by needs you, priority, or recency |
| `collapse` | <kbd>h</kbd>, <kbd>Left</kbd> | Step up to the previous section |
| `cursor_down` | <kbd>j</kbd>, <kbd>Down</kbd> | Move the cursor down a row |
| `cursor_up` | <kbd>k</kbd>, <kbd>Up</kbd> | Move the cursor up a row |
| `exit` | <kbd>Esc</kbd>, <kbd>s</kbd> | Leave the rail, back to the panes |
| `expand` | <kbd>l</kbd>, <kbd>Right</kbd> | Step down to the next section |
| `file_search` | <kbd>Ctrl</kbd>+<kbd>f</kbd> | Search files below the folder the sidebar shows |
| `first` | <kbd>g</kbd>, <kbd>Home</kbd> | Jump to the first row |
| `help` | <kbd>&#63;</kbd> | Show the list of the rail's keys |
| `jump_1` | <kbd>1</kbd> | Jump to session 1 by its position in the rail |
| `jump_2` | <kbd>2</kbd> | Jump to session 2 in the rail |
| `jump_3` | <kbd>3</kbd> | Jump to session 3 in the rail |
| `jump_4` | <kbd>4</kbd> | Jump to session 4 in the rail |
| `jump_5` | <kbd>5</kbd> | Jump to session 5 in the rail |
| `jump_6` | <kbd>6</kbd> | Jump to session 6 in the rail |
| `jump_7` | <kbd>7</kbd> | Jump to session 7 in the rail |
| `jump_8` | <kbd>8</kbd> | Jump to session 8 in the rail |
| `jump_9` | <kbd>9</kbd> | Jump to session 9 in the rail |
| `kill` | <kbd>x</kbd> | Open that row's menu on its Close or Kill row |
| `last` | <kbd>G</kbd>, <kbd>End</kbd> | Jump to the last row |
| `mail` | <kbd>i</kbd> | Open the mailbox for the pane under the cursor |
| `menu` | <kbd>m</kbd> | Open the menu for the row under the cursor |
| `narrow` | <kbd>&#60;</kbd> | Collapse the rail. On the divider: split down |
| `new_session` | <kbd>n</kbd> | New session (the sessions header's +), asking which machine |
| `new_window` | <kbd>t</kbd> | New terminal (the terminals header's +) |
| `palette` | <kbd>&#47;</kbd> | Open the palette to find a pane in any session, or filter by @state |
| `rename` | <kbd>r</kbd> | Rename the window under the cursor |
| `reorder_down` | <kbd>J</kbd>, <kbd>Shift</kbd>+<kbd>Down</kbd> | Rail: move this session or machine down |
| `reorder_up` | <kbd>K</kbd>, <kbd>Shift</kbd>+<kbd>Up</kbd> | Rail: move this session or machine up |
| `section` | <kbd>Tab</kbd>, <kbd>Shift</kbd>+<kbd>Tab</kbd> | Cycle the sessions, terminals and agents sections |
| `widen` | <kbd>&#62;</kbd> | Expand the rail. On the divider: split up |

### [keybindings.sidebar_files]

Consulted before `sidebar`, and only while the rail's cursor is on a row of the
files section. That is why <kbd>r</kbd>, <kbd>x</kbd> and <kbd>p</kbd> can mean
rename, cut and paste here and something else on other rows.

| Action | Default key(s) | What it does |
|---|---|---|
| `file_copy` | <kbd>y</kbd> | Files: copy this file |
| `file_create` | <kbd>a</kbd> | Files: new file, or a folder with a trailing / |
| `file_cut` | <kbd>x</kbd> | Files: cut this file |
| `file_delete` | <kbd>d</kbd> | Files: delete this file |
| `file_delete_forever` | <kbd>D</kbd> | Files: delete for good, with no trash |
| `file_edit` | <kbd>Shift</kbd>+<kbd>Enter</kbd> | Files: edit this text file in a new pane |
| `file_open` | <kbd>Enter</kbd> | Files: open this folder, or copy this file's path |
| `file_paste` | <kbd>p</kbd> | Files: paste into this folder |
| `file_rename` | <kbd>r</kbd> | Files: rename this file |

`file_edit` opens a text file in a new pane running the editor set under
Settings, Sidebar, File editor (or `$EDITOR`). <kbd>Shift</kbd>+<kbd>Enter</kbd>
needs a terminal that reports modified Enter (the Kitty keyboard protocol); on
other terminals use the file's context menu or bind `file_edit` elsewhere.
<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>f</kbd> (`prefix_file_search`) and the rail's
<kbd>Ctrl</kbd>+<kbd>f</kbd> (`file_search`) search file names; the search skips
`.git`, `node_modules`, `.venv` and `target` and stops after about 2.5 seconds
(the title says `partial`).

### [keybindings.sidebar_agents]

Consulted before `sidebar`, and only while the rail's cursor is on an agent
row. See [Agents](agents.md) for what each action does to an agent.

| Action | Default key(s) | What it does |
|---|---|---|
| `agent_cancel_queued` | <kbd>x</kbd> | Agents: drop the newest queued message |
| `agent_reply` | <kbd>r</kbd> | Agents: reply to the agent |
| `agent_review` | <kbd>v</kbd> | Agents: review the pane's changes |
| `agent_snooze` | <kbd>z</kbd> | Agents: snooze the pane's Inbox item |
| `agent_unread` | <kbd>u</kbd> | Agents: mark the pane's finished turn unread |

On a row with nothing queued, <kbd>x</kbd> falls through to the rail's own
`kill` (open the row's menu on Close or Kill). <kbd>u</kbd> within 10 seconds of
<kbd>x</kbd> queues the dropped message again. From `send-keys` or a tape,
neither touches the queue.

### [keybindings.inbox]

Live while the Inbox (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>i</kbd>) is open and its
selector line is not. The digits <kbd>1</kbd> to <kbd>9</kbd> are not
bindings: they answer a held approval or a question by the number the prompt
shows (on a held approval, `1` allows once, `2` always allows, `3` denies).

| Action | Default key(s) | What it does |
|---|---|---|
| `inbox_close` | <kbd>Esc</kbd>, <kbd>q</kbd> | Inbox: close |
| `inbox_deny_reason` | <kbd>n</kbd> | Inbox: deny the approval or plan with a reason |
| `inbox_detail_down` | <kbd>J</kbd>, <kbd>Ctrl</kbd>+<kbd>d</kbd> | Inbox: scroll the detail down |
| `inbox_detail_up` | <kbd>K</kbd>, <kbd>Ctrl</kbd>+<kbd>u</kbd> | Inbox: scroll the detail up |
| `inbox_dismiss` | <kbd>d</kbd>, <kbd>Delete</kbd> | Inbox: dismiss the item |
| `inbox_down` | <kbd>j</kbd>, <kbd>Down</kbd>, <kbd>Ctrl</kbd>+<kbd>n</kbd> | Inbox: next item |
| `inbox_filter` | <kbd>f</kbd> | Inbox: show one kind, then the next |
| `inbox_first` | <kbd>g</kbd>, <kbd>Home</kbd> | Inbox: first item |
| `inbox_go` | <kbd>Enter</kbd> | Inbox: go to the item's pane, or open its mail |
| `inbox_last` | <kbd>G</kbd>, <kbd>End</kbd> | Inbox: last item |
| `inbox_mailbox` | <kbd>m</kbd> | Inbox: open the whole mailbox |
| `inbox_page_down` | <kbd>PgDn</kbd> | Inbox: ten items down |
| `inbox_page_up` | <kbd>PgUp</kbd> | Inbox: ten items up |
| `inbox_pass_on` | <kbd>p</kbd> | Inbox: pass held mail on to the agent it was for |
| `inbox_peek` | <kbd>Space</kbd> | Inbox: read the prompt here and answer it |
| `inbox_reply` | <kbd>r</kbd> | Inbox: reply to the mail |
| `inbox_resume` | <kbd>y</kbd> | Inbox: resume the conversation in its pane |
| `inbox_review` | <kbd>v</kbd> | Inbox: review the changes in the item's pane |
| `inbox_select` | <kbd>&#47;</kbd> | Inbox: narrow the list with a selector |
| `inbox_show_snoozed` | <kbd>S</kbd> | Inbox: show or hide snoozed items |
| `inbox_snooze` | <kbd>z</kbd> | Inbox: snooze the item, then 1 to 4 for how long |
| `inbox_undo` | <kbd>u</kbd> | Inbox: undo the last dismiss or snooze |
| `inbox_up` | <kbd>k</kbd>, <kbd>Up</kbd>, <kbd>Ctrl</kbd>+<kbd>p</kbd> | Inbox: previous item |

### [keybindings.inbox_peek]

Live while a prompt is open over the Inbox (opened with <kbd>Space</kbd>) and
its text line is not. <kbd>d</kbd> denies here but dismisses in the list,
which is why this is a scope of its own.

| Action | Default key(s) | What it does |
|---|---|---|
| `peek_approve` | <kbd>a</kbd> | Inbox prompt: approve |
| `peek_approve_always` | <kbd>A</kbd> | Inbox prompt: approve and do not ask again |
| `peek_back` | <kbd>Esc</kbd>, <kbd>q</kbd>, <kbd>Space</kbd> | Inbox prompt: back to the list |
| `peek_deny` | <kbd>d</kbd> | Inbox prompt: deny |
| `peek_go` | <kbd>Enter</kbd> | Inbox prompt: go to the pane |
| `peek_read_again` | <kbd>r</kbd> | Inbox prompt: read the prompt again |
| `peek_type` | <kbd>Tab</kbd> | Inbox prompt: type an answer |

### [keybindings.mail]

Live while the mailbox is open (<kbd>m</kbd> in the Inbox, or the rail's
<kbd>i</kbd>) and no reply is being written.

| Action | Default key(s) | What it does |
|---|---|---|
| `mail_back` | <kbd>Esc</kbd>, <kbd>q</kbd> | Mailbox: back, or close |
| `mail_down` | <kbd>j</kbd>, <kbd>Down</kbd>, <kbd>Ctrl</kbd>+<kbd>n</kbd> | Mailbox: next thread |
| `mail_focus_pane` | <kbd>o</kbd> | Mailbox: go to the pane that last wrote |
| `mail_new` | <kbd>n</kbd> | Mailbox: write a new message to an agent |
| `mail_open` | <kbd>Enter</kbd> | Mailbox: open the thread, or reply in an open one |
| `mail_page_down` | <kbd>PgDn</kbd> | Mailbox: ten threads down |
| `mail_page_up` | <kbd>PgUp</kbd> | Mailbox: ten threads up |
| `mail_reply` | <kbd>r</kbd> | Mailbox: reply in the open thread |
| `mail_up` | <kbd>k</kbd>, <kbd>Up</kbd>, <kbd>Ctrl</kbd>+<kbd>p</kbd> | Mailbox: previous thread |

### [keybindings.script]

Live only while a `.tape` is playing back. It shares
<kbd>Ctrl</kbd>+<kbd>p</kbd> with the palette without a conflict, because the
two contexts are never active together.

| Action | Default key(s) | What it does |
|---|---|---|
| `script_pause` | <kbd>Ctrl</kbd>+<kbd>p</kbd> | Pause or resume the playing tape |

### Actions with no default key

These actions exist and can be bound in a suitable section (most in
`prefix_mode`, `global` or a window-mode section), but ship unbound. Several
are reachable from the command palette or a context menu instead.

| Action | What it does |
|---|---|
| `clear_selection` | Clear the text selection |
| `close_workspace` | Close every pane on the current workspace, after a confirmation |
| `copy_mode_search_backward` | Enter copy mode and search backward |
| `copy_mode_search_forward` | Enter copy mode and search forward |
| `cycle_tiling_scheme` | Cycle the workspace's tiling scheme: spiral, longest side, alternate, smart split |
| `hints_all_panes` | Label the text on all panes to copy it |
| `hold_window_mode` | Hold for window management mode |
| `kill_session` | Kill the session the menu was opened on |
| `kill_session_next` | Kill session, go to next |
| `kill_session_quit` | Kill session and quit |
| `paste_clipboard` | Paste from clipboard |
| `rename_session` | Rename the session the menu was opened on |
| `resize_height_10` | Set focused window height to 10% |
| `resize_height_20` | Set focused window height to 20% |
| `resize_height_30` | Set focused window height to 30% |
| `resize_height_40` | Set focused window height to 40% |
| `resize_master_shrink_left` | Decrease master width from left edge |
| `resize_width_10` | Set focused window width to 10% |
| `resize_width_20` | Set focused window width to 20% |
| `resize_width_30` | Set focused window width to 30% |
| `resize_width_40` | Set focused window width to 40% |
| `screenshot` | Pick what to screenshot |
| `screenshot_screen` | Screenshot the whole screen |
| `screenshot_window` | Screenshot this window |
| `set_accent` | Accent color |
| `set_master_position_bottom` | Put the master panes at the bottom |
| `set_master_position_center` | Put the master panes in the center, with the stack on both sides |
| `set_master_position_left` | Put the master panes on the left |
| `set_master_position_right` | Put the master panes on the right |
| `set_master_position_top` | Put the master panes at the top |
| `set_session_accent` | Session color |
| `set_tiling_scheme_alternate` | Set the workspace's tiling scheme to alternate |
| `set_tiling_scheme_longest_side` | Set the workspace's tiling scheme to longest side |
| `set_tiling_scheme_smart_split` | Set the workspace's tiling scheme to smart split |
| `set_tiling_scheme_spiral` | Set the workspace's tiling scheme to spiral |
| `settings_sidebar` | Sidebar settings |
| `stop_recording` | Stop tape recording |
| `toggle_cache_stats` | Toggle cache statistics |
| `toggle_logs` | Toggle log viewer |
| `toggle_multifocus_active` | Add or remove the focused pane from multifocus |
| `toggle_multifocus_all` | Add all panes on the workspace to multifocus, or clear it |
| `toggle_tape_manager` | Toggle tape manager |
| `workspace_pill_switch` | Switch to workspace |



## Rebinding

### The syntax

A binding is `action = [keys...]` inside the section that owns the action.
Writing an action replaces its default keys entirely; it does not add to them.

```toml
[keybindings]
leader_key = "ctrl+a"

[keybindings.window_management]
close_window = ["x"]            # drop the default w, keep x
new_window   = ["n", "ctrl+n"]  # two keys for one action

[keybindings.prefix_mode]
prefix_split_vertical   = ["v"]   # ctrl+a v splits left/right
prefix_split_horizontal = ["s"]   # ctrl+a s splits top/bottom
prefix_scrollback       = ["/"]   # move the scrollback browser off s
```

Rules:

- **The section matters.** An action is looked up in the section that defines
  it. `new_window` lives in `window_management`; putting it in `layout` makes
  it a window-mode binding all the same (both are in the window-mode scope),
  but putting `prefix_new_window` in `window_management` does not make it a
  prefix chord. Use the action's own section from the tables above.
- **Some actions exist in more than one section** under the same name, with
  different meanings by scope: `new_window` (window mode <kbd>n</kbd>, rail
  <kbd>t</kbd>), `launcher` (global <kbd>Alt</kbd>+<kbd>Space</kbd>, prefix
  <kbd>a</kbd>), `terminal_focus_left` (terminal mode, and prefix
  <kbd>Left</kbd>), `next_session`/`prev_session` (window mode and prefix).
- **Multiple keys per action** are listed in the array, in any order.
- **A missing line gets its default back** at the next load. To change an
  action you must write it; to keep a default you can simply leave it out.
- **Moving a key between actions** needs both lines: the new owner and the old
  owner without that key. Otherwise the two compete and the precedence rules
  decide (see [Who wins a contested key](#who-wins-a-contested-key)).

### Unbinding

An action set to an empty list has no key, and **stays** empty: the default
does not come back.

```toml
[keybindings.terminal_mode]
terminal_focus_left  = []   # give alt+left back to readline/zsh/fish
terminal_focus_right = []   # give alt+right back too

[keybindings.global]
launcher = []               # free alt+space
```

::: warning
An empty list and a missing line are not the same. A line your file does not
have gets its default back the next time tuios loads the config; an action set
to `[]` stays empty. The validator does not warn about an empty list, because
it is the documented way to unbind.
:::

From a shell, two commands do this for you and write the file:

```sh
tuios keybinds unbind close_window w   # take w off close_window, keep x
tuios keybinds unbind close_window     # leave close_window with no key at all
tuios keybinds free alt+left           # take alt+left off EVERY action in every scope
```

| Command | Scope of the change | When to use it |
|---|---|---|
| `tuios keybinds unbind <action> [key]` | One action. Name a key to remove only that one; name none to remove all of its keys | "This action should not be on this key" |
| `tuios keybinds free <key>` | Every action, in every scope, that holds the key | "The program in my pane wants this key" |

`free` works across every scope at once because a key that tuios still claims
anywhere is a key the pane never sees. Each action that runs out of keys is
written as an empty list. `free` cannot take the leader (move
`keybindings.leader_key` instead) or the few keys the input path reads
directly; it says so rather than reporting success.

### Inspecting your bindings

| Command | What it shows |
|---|---|
| `tuios keybinds list` | The common bindings, as configured, in tables (Global, Window Management, Workspaces, Layout, Modes, Selection) |
| `tuios keybinds list-custom` | Only the bindings that differ from the defaults, beside their defaults |
| `tuios keybinds doctor` | Every scope: keys claimed twice, keys taken from the pane, keys a common program wants, keys tuios cannot read. `--json` for the same analysis; `--guest <prog>` to treat a program as the one in the pane |
| `tuios keybinds explain <key>` | Every scope the key acts in, whether the pane receives it, its terminal-level twin, and which common programs bind it. `--json`, `--guest` |
| `tuios keybinds free <key>` | Hand a key back to the pane (writes the file) |
| `tuios keybinds unbind <action> [key]` | Take a key off one action (writes the file) |

::: note
v0.8.5 has no `tuios keybinds edit` or `tuios keybinds reset` subcommand.
Typing either just prints the `keybinds` help. Edit bindings in the file
(`tuios config edit`) or in the keybind manager.
:::

```sh
tuios keybinds explain ctrl+p
```

```text
ctrl+p
  global           Open the command palette [global]
  inbox            Inbox: previous item [inbox]
  mail             Mailbox: previous thread [mail]
  script           Pause or resume the playing tape [script]
  pane             kept from the pane: Open the command palette

  wanted by (reference):
    zellij                           pane mode
    vim / neovim                     keyword completion
    fish                             history back
```

That is the output with a default config: one line per scope that binds the
key, then what the pane gets, then which common programs want the key. On the
machine used for this chapter the palette was moved to
<kbd>Ctrl</kbd>+<kbd>Space</kbd>, so the same command printed no `global` line
and ended with `pane  forwarded to the pane`. A key that nothing claims prints
`free: nothing in tuios claims it, and the pane receives it`.


`tuios keybinds doctor` groups its report by evidence:

| Evidence | Meaning |
|---|---|
| `certain` | Derived from tuios's own registry and dispatch order |
| `observed` | Read from the pane (or terminal) when the report was built; possibly stale |
| `reference` | A fixed list of common programs' defaults. A hint, never a fact about your setup |

```sh
tuios keybinds doctor --guest nvim
tuios keybinds doctor --json | jq '.collisions, .key_problems'
```

### The keybind manager

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>k</kbd> (or the palette row "Keybind
manager") opens an overlay over the same analysis, with four tabs:

| Tab | What it shows |
|---|---|
| Bindings | Every binding in every scope, filterable by typing |
| Conflicts | Keys used twice; the dead bindings are marked |
| Guests | Where tuios takes a key that the pane's program wants |
| Record | Press a key and see what tuios does with it |

| Key | What it does |
|---|---|
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> | Next / previous tab |
| <kbd>Left</kbd> / <kbd>Right</kbd> | Previous / next tab (on the Bindings tab, where letters are filter text) |
| <kbd>h</kbd>, <kbd>&#91;</kbd> / <kbd>l</kbd>, <kbd>&#93;</kbd> | Previous / next tab (on the tabs with no filter) |
| <kbd>Up</kbd>, <kbd>Down</kbd> and the other list keys | Move |
| typing, <kbd>Backspace</kbd>, <kbd>Ctrl</kbd>+<kbd>u</kbd> | Edit / clear the Bindings filter |
| <kbd>&#47;</kbd> | Go to the Bindings tab (from a tab with no filter) |
| <kbd>Ctrl</kbd>+<kbd>r</kbd> | Record. On a selected binding, the next key pressed is captured for that action; elsewhere it only inspects |
| <kbd>Enter</kbd> | Write the captured key to the action. It is appended, so a second key becomes an alternative |
| <kbd>Ctrl</kbd>+<kbd>d</kbd> | Bindings: unbind the selected binding. Conflicts: remove the dead bindings. Record: free the captured key everywhere |
| <kbd>Ctrl</kbd>+<kbd>x</kbd> | Free the selected key from every action |
| <kbd>Esc</kbd>, <kbd>Ctrl</kbd>+<kbd>c</kbd>, <kbd>q</kbd> (no-filter tabs) | Close |

While the recorder is armed there are no commands at all, <kbd>Esc</kbd>
included: the very next key is the one recorded, and recording it disarms.

::: example
**Example: give "Toggle zoom" a second key from inside tuios**

1. <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>k</kbd>, type `zoom`.
2. Select the `toggle_zoom` row, press <kbd>Ctrl</kbd>+<kbd>r</kbd>, then
   press <kbd>Z</kbd>.
3. Press <kbd>Enter</kbd>. The file now has `toggle_zoom = ["z", "Z"]` and the
   overlay already shows the new binding.
:::

The palette reaches the manager too: type `#` and an action name (see
[Keybinding rows](#keybinding-rows-the-token)).

### Editing the file, validation and reload

```sh
tuios config path     # print the path of config.toml
tuios config edit     # open it in $EDITOR, else $VISUAL, else vim, vi, nano, emacs
tuios config reset    # reset the WHOLE config to defaults
tuios config apply    # push changes that grant more to a running daemon (run outside tuios)
```

::: warning
`tuios config reset` resets every section, not only `[keybindings]`. To undo
only your key changes, delete the `[keybindings.*]` lines you wrote: missing
lines come back as defaults.
:::

Validation runs whenever the config is loaded:

| Problem | Reported as |
|---|---|
| A key tuios cannot read (bad modifier, unknown name) | Error, naming the key; also `key_problems` in `doctor` |
| A key two actions contest | Warning: which action runs, which never run, and the `unbind` command to fix it |
| `new_window`, `close_window`, `enter_terminal_mode`, `enter_window_mode` or `quit` with no key | Warning: tuios may be difficult to use |
| On macOS, a hand-written `alt+` | Advisory warning suggesting `opt+` |
| A bad `[[keybindings.command]]` entry | Warning; tuios ignores that entry |
| A `[[keybindings.copy_pipe]]` entry on `q`, `Esc`, `v`, `V`, `/`, `?` or a digit | Warning |

`config.toml` is watched by every client. When you save it, the client applies
what it can at once and tells you on screen if the file cannot be parsed (the
running config stays in force). For keybindings the rule is:

- Changes made **through the keybind manager** (record, unbind, free) take
  effect immediately in that client, and are written to the file.
- Changes to **`[keybindings.*]` tables in the file**, including those
  written by `tuios keybinds unbind` and `free` from a shell, take effect in
  the **next client**: detach and attach again (<kbd>Ctrl</kbd>+<kbd>b</kbd>
  <kbd>d</kbd>, then `tuios attach`), or restart a standalone tuios.
- For **command keys**, the command and the palette row change on save; a
  changed `key` works in the next client.

::: tip
After any hand edit, run `tuios keybinds doctor`. It reads the file as tuios
will and tells you about dead bindings and unreadable keys before you attach.
:::

`tuios set-config` does not edit keybindings: the binding sections are tables,
not scalar options, and are edited in `config.toml` or the keybind manager.

## Command keys

A `[[keybindings.command]]` entry binds a key to a command **you** write. It
is the tuios equivalent of tmux `bind-key ... run-shell` or
`display-popup`, and of herdr's custom command keybindings. Each entry also
becomes a row in the command palette and in `tuios keybinds list` (under
Commands).

### Schema

| Field | Type | Default | Meaning |
|---|---|---|---|
| `key` | string | required | The key. `prefix+` puts it after the leader (the `prefix_mode` scope, e.g. `prefix+alt+g` is <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Alt</kbd>+<kbd>g</kbd>). Any other key acts in window mode and terminal mode (the `global` scope) |
| `type` | string | `popup` | `scratch`, `popup`, `pane` or `shell` |
| `command` | string | required except for `scratch` | Run with `sh -c`, so pipes and quotes work. Starts in the focused pane's folder. A `scratch` entry without one runs your shell |
| `description` | string | none | The name in the palette and in `tuios keybinds list`. Without it the label is `Run <command>` |
| `name` | string | derived | A stable name for the entry (and its scratch terminal). Default: a slug of the description, else of the command, else of the key |
| `width`, `height` | string | `80%` | Size of a `scratch` or `popup` box, in cells (`100`) or percent (`80%`) |

| `type` | What happens |
|---|---|
| `scratch` | A scratch terminal of its own, toggled by the key like <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>g</kbd>. It has its own layout (you can split it). One scratch is on screen at a time. When the command exits its pane closes; with no pane left, the next press starts it again |
| `popup` | A popup that closes when the command exits |
| `pane` | A new pane in the layout next to the focused one; closes when the command exits |
| `shell` | Runs with no window. You do not see output; a failure shows in the dock |

The command's environment:

| Variable | Value |
|---|---|
| `TUIOS_SESSION` | The session in which you pressed the key |
| `TUIOS_SOCKET` | The daemon's socket |
| `TUIOS_ACTIVE_PANE_ID` | The pane that had focus |
| `TUIOS_ACTIVE_PANE_CWD` | The folder the command starts in |

Each entry is the action `command:<name>`, which is how `tuios keybinds
doctor` and the keybind manager refer to it.

### Rules and edge cases

- **A command key never takes a key from a tuios action or from the leader.**
  If the key is taken, the entry is dead (`doctor` shows it). Two entries on
  one key: the first in the file runs.
- **A bare key without `prefix+` or a modifier** (for example `g`) is in the
  global scope and so takes that letter from every pane. tuios warns. Use
  `prefix+g` or `alt+g`.
- **Invalid entries are warnings**, and tuios ignores the entry: no `key`, an
  unknown `type`, no `command` on a non-scratch entry, an unusable name, the
  reserved name `scratch` (the built-in scratch terminal), an unreadable key,
  or a bad width or height. A second entry with the same name is ignored.
- **Reload.** Saving the file updates an entry's command and palette row. A
  changed key works in the next client. Removing or renaming an entry (or
  changing the description of an entry that has no `name`) closes its scratch
  panes at the next reload, with a dock message.
- **Failure on start.** A scratch command that stops in its first moments (not
  installed, for instance) shows its exit code in the dock. tuios does not
  restart it by itself.
- **Remote sessions.** In a session on another machine, `scratch` and `popup`
  entries do not run (the dock says so). A `pane` entry runs on the session's
  machine; a `shell` entry runs on the machine that runs the tuios client.
- **Who can run one.** Only a key press or the palette. Changing
  `config.toml` never runs a command. A pane with the `respond` grant can press
  keys as you through `run-command`, including a command key, so give that
  grant only to panes you trust.

### Examples

::: example
**Example 1: lazygit in a scratch box, in the focused pane's folder**

```toml
[[keybindings.command]]
key = "prefix+alt+g"
type = "scratch"
command = "lazygit"
description = "Lazygit"
width = "80%"
height = "80%"
```

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Alt</kbd>+<kbd>g</kbd> shows the box, pressing
it again hides it, and lazygit keeps running in between. The palette has a
"Lazygit" row in the Commands category with the shortcut `prefix+alt+g`.
:::

::: example
**Example 2: pick a file with fzf and type it into the pane you came from**

```toml
[[keybindings.command]]
key = "prefix+alt+p"
type = "popup"
command = "tuios send-text -w \"$TUIOS_ACTIVE_PANE_ID\" \"$(fzf)\""
description = "Pick a file"
```

The popup closes when fzf exits, and `tuios send-text` types the pick into the
pane named by `TUIOS_ACTIVE_PANE_ID` (see [CLI](cli.md)).
:::

::: example
**Example 3: copy the pane's folder to the clipboard, no window**

```toml
[[keybindings.command]]
key = "prefix+alt+y"
type = "shell"
command = "printf %s \"$TUIOS_ACTIVE_PANE_CWD\" | (pbcopy || wl-copy || xclip -selection clipboard)"
description = "Copy pane folder"
```

Nothing opens. If none of the three clipboard tools exists, the dock shows the
failure.
:::

Run `tuios keybinds doctor` after adding any entry to check that its key is
free.

## The command palette

The palette is one box that finds every command, every session and window,
every action you can rebind, and every settings row.

### Opening it

| How | Key |
|---|---|
| Global binding `command_palette` | <kbd>Ctrl</kbd>+<kbd>p</kbd> (both modes) |
| Prefix binding `prefix_command_palette` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>P</kbd> |
| From the rail (`palette` in `[keybindings.sidebar]`) | <kbd>&#47;</kbd> with the rail focused |

The launcher (<kbd>Alt</kbd>+<kbd>Space</kbd> or <kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>a</kbd>) is a separate overlay for starting programs; the palette's first
row, "Run a program", opens it. File search (<kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>f</kbd>) reuses the palette's box for file names.

### Keys inside the palette

| Key | What it does |
|---|---|
| typing | Filter. Every printable key, including <kbd>j</kbd> and <kbd>k</kbd>, is query text |
| <kbd>Backspace</kbd> | Delete the last character |
| <kbd>Ctrl</kbd>+<kbd>u</kbd> | Clear the query |
| <kbd>Up</kbd> / <kbd>Down</kbd>, <kbd>Ctrl</kbd>+<kbd>p</kbd> / <kbd>Ctrl</kbd>+<kbd>n</kbd> | Move one row, wrapping at the ends |
| <kbd>Home</kbd> / <kbd>End</kbd> | First / last row |
| <kbd>PgUp</kbd> / <kbd>PgDn</kbd> | A page, stopping at the ends |
| mouse wheel | Scroll the list |
| <kbd>Enter</kbd> | Run the selected row |
| <kbd>Esc</kbd> | Close |

Set `appearance.wrap_lists = false` to stop at the ends instead of wrapping.

### What is listed

With **nothing typed**, the palette lists its commands under category headers.
The headers are not rows; the cursor steps over them. The categories appear in
this order:

| Category | Examples |
|---|---|
| Run | Run a program |
| View | Start the screen saver |
| Window | Screenshot this window, New window, Close window, Toggle zoom, Toggle multifocus, Close workspace, Edit scrollback in `$EDITOR` |
| Clipboard | Paste the clipboard image as a file path |
| Layout | Toggle tiling, Split horizontal/vertical, Rotate split, tiling schemes, master position, Layout: BSP / master-stack / scrolling, Save layout, Load layout |
| Navigation | Next / Previous window, Workspace 1 to 9, All windows |
| Session | New session, Settings, Theme picker, Reload config, Toggle sidebar, Switch session, Show help, hints, scratch, copy mode, tape |
| Keybind | Keybind manager, Rebind a key, Unbind a key |
| Agents | Agents: open mailbox, Agents: Inbox, what is waiting for you, Agents: go to the oldest waiting, Agents: Review changes of the focused pane, Agents: Inbox, mail for you |
| Commands | One row per `[[keybindings.command]]` entry |
| Sessions | `Session: <name>`, `Window: <label>`, and `Mail #N from → to: subject` for unread threads |

Rows that depend on state are hidden until they apply: the Agents rows until an
agent has been seen, the review row unless the daemon can review diffs, and
"Multi copy mode" unless a multifocus set exists. Settings rows are never in
the empty list.

Once you **type**, the headers go. Rows are ranked by how well their name
matches (a fuzzy, scored match; the matched letters are lit), and each row
names its category in a quiet column on the right. A row admitted only because
its category matches comes after every name match, so typing `layout` lists
the Layout section below anything actually called layout. Settings rows come
last of all.

The right-hand slot of a row is its key or its consequence: `prefix+c` for
New window, `another machine` for a session on another host, `unread` for a
mail thread. For the built-in command rows this label is fixed text for the
default layout; for command-key rows and `#` rows it is read from your config.

::: example
**Example: three ways to split**

Open the palette and type `spl`. "Split horizontal", "Split vertical" and
"Smart split" rank first, with `spl` underlined. <kbd>Down</kbd>,
<kbd>Enter</kbd> runs the split.
:::

### State filters: the @ token

A query that starts with `@` narrows the list to **panes** in an agent state.
Only the session and window rows carry a state, so every static command drops
out. The state name is matched by prefix, so one letter is enough:

| Token | Admits panes whose agent is |
|---|---|
| `@a`, `@attention` | needing input or errored (the same definition as the rail's attention mark) |
| `@w`, `@working` | working |
| `@n`, `@needs_input` | waiting for input |
| `@d`, `@done` | done |
| `@i`, `@idle` | idle |
| `@e`, `@errored` | errored |
| `@` alone | any pane running an agent |

A token naming no state (a typo) admits nothing, so you see an empty list
rather than a filter that silently did not apply. Text after the token is
matched as usual: `@a server` ranks the attention panes whose names match
`server`.

::: example
**Example: jump to whichever agent needs you**

<kbd>Ctrl</kbd>+<kbd>p</kbd>, type `@a`, <kbd>Enter</kbd>. The palette switches
session if it must and focuses that pane. The rail's <kbd>&#47;</kbd> opens the
same palette, ready for the same token.
:::

### Keybinding rows: the # token

A query that starts with `#` turns the palette into a search over **actions**.
Every action gets one row, whatever it is bound to, built from the registry:

- the row's name is the action's description followed by the action name, for
  example `Close current window  prefix_close_window`, so you can search by
  either the words or the config name;
- the right-hand slot lists every key that reaches the action, chord included
  (`ctrl+b x`), or `unbound`;
- <kbd>Enter</kbd> opens the keybind manager filtered to that action, where
  each of its bindings can be rebound or unbound.

`#` is exclusive both ways: a `#` query lists only action rows, and no other
query ever lists them, so a few hundred actions never bury the commands. A bare
`#` lists every action, which is also the answer to "what can I rebind?". The
"Rebind a key" and "Unbind a key" rows advertise this with `or type #close` in
their key slot.

Two of the rows `#zoom` finds, with a default config:

| Row name | Key slot |
|---|---|
| `Toggle zoom (fullscreen)  toggle_zoom` | `z` |
| `Fullscreen current window  prefix_fullscreen` | `ctrl+b z` |

### Settings rows

Every settings row is also a palette row, matched as `Settings: <name>`, with
its tab in the key slot. Type the setting's name (`pane background`) or the
prefix (`settings: pane background`); <kbd>Enter</kbd> opens the settings page
on that row.

### Agent entries

The Agents category holds the agent commands (named "Agents: ..." so typing
`agent` lists them): the mailbox, the Inbox, the Inbox on its mail, the oldest
waiting item, and the review of the focused pane. Session and window rows for
panes running an agent carry a coloured state glyph, which is also what the
`@` filter reads. Unread mail threads appear as `Mail #N ...` rows; selecting
one opens the mailbox on that thread. See [Agents](agents.md).

## Hints mode

Hints mode puts a short label on each useful piece of text in the focused pane
(URLs, paths, hashes, addresses, numbers and more) so you can copy it by typing
the label. It works like tmux-fingers or kitty's hints kitten.

| Key | What it does |
|---|---|
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>F</kbd> | Start hints (`hints` in `prefix_mode`) |
| a label, such as <kbd>a</kbd> or <kbd>l</kbd><kbd>s</kbd> | Copy the text and close |
| the label with <kbd>Shift</kbd>, such as <kbd>A</kbd> | Copy the text and type it into the pane |
| the label with <kbd>Ctrl</kbd>, such as <kbd>Ctrl</kbd>+<kbd>a</kbd> | Open a URL in the browser or a path in `$EDITOR` in a new pane |
| <kbd>Backspace</kbd> | Remove the last label letter typed |
| <kbd>Esc</kbd>, or the leader | Close |
| <kbd>q</kbd> | Close, when `q` is not a label letter |
| <kbd>Ctrl</kbd>+<kbd>c</kbd>, <kbd>Ctrl</kbd>+<kbd>g</kbd> | Close, when `c` / `g` is not a label letter (with the default alphabet, `g` is a letter, so <kbd>Ctrl</kbd>+<kbd>g</kbd> opens label `g`) |

The nearest text to the cursor gets the shortest label, and the same text gets
the same label every time. While labels show, hints mode keeps all input from
the pane. A click or the wheel closes it first; so does the pane closing, the
focus moving, or a workspace change. The palette has it too (search `hints`).

### All panes

`hints_all_panes` labels every pane the workspace shows (tiled, floating,
focused), giving the focused pane the shortest labels and the nearest panes
the next shortest. Labels are unique across panes; <kbd>Shift</kbd> and a label
types the text into the *focused* pane even if it came from another;
<kbd>Ctrl</kbd> and a label opens it using the folder and machine of the pane
that shows it. Text you cannot see (minimized, behind a zoomed pane, off
screen, under another pane) gets no label.

The action has no default key. Bind it, or make <kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>F</kbd> do it:

```toml
[keybindings.prefix_mode]
hints_all_panes = ["A"]

[hints]
all_panes = true   # default false: Ctrl+B F labels only the focused pane
```

### Hints settings

| Option | Default | Meaning |
|---|---|---|
| `hints.builtins` | `"all"` | `"all"`, `"none"`, or names such as `"url,path,sha"` |
| `hints.patterns` | `[]` | Extra Go regular expressions, tried before the built-ins; a group named `match` sets what is copied |
| `hints.alphabet` | `"asdfghjkl"` | Label letters, easiest first, lowercase |
| `hints.open` | `true` | Let <kbd>Ctrl</kbd> and a label open the text |
| `hints.dim` | `60` | How much the rest of the pane dims, 10 to 90 percent |
| `hints.all_panes` | `false` | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>F</kbd> labels all panes |

The built-in patterns are `url`, `path`, `diff`, `sha`, `ip`, `uuid`, `color`,
`hex`, `number` (4 digits or more), `email` and `id` (Kubernetes-style
resource names and `sha256:` digests). All but `hints.patterns` are on the
settings page (Selection tab) and work with `tuios set-config`. Full details,
including when <kbd>Ctrl</kbd> copies instead of opening, are in the upstream
[HINTS.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/HINTS.md).



## Copy mode, search and selection

### Entering and leaving

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#91;</kbd> (`prefix_selection`) starts copy mode
on the focused pane. The copy cursor starts on the terminal cursor, usually the
prompt line, as in tmux. Set `appearance.selection.copy_entry = "center"` to
start on the middle row instead.

| Key | What it does |
|---|---|
| <kbd>q</kbd>, <kbd>Esc</kbd> | Leave copy mode |
| <kbd>i</kbd> | Leave copy mode and enter terminal mode |

Copy mode's keys are its own vim-style grammar, not bindings in a
`[keybindings.*]` section, so they cannot be rebound (only extended with
`[[keybindings.copy_pipe]]`, below). Inside copy mode, the leader does not
start a chord, because copy mode uses <kbd>Ctrl</kbd>+<kbd>b</kbd> for page
up. `tuios send-keys` and tapes cannot drive copy mode: it ignores remote
keys.

### Motion

A number typed first repeats a motion (`5j`), and a number before
<kbd>G</kbd> goes to that line (`10G`).

| Key | Motion |
|---|---|
| <kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd>, arrows | Left, down, up, right |
| <kbd>w</kbd> / <kbd>b</kbd> / <kbd>e</kbd> | Next word, previous word, end of word |
| <kbd>W</kbd> / <kbd>B</kbd> / <kbd>E</kbd> | The same by WORD (whitespace-separated) |
| <kbd>0</kbd>, <kbd>&#94;</kbd> / <kbd>&#36;</kbd> | Start / end of the line |
| <kbd>g</kbd><kbd>g</kbd> / <kbd>G</kbd> | Top of the scrollback / bottom |
| <kbd>H</kbd> / <kbd>M</kbd> / <kbd>L</kbd> | Top / middle / bottom of the screen |
| <kbd>Ctrl</kbd>+<kbd>u</kbd> / <kbd>Ctrl</kbd>+<kbd>d</kbd> | Half a page up / down |
| <kbd>Ctrl</kbd>+<kbd>b</kbd>, <kbd>PgUp</kbd> / <kbd>Ctrl</kbd>+<kbd>f</kbd>, <kbd>PgDn</kbd> | A page up / down |
| <kbd>&#123;</kbd> / <kbd>&#125;</kbd> | Previous / next paragraph |
| <kbd>&#37;</kbd> | Matching bracket |
| <kbd>f</kbd>, <kbd>F</kbd>, <kbd>t</kbd>, <kbd>T</kbd> then a character | Find / till a character forward or backward on the line |
| <kbd>&#59;</kbd> / <kbd>&#44;</kbd> | Repeat the last character search / in the opposite direction |

### Search

| Key | What it does |
|---|---|
| <kbd>&#47;</kbd> | Search forward, down toward the newest output |
| <kbd>&#63;</kbd> | Search backward, up into the scrollback |
| <kbd>n</kbd> | Next match in the direction of the last search |
| <kbd>N</kbd> | Next match in the opposite direction |
| <kbd>Esc</kbd> in the prompt | Cancel the search and move the cursor back |
| <kbd>Ctrl</kbd>+<kbd>l</kbd> | Clear the search highlighting |

The prompt shows `/` or `?` for the direction. A search starts at the copy
cursor and wraps to the other end of the buffer when nothing is found in that
direction. More than 1000 matches shows `1000+`.

Two actions enter copy mode and open the search prompt in one key, like tmux
`bind-key b copy-mode \; send-keys ?`. They have no default key:

```toml
[keybindings.prefix_mode]
copy_mode_search_backward = ["/"]   # ctrl+b / searches up into the scrollback
copy_mode_search_forward  = ["alt+/"]
```

The palette has them as "Copy mode: search forward" and "Copy mode: search
backward". If the pane is already in copy mode, the action just opens the
prompt without moving the cursor. Bound in `global`, `terminal_mode` or
`window_management`, the key also works from inside copy mode; bound under the
leader, it works only from outside (copy mode keeps <kbd>Ctrl</kbd>+<kbd>b</kbd>).

### Selecting and yanking

| Key | What it does |
|---|---|
| <kbd>v</kbd> | Start a character selection (VISUAL); <kbd>v</kbd> again ends it |
| <kbd>V</kbd> | Start a line selection (VISUAL LINE); from VISUAL, switch to lines; in VISUAL LINE, end it |
| the motions above | Extend the selection |
| <kbd>y</kbd>, <kbd>c</kbd> | Yank the selection to the clipboard |
| <kbd>q</kbd>, <kbd>Esc</kbd> | End the selection |
| mouse drag | Start a new character selection at the press |

A yank is written with OSC 52 and, on a local client, with the system
clipboard tool. Outside copy mode, a mouse selection copies on release, and
<kbd>c</kbd> in window mode (`copy_selection`) copies the current selection.

**Multi copy mode.** With a multifocus set, <kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>&#91;</kbd> enters copy mode in every pane of the set ("Multi copy mode" in the
palette); a search prompt opens in each, and <kbd>y</kbd> copies every pane's
selection joined in the configured format.

### Pipe a yank through a command

| Setting | Effect |
|---|---|
| `appearance.selection.copy_command` | Every yank in copy mode (<kbd>y</kbd> and <kbd>c</kbd>) goes through this command; its stdout becomes the clipboard (tmux `copy-command`) |
| `[[keybindings.copy_pipe]]` | A copy-mode key with its own command (tmux `copy-pipe` / `copy-pipe-and-cancel`) |

| `copy_pipe` field | Default | Meaning |
|---|---|---|
| `key` | required | The copy-mode key. An entry on `y` replaces the plain yank. `p` and `P` are free in copy mode; `q`, `Esc`, `v`, `V`, `/`, `?` or a digit get a warning |
| `command` | required | Run with `sh -c`; gets the selection on stdin |
| `cancel` | `false` | `false`: stay in copy mode and clear the selection (`copy-pipe`). `true`: leave copy mode (`copy-pipe-and-cancel`) |
| `description` | none | Names the entry in dock messages |

```toml
[appearance.selection]
copy_command = "xclip -selection primary >/dev/null"

[[keybindings.copy_pipe]]
key = "p"
command = "tr '\\n' ' '"
cancel = true
description = "flatten"
```

The clipboard falls back to the plain selection when the command writes
nothing, exits non-zero (the dock shows the code and the first stderr line), or
runs longer than 10 seconds. The command runs on the machine that runs the
client, in the focused pane's folder, with the same `TUIOS_*` variables as a
command key.

## The rail and the Inbox

The rail (the session sidebar) and the Inbox each own the keyboard while they
are focused, and their keys are rebindable sections of their own. The tables
under [Default keybindings](#default-keybindings-section-by-section) list every
action; this is the short version. [Agents](agents.md) explains what the agent
actions do.

| Where | Keys |
|---|---|
| Focus the rail | <kbd>s</kbd> (window mode), <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>e</kbd>; <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>b</kbd> shows or hides it |
| On the rail | <kbd>j</kbd>/<kbd>k</kbd> move, <kbd>h</kbd>/<kbd>l</kbd> section, <kbd>Enter</kbd> activate, <kbd>1</kbd>-<kbd>9</kbd> session, <kbd>&#47;</kbd> palette, <kbd>m</kbd> menu, <kbd>&#63;</kbd> its keys, <kbd>Esc</kbd>/<kbd>s</kbd> leave |
| On an agent row | <kbd>r</kbd> reply, <kbd>v</kbd> review, <kbd>u</kbd> unread, <kbd>z</kbd> snooze, <kbd>x</kbd> drop the newest queued message |
| Open the Inbox | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>i</kbd>; on its mail, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>M</kbd>; walk waiting items without opening it, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>o</kbd> |
| In the Inbox | <kbd>j</kbd>/<kbd>k</kbd>, <kbd>Enter</kbd> go, <kbd>Space</kbd> read and answer, <kbd>r</kbd> reply, <kbd>y</kbd> resume, <kbd>p</kbd> pass on, <kbd>d</kbd> dismiss, <kbd>f</kbd> kind, <kbd>&#47;</kbd> selector, <kbd>m</kbd> mailbox, <kbd>v</kbd> review, <kbd>z</kbd> snooze, <kbd>u</kbd> undo, <kbd>S</kbd> snoozed, <kbd>Esc</kbd> close |
| On a held approval | <kbd>1</kbd> allow once, <kbd>2</kbd> always, <kbd>3</kbd> deny, <kbd>n</kbd> deny with a reason |
| In the prompt (<kbd>Space</kbd>) | a digit picks, <kbd>a</kbd> approve, <kbd>A</kbd> always, <kbd>d</kbd> deny, <kbd>Tab</kbd> type, <kbd>r</kbd> read again, <kbd>Enter</kbd> go, <kbd>Esc</kbd> back |
| In the mailbox | <kbd>j</kbd>/<kbd>k</kbd>, <kbd>Enter</kbd> open, <kbd>n</kbd> new, <kbd>r</kbd> reply, <kbd>o</kbd> go to the writer's pane, <kbd>Esc</kbd> back |

On a risky approval, <kbd>1</kbd> and <kbd>2</kbd> act only on a second press
within 3 seconds. The footers always name the keys your config binds.

The review overlay (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>v</kbd>) has fixed keys of
its own, not bindings; see [Agents](agents.md).

## Lists, panels and settings

Every list in the TUI (the palette, launcher, settings, Inbox, mailbox,
keybind manager, every picker and menu, the dock and rail editors, the tape
manager) moves the same way: <kbd>Up</kbd>/<kbd>Down</kbd> or
<kbd>Ctrl</kbd>+<kbd>p</kbd>/<kbd>Ctrl</kbd>+<kbd>n</kbd> one row (wrapping
unless `appearance.wrap_lists = false`), <kbd>Home</kbd>/<kbd>End</kbd> the
ends, <kbd>PgUp</kbd>/<kbd>PgDn</kbd> a page, <kbd>j</kbd>/<kbd>k</kbd>/<kbd>g</kbd>/<kbd>G</kbd>
in a list with no filter, <kbd>Ctrl</kbd>+<kbd>u</kbd> to clear a filter, and the
wheel. The close-session and file confirmations never wrap, so up from Cancel
cannot land on the destructive answer.

The settings page (<kbd>&#44;</kbd> in window mode, <kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>&#44;</kbd>) uses the same list keys, plus <kbd>Left</kbd>/<kbd>Right</kbd> to change a
value, <kbd>Tab</kbd> for tabs, <kbd>&#47;</kbd> to search and <kbd>Backspace</kbd> to reset a row. The help overlay
(<kbd>&#63;</kbd> in window mode, <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#63;</kbd>) lists
the bindings read from your config, including an Agents section and the mouse
gestures.

## Cheat sheet

The 40 keys worth learning first, with the default leader. "WM" is window
mode, "TM" terminal mode.

| # | Keys | Where | What it does |
|---|---|---|---|
| 1 | <kbd>Ctrl</kbd>+<kbd>b</kbd> | both | Leader: start a prefix chord |
| 2 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Ctrl</kbd>+<kbd>b</kbd> | TM | Send a literal leader to the pane |
| 3 | <kbd>i</kbd>, <kbd>Enter</kbd> | WM | Enter terminal mode |
| 4 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Esc</kbd> | TM | Back to window mode |
| 5 | <kbd>Opt</kbd>+<kbd>Esc</kbd> / <kbd>Alt</kbd>+<kbd>Esc</kbd> | TM | Back to window mode, no prefix (macOS / others) |
| 6 | <kbd>Ctrl</kbd>+<kbd>p</kbd> | both | Command palette |
| 7 | <kbd>Alt</kbd>+<kbd>Space</kbd> | both | Launcher |
| 8 | <kbd>&#63;</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#63;</kbd> | WM / both | Help |
| 9 | <kbd>n</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>c</kbd> | WM / both | New window |
| 10 | <kbd>x</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>x</kbd> | WM / both | Close window |
| 11 | <kbd>r</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>r</kbd> | WM / both | Rename window |
| 12 | <kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd> | WM | Focus (or snap, tiling off) by direction |
| 13 | <kbd>Alt</kbd>+arrows | TM | Focus by direction |
| 14 | <kbd>Ctrl</kbd>+<kbd>b</kbd> arrows | both | Focus by direction, repeatable |
| 15 | <kbd>H</kbd> <kbd>J</kbd> <kbd>K</kbd> <kbd>L</kbd> | WM | Swap with the neighbour |
| 16 | <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> | WM | Next / previous window |
| 17 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>n</kbd> / <kbd>p</kbd> | both | Next / previous window |
| 18 | <kbd>1</kbd>-<kbd>9</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>0</kbd>-<kbd>9</kbd> | WM / both | Jump to a window |
| 19 | <kbd>&#45;</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#45;</kbd> | WM / both | Split top/bottom |
| 20 | <kbd>&#124;</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#124;</kbd> | WM / both | Split left/right |
| 21 | <kbd>&#61;</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#61;</kbd> | WM / both | Equalize splits |
| 22 | <kbd>R</kbd> | WM | Rotate split |
| 23 | <kbd>&lt;</kbd> <kbd>&gt;</kbd> <kbd>&#123;</kbd> <kbd>&#125;</kbd> | WM | Resize width / height |
| 24 | <kbd>t</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>Space</kbd> | WM / both | Toggle tiling |
| 25 | <kbd>z</kbd> / <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>z</kbd> | WM / both | Zoom (fullscreen) the window |
| 26 | <kbd>m</kbd> / <kbd>M</kbd> | WM | Minimize / restore all |
| 27 | <kbd>Opt</kbd>/<kbd>Alt</kbd>+<kbd>1</kbd>-<kbd>9</kbd> | both | Switch workspace |
| 28 | <kbd>Opt</kbd>/<kbd>Alt</kbd>+<kbd>Shift</kbd>+<kbd>1</kbd>-<kbd>9</kbd> | both | Move window to workspace and follow |
| 29 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>1</kbd>-<kbd>9</kbd> | both | Switch workspace (any terminal) |
| 30 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#40;</kbd> / <kbd>&#41;</kbd> | both | Previous / next session |
| 31 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>S</kbd> | both | Session switcher |
| 32 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>d</kbd> | both | Detach (daemon session) |
| 33 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#91;</kbd> | both | Copy mode (then <kbd>&#47;</kbd> <kbd>&#63;</kbd> <kbd>v</kbd> <kbd>y</kbd>) |
| 34 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>F</kbd> | both | Hints: label and copy text |
| 35 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>g</kbd> | both | Scratch terminal |
| 36 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>b</kbd> / <kbd>s</kbd> | both / WM | Toggle / focus the sidebar |
| 37 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>i</kbd> | both | Inbox |
| 38 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>o</kbd> | both | Go to the oldest item that needs you |
| 39 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>k</kbd> | both | Keybind manager |
| 40 | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>&#44;</kbd> / <kbd>&#44;</kbd> | both / WM | Settings |

## Glossary

Chord
: A key with modifiers (`ctrl+shift+v`), or in this manual also a sequence of
  presses after the leader (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>w</kbd> <kbd>1</kbd>).

Command key
: A `[[keybindings.command]]` entry: a key that runs a command you write, as a
  scratch, popup, pane or windowless shell command.

Dead binding
: A binding that never runs because another action, earlier or later by the
  precedence rules, holds its key. Also *shadowed*.

Leader
: The prefix key, `keybindings.leader_key`, <kbd>Ctrl</kbd>+<kbd>b</kbd> by
  default.

Prefix repeat
: The window after a repeatable prefix command during which the second key can
  be pressed again without the leader (`appearance.prefix_repeat_time`).

Scope
: One keyboard context whose keys are looked up together. Conflicts exist only
  inside a scope.

Sub-prefix
: A menu opened by a key after the leader (`t`, `m`, `w`, `L`, `T`, `D`) with
  a section of its own.

Yielding default
: A newer default that stays unbound when your config already uses its key.
