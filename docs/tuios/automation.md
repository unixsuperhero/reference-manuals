---
title: "TUIOS: Tape Scripting, Recording, Screenshots and Scripted Workflows"
template: tuios-manual
manual: tuios
chapter: 8
summary: How to drive tuios without touching the keyboard, with tape scripts, recorded tapes, project tapes, screenshots and shell scripts built on the control commands.
tags:
  - tuios
  - automation
  - tape
  - scripting
  - screenshots
---

tuios can be driven by something other than your hands. A *tape* is a small
script of keystrokes and window-manager commands that tuios plays back in a
visible session. You can write one, record one, or keep one in a project
directory so that entering the directory builds your layout. Separately, every
part of a running session is reachable from a shell through commands such as
`tuios new-window`, `tuios send-text`, `tuios run` and `tuios wait-for`, which
is how you build scripts, CI helpers and hooks. This chapter covers all of it,
including screenshots, and ends with six complete scripts you can adapt.

## Choosing a mechanism

There are five ways to automate tuios. They overlap, but each has one job it
does best.

| Mechanism | Entry point | Runs where | Best for |
|---|---|---|---|
| Tape playback | `tuios tape play FILE` | A fresh, visible, standalone tuios started for the tape | Demos, reproducible walkthroughs, bug reproductions |
| Tape execution | `tuios tape exec FILE` | The attached client of a running daemon session | Replaying a short tape into the session you are already using |
| Tape recording | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>r</kbd> | In the TUI | Capturing what you just did, then editing it into a script |
| Project tapes | `.tuios.tape` in a directory | The focused shell's session, after you review it | A per-project layout built when you `cd` into the project |
| Control commands | `tuios new-window`, `send-text`, `run`, `wait-for`, ... | The daemon, attached or detached | Shell scripts, CI, hooks, agents |

::: tip
If you are writing a script that must work reliably, prefer the control
commands over tapes. They address windows by name or id, they work on a
detached session, they report what changed, and `tuios wait-for` blocks on
real events instead of guessing with `Sleep`. Tapes drive whichever window has
the focus, which is right for a demo and fragile for a build.
:::

## Tape scripting

### What a tape is

A tape is a plain text file, conventionally with the `.tape` extension, that
holds one command per line. Each command either sends input to the focused
window's terminal (`Type`, `Enter`, `Ctrl+C`), or performs a window-manager
action (`NewWindow`, `EnableTiling`, `SwitchWorkspace 2`), or controls playback
timing (`Sleep`, `WaitUntilRegex`). The language looks like the tape format of
Charm's VHS, and borrows its spelling, but it is tuios's own language with its
own parser (see [VHS and tuios tapes](#vhs-and-tuios-tapes)).

```tape
# hello.tape
DisableAnimations
NewWindow
Sleep 500ms
Type "echo Hello from TUIOS"
Enter
Sleep 1s
EnableAnimations
```

The upstream reference for the language lives at
<https://tuios.dev/docs/tape-scripting>; the repository's
[TAPE_SCRIPTING.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/TAPE_SCRIPTING.md)
points there. Everything below is checked against the v0.8.5 parser
(`internal/tape/lexer.go`, `parser.go`) and executor (`executor.go`), and the
example outputs come from running `tuios tape validate` on v0.8.5.

### The tape subcommands

There is one top-level command, `tuios tape`, with seven subcommands. There is
no `tuios --tape` flag and no `tape record` or `tape run` subcommand: recording
happens inside the TUI.

| Command | What it does |
|---|---|
| `tuios tape play <file.tape>` | Start a new, visible tuios and play the tape in it |
| `tuios tape exec <file.tape> [-s SESSION]` | Send the tape to a running daemon session and play it through that session's attached client |
| `tuios tape validate <file.tape>` | Parse the file, print every error, or print a numbered command summary |
| `tuios tape list` | List the tapes in the recordings directory, newest first, with size and date |
| `tuios tape show <name>` | Print a saved tape (by name, with or without `.tape`) |
| `tuios tape delete <name>` | Delete a saved tape after a `yes`/`no` prompt |
| `tuios tape dir` | Print the recordings directory |

```sh
tuios tape validate examples/demo.tape
tuios tape play examples/demo.tape
tuios tape exec --session work examples/simple.tape
tuios tape dir
```

#### tape play

`tuios tape play` reads and parses the whole file first. If there is any parse
error it prints the errors and exits without starting the TUI:

```text
Tape parsing errors:
  line 3: Sleep command expects a duration, got NUMBER
```

Otherwise it prints the command count and starts a tuios of its own.

The playback tuios is a fresh, **standalone** one (a local client, not the
daemon), so it touches none of your sessions, and it starts with no windows:
that is why almost every tape begins with `NewWindow`. It loads your
`config.toml`, accepts the appearance flags of `tuios` (`--theme`,
`--border-style`, `--show-keys`, `--no-animations` and the rest), and forces
animations off at start. Before each command it waits for running animations
and for any window the previous command asked for (up to 5 seconds), so a
`Type` after `NewWindow` lands in the new window. A failing command shows a
`Script error: ...` notification and playback goes on. When the tape ends,
tuios shows a completion indicator and stays open; quit it as usual.

::: tip
`--show-keys` is useful for recording a demo of a tape: the showkeys overlay
displays the keys the tape presses. `tuios tape play --show-keys --theme dracula demo.tape`
:::

During playback <kbd>Ctrl</kbd>+<kbd>p</kbd> pauses and resumes. It is the
`script_pause` action in `[keybindings.script]`, and it is live only while a
tape plays, which is why it can share <kbd>Ctrl</kbd>+<kbd>p</kbd> with the
command palette.

```toml
[keybindings.script]
script_pause = ["ctrl+p"]
```

#### tape exec

`tuios tape exec` sends the file's text to the daemon, which forwards it to the
TUI client attached to the target session. The tape then runs inside that
session, against its windows and focus.

```sh
tuios tape exec demo.tape                 # most recently active session
tuios tape exec --session mysession demo.tape
```

It differs from `tape play` in several ways:

| Behaviour | `tape play` | `tape exec` |
|---|---|---|
| Needs a daemon | No | Yes |
| Needs an attached client | It is the client | Yes: a headless session answers `tape scripts need an attached client. A headless daemon has no renderer to run them` |
| Parse errors | Reported, nothing runs | Unparseable lines are skipped; it refuses only a file with no commands at all (`tape script has no commands or contains errors`) |
| `Sleep` | Honoured | Honoured |
| `Wait` | Honoured, same as `Sleep` | Skipped (no delay) |
| `WaitUntilRegex` | Blocks until match or timeout | Skipped |
| Gap between commands | Paced by the render loop | 50 ms after each command |

::: warning
Because `tape exec` skips `Wait` and `WaitUntilRegex`, a tape that relies on
them for correctness runs too fast under `exec`. Use `Sleep` for delays you
need under both, or validate the tape with `tape play` and drive the live
session with control commands instead.
:::

From inside a tuios pane, `tape exec` is held to the pane's grants. A pane
without the `respond` grant may not run a tape that types or presses keys
(`Type`, `Enter`, the key commands, key combinations, `Source` and
`LoadLayout`), because the client types into whatever pane has the focus. The
refusal names the reason and suggests `send-keys` or `send-text` with a window.
See [Agents](agents.md) for grants.

#### tape validate

`validate` parses the file and nothing more. On success it prints the count and
a numbered summary of how each line was understood, which is the fastest way to
see what the parser kept and what it dropped:

```sh
tuios tape validate examples/simple.tape
```

```text
✓ Tape file is valid
  File: examples/simple.tape
  Commands: 7

  Command Summary:
    [1] DisableAnimations []
    [2] NewWindow []
    [3] Sleep [500ms]
    [4] Type ["echo Hello from TUIOS"]
    [5] Enter []
    [6] Sleep [1s]
    [7] EnableAnimations []
```

On failure it prints each error with its line number and exits non-zero:

```text
Parsing errors found:
  ✗ line 1: unexpected token: IDENTIFIER
  ✗ line 3: Sleep command expects a duration, got NUMBER
  ✗ line 4: Type command expects a string, got IDENTIFIER
tape file has parsing errors
```

### Lexical rules

The rules below are what the v0.8.5 lexer and parser do.

| Rule | Detail |
|---|---|
| One command per line | A newline ends a command. Anything left on the line after the command's arguments is silently ignored, so `Type "ls" Enter` types `ls` and drops the `Enter`. |
| Comments | `#` starts a comment that runs to the end of the line, anywhere outside a string. Blank lines are ignored. |
| Keywords | Case-insensitive: `Type`, `type` and `TYPE` are the same command. |
| Strings | Double quotes `"..."`, single quotes `'...'` or backticks `` `...` ``. |
| Escapes in strings | `\n` `\t` `\r` `\\` `\"` `\'` `` \` `` `\a` `\b` `\f` `\v`, plus `\xHH` (one byte), `\uHHHH` and `\UHHHHHHHH` (one Unicode code point). An unknown escape keeps the letter: `\q` is `q`. |
| Durations | A number with a Go duration unit: `500ms`, `2s`, `1.5s`, `1m`, `1m30s`, `1h`. A bare number is not a duration: `Sleep 500` is an error. |
| Numbers | Digits with an optional decimal part: `3`, `2000`. |
| Delay modifier | `@<duration>` right after the keyword: `Type@100ms "x"`, `Enter@200ms`. See the note below. |
| Repeat count | A number after a key command repeats it: `Down 5`, `Backspace 10`. |
| Identifiers | Letters, digits and `_`. A `.` or `-` ends an identifier, so quote file and layout names that contain them. |

::: note
**The `@` delay modifier parses but has no effect in v0.8.5.** The parser
stores it, but playback uses a command's delay only for `Sleep` and `Wait`. A
`Type@1s "hello"` line sends `hello` in one write, immediately. Use an explicit
`Sleep` between commands to pace a demo.
:::

### Command quick reference

Every command the v0.8.5 parser accepts in a tape file:

| Command | Syntax | What it does |
|---|---|---|
| `Type` | `Type "text"` | Write the text to the focused window's terminal |
| `Enter` | `Enter [N]` | Send a newline (`\r\n` on Windows) |
| `Space` | `Space [N]` | Send a space |
| `Backspace` | `Backspace [N]` | Send `\b` |
| `Delete` | `Delete [N]` | Send `ESC [ 3 ~` |
| `Tab` | `Tab [N]` | Send `\t` |
| `Escape` | `Escape [N]` | Send `ESC` |
| `Up` `Down` `Left` `Right` | `Up [N]` | Send the cursor key (`ESC [ A` ... `ESC [ D`) |
| `Home` `End` | `Home [N]` | Send `ESC [ H` / `ESC [ F` |
| Key combination | `Ctrl+c`, `Alt+x`, `Ctrl+Alt+x`, `Shift+a`, `Alt+1` | Send the key's bytes; `Alt+1`..`Alt+9` switch workspace |
| `Sleep` | `Sleep <duration>` | Pause playback |
| `Wait` | `Wait <duration>` | Same as `Sleep` (skipped by `tape exec`) |
| `WaitUntilRegex` | `WaitUntilRegex "regex" [timeout_ms]` | Block until the focused window's screen matches, or the timeout (default 5000) passes |
| `TerminalMode` | `TerminalMode` | Switch to terminal mode |
| `WindowManagementMode` | `WindowManagementMode` | Switch to window-management mode |
| `NewWindow` | `NewWindow` | Open a new window |
| `CloseWindow` | `CloseWindow` | Close the focused window |
| `NextWindow` / `PrevWindow` | `NextWindow` | Cycle focus |
| `FocusWindow` | `FocusWindow <name-or-id>` | Focus a window by name, else by full id |
| `RenameWindow` | `RenameWindow "name"` | Name the focused window |
| `MinimizeWindow` | `MinimizeWindow` | Minimize the focused window |
| `RestoreWindow` | `RestoreWindow` | Restore the focused window |
| `ToggleTiling` / `EnableTiling` / `DisableTiling` | `EnableTiling` | Tiling on, off, or flipped |
| `SnapLeft` / `SnapRight` / `SnapFullscreen` | `SnapLeft` | Snap the focused window |
| `Split` | `Split` | Parses, but fails when run (see [Split](#tiling-and-layout)) |
| `RotateSplit` | `RotateSplit` | Flip the axis of the split holding the focused pane |
| `EqualizeSplits` | `EqualizeSplits` | Reset every split ratio |
| `ToggleZoom` | `ToggleZoom` | Zoom or unzoom the focused window |
| `SmartSplit` | `SmartSplit` | Split the focused pane along its longer side (tiling only) |
| `SwitchWorkspace` | `SwitchWorkspace N` | Show workspace N |
| `MoveToWorkspace` | `MoveToWorkspace N` | Move the focused window to workspace N |
| `MoveAndFollowWorkspace` | `MoveAndFollowWorkspace N` | Move it there and follow |
| `SaveLayout` / `LoadLayout` | `SaveLayout name` | Save or apply a layout template |
| `CommandPalette` | `CommandPalette` | Open the command palette |
| `Screenshot` | `Screenshot` | Render the focused window to an image file |
| `EnableAnimations` / `DisableAnimations` / `ToggleAnimations` | `DisableAnimations` | Animation switch |
| `Set` | `Set key value` | Parses, does nothing |
| `Output` | `Output file` | Parses, does nothing |
| `Source` | `Source "file.tape"` | Parses, does nothing |
| `Focus` | `Focus name` | Parses, does nothing (use `FocusWindow`) |

The sections below give each command's arguments, behaviour and an example.

### Typing and keys

#### Type

```text
Type "text"
```

`Type` writes the string to the focused window's terminal, byte for byte, in
one write. It needs a string; `Type hello` (no quotes) is the error
`Type command expects a string, got IDENTIFIER`. It does not press Enter.

```tape
Type "git status"
Enter
Type "printf 'a\\tb\\n'"   # \\ in the tape is one backslash for the shell
Enter
```

::: note
`Type` and the key commands write straight to the focused window's terminal,
whatever mode tuios is in, so a tape does not need `TerminalMode` for its text
to arrive. The shipped examples still bracket typing with `TerminalMode` and
`WindowManagementMode`, which keeps the on-screen mode indicator honest and
leaves tuios in the right mode for a person who takes over after the tape. The
mode does matter when real keys are pressed: under VHS, or with
`tuios send-keys` without `-w`, text typed in window-management mode is read as
tuios keybindings (`t` toggles tiling, and so on).
:::

#### Enter, Space, Backspace, Delete, Tab, Escape and the cursor keys

Each sends the fixed byte sequence listed in the
[quick reference](#command-quick-reference) to the focused window, once, or N
times with a trailing count.

```tape
Type "hello wrold"
Backspace 5
Type "world"
Enter
Up 2          # recall the command from two lines back
Escape
```

::: note
The cursor keys are always sent in normal mode (`ESC [ A`). A program that
switched on application cursor keys (vim, less) accepts these anyway in most
cases. `tuios send-keys` is smarter here: it sends the form the program asked
for.
:::

#### Key combinations

```text
Ctrl+<key>   Alt+<key>   Shift+<key>   Ctrl+Alt+<key>   Opt+<key>
```

A key combination is one or more modifiers joined to a final key with `+`. The
final key may be a letter, a digit, an identifier such as `space` or `enter`,
or `Enter`, `Space` and the cursor-key keywords. Modifiers are
case-insensitive, and `Opt` is a synonym for `Alt`.

The combination is converted to bytes and written to the focused window:

| Combination | Bytes |
|---|---|
| `Ctrl+<letter>` | The control character: `Ctrl+c` is 0x03, `Ctrl+b` is 0x02 |
| `Ctrl+<digit>` | The digit AND 0x1f |
| `Alt+<char>` | `ESC` then the character |
| `Shift+<char>` | The upper-case character |
| `Alt+space`, `Alt+enter`, ... | `ESC` then the named key's byte |
| `Ctrl+space`, `Ctrl+enter`, ... | The named key's byte (the Ctrl is dropped) |
| `Ctrl+Up`, `Alt+Home`, ... | The key's name as text (`Up`), since only the names `space`, `enter`, `return`, `tab`, `escape`, `esc`, `backspace` and `delete` are mapped. Avoid these |
| `Alt+1` ... `Alt+9` | Not sent: switches to that workspace |

```tape
Type "sleep 100"
Enter
Sleep 1s
Ctrl+c          # interrupt it
Ctrl+l          # clear the screen
Alt+2           # go to workspace 2
```

::: warning
A key combination is sent **to the program in the focused window**, never to
tuios: `Ctrl+b` is the byte 0x02 for the shell, not the tuios leader, so a tape
cannot open a prefix menu. Use the tape commands for tuios actions, or
`tuios send-keys "PREFIX n"` (no `-w`) from a shell. And `Shift+Tab` does not
parse in v0.8.5 (`expected key after modifier, got Tab`); send a back-tab with
`tuios send-keys -w NAME BTab`.
:::

### Timing and waiting

#### Sleep and Wait

```text
Sleep <duration>
Wait <duration>
```

Both pause playback for the duration. `Wait` is an alias kept for
compatibility, with one difference: `tape exec` skips it. A bare number is an
error (`Sleep command expects a duration, got NUMBER`).

```tape
Sleep 300ms
Sleep 2s
Sleep 1m30s
Wait 500ms
```

#### WaitUntilRegex

```text
WaitUntilRegex "pattern" [timeout_ms]
```

`WaitUntilRegex` blocks playback until the **visible screen of the focused
window** matches a Go regular expression (RE2 syntax), or until the timeout
passes. The timeout is an optional integer number of milliseconds; it defaults
to 5000. A timeout is not fatal: tuios shows a `WaitUntilRegex: timed out`
warning and continues with the next command. An invalid pattern shows
`WaitUntilRegex: invalid pattern: ...` and the command is skipped without
waiting.

```tape
Type "make build"
Enter
WaitUntilRegex "Build (succeeded|failed)" 120000
```

The pattern must be a quoted string (`WaitUntilRegex /ready/` is a parse
error). It is matched against the window's **visible screen**, not its
scrollback, so a line that scrolled off no longer matches. String escapes are
processed first: write `"\\$"` for the regex `\$` and `"\\d+"` for `\d+`.
`tape exec` skips the command.

::: tip
Because the typed command is itself on screen, waiting for a word it contains
matches immediately. Wait for something only the output can contain, such as
`"^ok "` or `"[0-9]+ passed"`. The same trap exists for `tuios wait-for`;
[the marker section](#markers-and-the-one-trap-in-window-output) shows the
general fix.
:::

### Modes

```text
TerminalMode
WindowManagementMode
```

`TerminalMode` switches to terminal mode (and focuses the first
non-minimized window if none is focused); `WindowManagementMode` switches to
window-management mode. See [Concepts](concepts.md) for the modes, and the note
under [Type](#type) for why tapes bracket typing with them.

### Windows

`NewWindow` waits (up to 5 s) for the window to exist before the next command
runs. `FocusWindow` tries a window name first, then a full window id; an id that
matches nothing does nothing, silently. `RenameWindow` takes a quoted string or
a bare word. `CloseWindow`, `MinimizeWindow` and `RestoreWindow` act on the
focused window.

```tape
NewWindow
RenameWindow "server"
TerminalMode
Type "python3 -m http.server 8000"
Enter
WindowManagementMode
NewWindow
RenameWindow "client"
FocusWindow server
```

::: note
In a tape file these commands take only the arguments shown. `NewWindow "name"`
and `CloseWindow "name"` parse, but the name is discarded. The forms with a
name (`NewWindow [name]`, `CloseWindow [name]`, `MinimizeWindow [name]`,
`RestoreWindow [name]`, `RenameWindow <old> <new>`) exist only through
`tuios run-command`. `FocusWindow` takes a bare word, so a name with spaces or
dots cannot be focused from a tape; use a simple name.
:::

### Tiling and layout

`SmartSplit` splits the focused pane along its longer side and fails with
tiling off. `SnapLeft`, `SnapRight` and `SnapFullscreen` act on a floating
window. `SaveLayout NAME` saves a layout template and `LoadLayout NAME` applies
one; an unknown name shows `layout template not found: NAME`.

```tape
EnableTiling
NewWindow
NewWindow
SmartSplit
EqualizeSplits
SaveLayout dev
DisableTiling
LoadLayout "dev"
```

::: warning
**`Split` does not work in a tape file in v0.8.5.** The executor needs a
direction (`horizontal`/`h` or `vertical`/`v`), but the tape parser keeps only a
number after `Split`, so `Split vertical` reaches the executor with no argument
and fails with `Script error: Split needs horizontal or vertical`. Use
`SmartSplit` or `NewWindow` with tiling on inside a tape, and
`tuios run-command Split vertical` or `tuios split-window vertical` from a
shell. (The project-tape body language, which has its own parser, does accept
`Split vertical`; see [Project tapes](#project-tapes).)
:::

### Workspaces

```text
SwitchWorkspace N
MoveToWorkspace N
MoveAndFollowWorkspace N
```

Each takes a workspace number. A missing or non-numeric argument is a parse
error (`SwitchWorkspace expects a number, got IDENTIFIER`). `MoveToWorkspace`
moves the focused window and stays; `MoveAndFollowWorkspace` moves it and
switches to that workspace. `Alt+N` for N in 1 to 9 is a shorthand for
`SwitchWorkspace N`.

```tape
SwitchWorkspace 2
NewWindow
MoveAndFollowWorkspace 1
```

### Interface commands

Recorded tapes start with `DisableAnimations` and end with
`EnableAnimations`. `CommandPalette` opens the palette for a demo that shows
it. `Screenshot` renders the focused window under `screenshot.directory` with
the `[screenshot]` options, and the file exists before the next command runs,
so a later command can use it.

```tape
NewWindow
TerminalMode
Type "ls --color=always"
Enter
Sleep 500ms
Screenshot
```

### Commands that parse and do nothing

Some VHS keywords are accepted so that a VHS-flavoured file still parses, but
the v0.8.5 executor has no action for them. They are silently ignored at
playback.

| Command | Parses as | Effect |
|---|---|---|
| `Set <key> <value>` | `Set Theme dracula` | None. Use `tuios --theme` or `run-command SetTheme` |
| `Output <file>` | `Output demo.gif` (the identifier stops at the `.`, so it keeps `demo`) | None. tuios does not render video |
| `Source <file>` | `Source "other.tape"` | None. A tape cannot include another tape |
| `Focus <name>` | `Focus editor` | None. A quoted name is a parse error. Use `FocusWindow` |

::: warning
Because these lines are accepted, `tuios tape validate` reports them as valid.
Do not read a passing validation as proof that every line will do something.
:::

### Commands that only run-command reaches

The executor knows more commands than the tape parser does. These have no tape
keyword in v0.8.5 and run only through `tuios run-command` (or the
`run-command` verb):

`Split horizontal|vertical`, `ArrangePanes tiled|even-horizontal|even-vertical
[workspace [window...]]`, `SetMultifocus [window...]`,
`SetMasterPosition left|right|top|bottom|center`, `SetMasterCount 1-9`,
`CycleMasterPosition`, `AddMaster`, `RemoveMaster`, `SwapWithMaster`,
`FocusMaster`, `SetTheme NAME`, `SetDockbarPosition bottom|top|hidden`,
`SetBorderStyle STYLE`, `ShowNotification MESSAGE [TYPE]`, and the read-only
`ListWindows`, `GetWindow [id-or-name]` and `GetSessionInfo` (best with
`--json`). The name-taking forms of the window commands (`NewWindow [name]`,
`CloseWindow [name]`, `RenameWindow <old> <new>`) are run-command only too.

```sh
tuios run-command Split vertical
tuios run-command ArrangePanes even-horizontal
tuios run-command ShowNotification "Deploy finished" success
tuios run-command --list
```

`run-command` also accepts the keymap's spelling of a name: `toggle_tiling`,
`toggletiling` and `ToggleTiling` resolve to the same command. A name that is
none of these is an error rather than a silent no-op.

### The shipped examples

The source tree ships tapes in `examples/`. All of them pass
`tuios tape validate` on v0.8.5:

| File | Commands | What it shows |
|---|---|---|
| `simple.tape` | 7 | The minimum: one window, one command |
| `demo.tape` | 51 | Modes, windows, tiling, workspaces, minimize and restore |
| `with_waituntil_regex.tape` | 17 | Waiting on output instead of sleeping |
| `tapeception.tape` | 6 | A tape that plays itself inside itself |
| `advanced_demo.tape` | 87 | A longer tour |
| `nvim_demo.tape` | 20 | Driving Neovim |
| `vim_workflow.tape` | 88 | A longer editor session |
| `stress_test.tape` | 77 | Many windows and actions, for testing |

#### simple.tape

```tape
# Simple TUIOS Tape Script            (comment lines trimmed)
DisableAnimations
NewWindow
Sleep 500ms
Type "echo Hello from TUIOS"
Enter
Sleep 1s
EnableAnimations
```

Line by line:

1. `DisableAnimations`: playback already starts with animations off, so this
   is belt and braces; it also makes the tape behave the same under
   `tape exec` in a session that has animations on.
2. `NewWindow`: a `tape play` session starts empty, so the tape opens a window.
   Playback holds the next command until the window exists.
3. `Sleep 500ms`: gives the new shell time to print its prompt.
4. `Type "echo Hello from TUIOS"`: writes the text to the focused window,
   which is the new one. No `TerminalMode` is needed, because tape typing goes
   straight to the window's terminal.
5. `Enter`: runs it.
6. `Sleep 1s`: leaves the output on screen.
7. `EnableAnimations`: restores animations for whatever you do next in that
   tuios.

```sh
tuios tape play examples/simple.tape
```

#### demo.tape

The full file is 94 lines. Its structure, with the `Sleep` lines (300 ms to 1 s
after almost every command) and comments left out:

```tape
DisableAnimations
WindowManagementMode       # 1. start from a known mode
NewWindow                  # 2. window 1, run two commands
TerminalMode
Type "echo 'Window 1 - Terminal Emulation Demo'"
Enter
Type "ls -la"
Enter
WindowManagementMode       # 3. back to tuios, window 2
NewWindow
TerminalMode
Type "echo 'Window 2 - Workspace Demo'"
Enter
Type "pwd"
Enter
WindowManagementMode       # 4. tile and move focus
EnableTiling
NextWindow
PrevWindow
SwitchWorkspace 2          # 5. a window on workspace 2
NewWindow
TerminalMode
Type "echo 'Workspace 2 - Tiled Window'"
Enter
WindowManagementMode
MoveAndFollowWorkspace 1   # 6. carry it back to workspace 1
MinimizeWindow             # 7. minimize and restore
RestoreWindow
NextWindow                 # 8. finish
EnableAnimations
```

1. The tape fixes its starting mode with `WindowManagementMode` so it does not
   depend on `startup.start_in_terminal_mode`.
2. Every block of typing is bracketed: `TerminalMode` before, and
   `WindowManagementMode` after, so the mode shown on screen matches what the
   demo is doing. This is the pattern to copy for demos.
3. A second window opens and takes the focus.
4. `EnableTiling` lays both windows out side by side; `NextWindow` and
   `PrevWindow` move the focus and back.
5. `SwitchWorkspace 2` shows an empty workspace; the new window lands there.
6. `MoveAndFollowWorkspace 1` moves the focused window to workspace 1 and
   switches with it, so workspace 1 now tiles three windows.
7. `MinimizeWindow` sends the focused window to the dock, and `RestoreWindow`
   brings back the focused window.
8. The trailing sleeps hold the final frame.

#### with_waituntil_regex.tape

```tape
# TUIOS Demo with WaitUntilRegex      (comment lines trimmed)
DisableAnimations
WindowManagementMode
NewWindow
Sleep 500ms
TerminalMode
Type "echo 'Starting test'"
Enter
WaitUntilRegex "test" 3000
Type "ls -la"
Enter
WaitUntilRegex "\\$" 5000
Type "pwd"
Enter
WaitUntilRegex "/.*"
Type "exit"
Enter
EnableAnimations
```

1. A window opens, the tape enters terminal mode and runs an `echo`.
2. `WaitUntilRegex "test" 3000` waits up to 3 seconds for `test` on screen.
   Note that the typed command line `echo 'Starting test'` already contains
   `test`, so in practice this matches at once. It is a syntax demonstration
   more than a real gate.
3. `WaitUntilRegex "\\$" 5000`: the tape string `"\\$"` becomes the regex
   `\$`, a literal dollar sign, meant to catch a `$` prompt. On a prompt
   without `$` (fish's `>`, or a powerline prompt) it waits the full 5 seconds,
   warns and continues.
4. `WaitUntilRegex "/.*"` uses the default 5000 ms timeout and matches any
   slash on screen, which a path from `pwd` produces.
5. `Type "exit"` and `Enter` end the shell, which closes the window.

#### tapeception.tape

```tape
EnableTiling
NewWindow
Sleep 1s
Type "./tuios tape play ./examples/tapeception.tape"
Enter
Sleep 1s
```

1. `EnableTiling` tiles the session.
2. `NewWindow` and `Sleep 1s` open a shell and let it start.
3. `Type "./tuios tape play ./examples/tapeception.tape"` and `Enter` run tuios
   **inside** that window, playing the same tape. That nested tuios does the
   same thing, and so on: each level is a full tuios drawn inside a pane of the
   level above.
4. `Sleep 1s` ends the outer tape; the inner ones keep going.

It expects to be started from the root of a source checkout with a built
`./tuios` binary. It never terminates on its own; press
<kbd>Ctrl</kbd>+<kbd>c</kbd> in the outermost terminal to stop it. It is a fun
stress test of nested terminal emulation, and a good demonstration that a tape
types into whatever runs in the pane.

```sh
go build -o tuios ./cmd/tuios
./tuios tape play ./examples/tapeception.tape
```

### VHS and tuios tapes

tuios tapes share their look with the `.tape` files of
[VHS](https://github.com/charmbracelet/vhs), Charm's terminal recorder:
`Type`, `Sleep`, `Enter`, `Ctrl+C`, `Backspace 5`, `Set` and `Output` mean the
same kind of thing. They are still two different programs:

The VHS-only keywords `Output`, `Set` and `Source` parse in tuios and do
nothing; `Require`, `Hide` and `Show` are parse errors; and VHS has none of the
window-manager commands. VHS renders a terminal to GIF, MP4 or WebM; a tuios
tape drives a live tuios.

To make a video of tuios, run tuios under VHS. The tuios repository does this
for its README recording (`assets/demo.tape`, rendered by
`assets/record-demo.sh`), with a VHS tape whose `Type` lines start `tuios` and
press its keys. Inside such a recording you can also call
`tuios tape play` to let a tuios tape do the window choreography while VHS
records the frames.

::: note
The upstream recording notes one limit worth knowing: VHS has no `Alt+Space` or
`Alt+Escape`, so the tuios bindings on those keys cannot be pressed from a VHS
tape. The README demo opens the launcher from the command palette instead.
:::

## Tape recording

Recording turns what you do in the TUI into a tape you can replay and edit. It
is in-app only; the upstream guide is
<https://tuios.dev/docs/tape-recording>.

### Keys

All recording keys live under the tape prefix, <kbd>Ctrl</kbd>+<kbd>b</kbd>
<kbd>T</kbd> (capital T), in `[keybindings.tape_prefix]`:

| Keys | Action | What it does |
|---|---|---|
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>r</kbd> | `tape_prefix_record` | Open the naming prompt, then start recording |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>s</kbd> | `tape_prefix_stop` | Stop and save the recording |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>m</kbd> | `tape_prefix_manager` | Open the tape manager |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>t</kbd> | `tape_prefix_review` | Review the project tape (see [Project tapes](#project-tapes)) |
| <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>Esc</kbd> | `tape_prefix_cancel` | Leave the prefix |

::: example
**Example: record a short session**

Press <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>r</kbd>. A prompt offers a
name such as `recording_20261007_142530`; edit it to `git-tour` and press
<kbd>Enter</kbd>. A `Recording started: git-tour` notification appears and, if
a window is focused, tuios enters terminal mode. Type
`git log --oneline -5`, press <kbd>Enter</kbd>, switch to workspace 2 and back,
then press <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>s</kbd>:
`Recording saved: git-tour.tape`. `tuios tape show git-tour` prints it.
:::

Pressing record while already recording shows `Already recording`; stop while
not recording shows `Not recording`. <kbd>Esc</kbd> in the naming prompt goes
back to the manager's list without recording.

### What is recorded

The recorder captures three kinds of event, and it writes the time between
events as `Sleep` lines.

| You do | Recorded as |
|---|---|
| Type printable characters in terminal mode | Accumulated into one `Type "..."` per run of characters |
| Press Enter, Space, Backspace, Delete, Tab, Esc, arrows, Home, End | `Enter`, `Space`, `Backspace`, `Delete`, `Tab`, `Escape`, `Up`... |
| Press another key with Ctrl, Alt or Shift | A key combination line, such as `ctrl+c` |
| Switch mode | `TerminalMode` or `WindowManagementMode` |
| Switch workspace | `SwitchWorkspace N` |
| New, close, next, previous, minimize, restore-all window actions | `NewWindow`, `CloseWindow`, `NextWindow`, `PrevWindow`, `MinimizeWindow`, `RestoreWindow` |
| Toggle tiling, snap left, right or fullscreen | `ToggleTiling`, `SnapLeft`, `SnapRight`, `SnapFullscreen` |
| Select window N | `FocusWindow N` |

At the start the recorder writes the state you were in, so replay starts from
the same place: `SwitchWorkspace N` when you were not on workspace 1, then
`EnableTiling` or `DisableTiling`, then `TerminalMode` or
`WindowManagementMode`.

Not recorded: mouse actions, other window-manager actions (splits, renames,
zoom, layouts, the palette, settings), anything you type into a tuios panel,
and keys while the tape manager is open. A delay is written only when it is
over 100 ms.

### The file a recording produces

A recording is wrapped in a header, a `DisableAnimations` at the top and an
`EnableAnimations` at the bottom. A short recording looks like this (timings
vary):

```tape
# git-tour
# Recorded: 2026-10-07T14:25:30-07:00

# Disable animations for consistent playback
DisableAnimations

DisableTiling
TerminalMode
Sleep 1.204517823s
Type "git log --oneline -5"
Enter
Sleep 2.51209177s
SwitchWorkspace 2
Sleep 900.330125ms
SwitchWorkspace 1

# Re-enable animations
EnableAnimations
```

Sleeps carry Go's full duration precision, which is why they look like
`1.204517823s`; round them when you edit. `Type` lines are written with Go's
`%q` quoting, so quotes, backslashes and
non-printable characters round-trip through the `\"`, `\\`, `\xHH` and `\uHHHH`
escapes the lexer reads.

### Where recordings live

Recordings are saved as `NAME.tape` (mode 0600) in the tuios data directory,
which `tuios tape dir` prints:

| Platform | Directory |
|---|---|
| Linux | `$XDG_DATA_HOME/tuios`, usually `~/.local/share/tuios` |
| macOS | `~/Library/Application Support/tuios` |

`tape list`, `show`, `delete` and the tape manager see only files ending in
`.tape` directly in that directory. A name may be given with or without the
extension. `tape delete` asks `Delete 'git-tour'? (yes/no):` and accepts `yes`
or `y`.

### The tape manager

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>m</kbd> opens a panel that lists
the saved tapes. While recording, its title reads `recording NAME`.

| Key | What it does |
|---|---|
| <kbd>Up</kbd> <kbd>Down</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>g</kbd> <kbd>G</kbd> <kbd>PgUp</kbd> <kbd>PgDn</kbd> | Move, as in every tuios list |
| <kbd>Enter</kbd> | Play the selected tape in this session |
| <kbd>r</kbd> | Start a new recording (opens the naming prompt) |
| <kbd>d</kbd> | Delete the selected tape; <kbd>y</kbd> confirms, <kbd>n</kbd> or <kbd>Esc</kbd> cancels |
| <kbd>Esc</kbd> <kbd>q</kbd> | Close the manager |

Playing from the manager uses the same playback loop as `tape play`, including
`WaitUntilRegex` and <kbd>Ctrl</kbd>+<kbd>p</kbd> to pause, but it runs in the
session you are in, against its windows.

### Editing a recording into a script

A raw recording replays your exact timing and your exact typos. Turning it into
a script that works every time is a short edit. Copy it out of the data
directory first:

```sh
cp "$(tuios tape dir)/git-tour.tape" ./git-tour.tape
$EDITOR git-tour.tape
tuios tape validate git-tour.tape
tuios tape play git-tour.tape
```

::: example
**Example: from recording to script**

Before (as recorded):

```tape
DisableAnimations

DisableTiling
TerminalMode
Sleep 1.204517823s
Type "git lgo"
Backspace
Backspace
Type "og --oneline -5"
Enter
Sleep 4.871602114s
Type "git status"
Enter

EnableAnimations
```

After:

```tape
# git-tour: a reproducible two-command tour
DisableAnimations
NewWindow                      # tape play starts empty
Sleep 500ms
TerminalMode
Type "git log --oneline -5"    # typo and corrections removed
Enter
WaitUntilRegex "[0-9a-f]{7} " 5000   # wait for a short hash, not a guess
Sleep 1s
Type "git status"
Enter
WaitUntilRegex "On branch|HEAD detached" 5000
Sleep 2s
EnableAnimations
```

The edits: add `NewWindow`, merge the typo run into one `Type`, and replace
long recorded sleeps with `WaitUntilRegex`.
:::

## Project tapes

A project tape is a file named `.tuios.tape` in a project directory. When the
focused shell inside tuios enters a directory that holds one, tuios can build a
session and layout for the project from it, the way a `.envrc` works for
direnv. The full upstream description is
[PROJECT_TAPES.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/PROJECT_TAPES.md).

A tape is arbitrary command execution (`Type "curl x | sh" Enter` is a legal
tape), so the feature is built around one rule: **an untrusted tape is
inert**. tuios only stats it, reads it once, hashes it and shows it to you.
Nothing runs until you have read it and chosen to run or trust it.

### Quick start

```text
# ~/src/myproject/.tuios.tape
Session "myproject"
Require "pnpm"

RenameWindow "edit"
Type "nvim ." Enter

Split vertical
RenameWindow "serve"
Run "pnpm dev"

Split horizontal
RenameWindow "sh"

Focus "edit"
```

1. In a tuios pane, `cd ~/src/myproject`. About 400 ms later a passive banner
   slides in and a `tape ?` badge appears in the dock. Nothing has run, and
   your shell did not lose a keystroke.
2. Press <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>T</kbd> <kbd>t</kbd>, or choose
   **Tape: review the project tape** in the command palette. The review dialog
   shows the canonical path, the trust status (including "changed since you
   trusted it"), a one-line summary such as `session "myproject"` from a header
   parse that executes nothing, and the **full content**, scrollable with
   <kbd>Up</kbd> and <kbd>Down</kbd>. You approve what you can see.
3. Choose: <kbd>r</kbd> **Run once** (remember nothing), <kbd>t</kbd> **Trust
   and run** (remember this exact file), <kbd>n</kbd> **Never** (never prompt
   for this path), or <kbd>Esc</kbd> **Not now** (the badge stays).
4. On later visits the badge reads `tape ✓`, and one keypress runs it, which,
   once the session exists, just switches you to it.

The dialog opens only when you ask for it, or on detection with
`auto_review = true`. It never steals focus because you typed `cd`.

### The trust model

Trust is granted per pair of **canonical path and content hash**, as direnv
does. The path is the `realpath` of the tape and the hash is the SHA-256 of its
bytes, so **any edit reverts the tape to untrusted**: a `git pull` that changes
a trusted tape shows up as a "changed since you trusted it" prompt, never as a
silent run. tuios reads the file once, and hashes, shows and runs that same
buffer, so swapping the file or a symlink target after you approve changes
nothing. Decisions live in `$XDG_DATA_HOME/tuios/tape-trust.toml` (mode 0600),
which is per-machine state; do not sync it with your dotfiles.

| Status | Cause | What you see |
|---|---|---|
| Untrusted | Never decided, or edited since trusted | Banner, badge, dialog on request |
| Trusted | Trust and run on these exact bytes | `tape ✓`; runs on a keypress, or on entry in `auto` |
| Denied | **Never**, keyed by path only, so edits do not re-prompt | Nothing at all |
| Ineligible | Fails a hygiene check | A passive notice; the dialog offers only *Dismiss*, with no override |

A tape is eligible only if it is a regular file after symlink resolution, owned
by you, not group- or world-writable, has no world-writable directory without
the sticky bit on its path, and is at most 64 KiB, the way `sshd` checks
`authorized_keys`.

### Configuration: the [tape] table

| Option | Type | Default | Meaning |
|---|---|---|---|
| `tape.autorun` | `off`, `ask`, `auto` | `ask` | What happens on entering a directory with a project tape |
| `tape.auto_review` | bool | `false` | Open the review dialog on detection instead of only showing the badge |

```toml
[tape]
autorun = "ask"        # off | ask | auto
auto_review = false
```

- **`off`**: no scanning, no badge; the feature is invisible.
- **`ask`**: every encounter shows the banner and badge (or, with
  `auto_review`, opens the dialog); nothing runs until you choose.
- **`auto`**: a trusted, unedited tape runs on entry with no dialog. An
  untrusted or changed tape behaves exactly as under `ask`. No mode runs
  content you have not reviewed, and a denied tape stays silent in every mode.

The dialog auto-opens at most once per directory per session, only for the
focused window, and never while a tape runs. The environment variable
`TUIOS_TAPE_AUTORUN` overrides the option for one run, for CI or for reading
code you do not trust:

```sh
TUIOS_TAPE_AUTORUN=off tuios attach work
```

### The header

Optional declarative directives at the very top, before any body command. A
directive after the first body command is treated as body.

| Directive | Meaning | Default |
|---|---|---|
| `Session "name"` | The session to build or switch to | The project directory's basename |
| `Scope session` or `Scope current` | Where the tape runs | `session` |
| `Workspace N` | The workspace to build in | none |
| `Require "command"` | Skip the whole tape, with a notice, if the binary is not on `PATH` | none |

### The body language

The body is a small layout language with its own line parser, not the
recorder language above. One command per line, keywords case-insensitive,
`#` comments, blank lines and unknown commands ignored:

| Command | Effect |
|---|---|
| `Type "text" [Enter]` | Type into the focused pane; a trailing `Enter` submits it |
| `Run "cmd"` | Shorthand for `Type "cmd" Enter` |
| `Enter` | Submit a line |
| `Split vertical` or `Split horizontal` | Split the focused pane (`v` and `h` work; no argument means vertical) |
| `NewWindow ["name"]` | Create a new tiled pane |
| `RenameWindow "name"` (alias `Rename`) | Name the focused pane |
| `Focus "name"` (alias `FocusWindow`) | Focus a pane by name |
| `Sleep <duration>` (alias `Wait`) | Pause, for example `500ms` |
| `EnableTiling` / `DisableTiling` | Toggle tiling |

After every `Split` and `NewWindow`, tuios inserts a 900 ms settle delay so the
new pane is ready before the next command types into it.

::: warning
The two tape languages differ exactly where it hurts:

| Line | In `.tuios.tape` | In a `tape play` file |
|---|---|---|
| `Type "ls" Enter` | Types and submits | Types; `Enter` dropped |
| `Split vertical` | Splits | Fails: `Split needs horizontal or vertical` |
| `Focus "edit"` | Focuses `edit` | Parse error |
| `Run "make"` | Types and submits | Parse error |
| `WaitUntilRegex "x"` | Ignored | Waits |
| `Ctrl+c` | Ignored | Sends 0x03 |
:::

### What running a project tape does

**`Scope session`** (the default) is the tmux-sessionizer model. tuios derives
the session name (`Session`, else the basename). **If that session already
exists, it switches to it and rebuilds nothing**: the session is the durable
artifact and the tape is its constructor, run once. Otherwise it creates the
session, seeds one window whose shell starts at the project root, runs the body
and switches you there. Session scope needs a daemon-backed session; outside
one, tuios runs the tape in the current session and says so.

**`Scope current`** applies the body to the current session from the focused
window, composing with whatever exists. Keep such tapes tiny:

```text
# .tuios.tape: one split running the watcher
Scope current
Split horizontal
Run "make watch"
```

Two more guarantees: detection is off while a tape runs, and a project root
handled in this run does not re-trigger, so a tape that `cd`s onward cannot
chain another tape. Remote (SSH) shells are ignored, since tuios cannot read or
verify a file on another machine.


## Screenshots

A tuios screenshot is drawn from the pane's own cells, not grabbed from your
terminal, so colours, styles and links are exact, and it can be taken of a
detached session. By default it is a PNG of the window dressed as a card: a
title bar, rounded corners, a shadow, padding and a background wash derived
from your theme.

There are four ways to take one:

| Way | How | Scope |
|---|---|---|
| Capture mode | <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>C</kbd> (capital C) | Pick a window, the whole screen, or drag a region |
| CLI | `tuios screenshot [-s SESSION] [-w WINDOW]` | One window, attached or detached |
| Tape | `Screenshot` | The focused window |
| run-command | `tuios run-command Screenshot` | The focused window of the attached client |

### Capture mode

<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>C</kbd> (action `prefix_screenshot`; capital
because <kbd>s</kbd> is the scrollback browser) puts tuios into capture mode,
which owns the keyboard and mouse until it ends.

| Key | What it does |
|---|---|
| <kbd>Tab</kbd> <kbd>Right</kbd> <kbd>Down</kbd> <kbd>j</kbd> <kbd>l</kbd> | Highlight the next window |
| <kbd>Shift</kbd>+<kbd>Tab</kbd> <kbd>Left</kbd> <kbd>Up</kbd> <kbd>k</kbd> <kbd>h</kbd> | Highlight the previous window |
| <kbd>Enter</kbd> <kbd>Space</kbd> | Capture the highlighted window |
| <kbd>f</kbd> | Capture the whole screen |
| click, drag | Capture the window clicked, or the dragged region |
| <kbd>Esc</kbd> <kbd>q</kbd> <kbd>Ctrl</kbd>+<kbd>c</kbd> | Leave without capturing |

Capture mode also opens over a panel or overlay (the Inbox, the palette,
settings, a dialog). The panel stays open and is part of the picture; since the
panes are underneath, <kbd>Enter</kbd>, <kbd>f</kbd> or a click take the whole
screen, and a drag takes a region.

When `screenshot.preview` is on (the default), a preview panel opens after the
capture:

| Key | What it does |
|---|---|
| <kbd>Enter</kbd> <kbd>q</kbd> | Close and keep the file |
| <kbd>Esc</kbd> | Close and discard the capture |
| <kbd>c</kbd> | Copy the image to the clipboard |
| <kbd>o</kbd> | Open the file |
| <kbd>r</kbd> | Retake |
| arrows, <kbd>h</kbd><kbd>j</kbd><kbd>k</kbd><kbd>l</kbd>, <kbd>PgUp</kbd> <kbd>PgDn</kbd> | Scroll the preview |

### tuios screenshot

```text
tuios screenshot [--flags]
```

The daemon renders the file, so this works with nobody attached. It prints the
path it wrote.

| Flag | Meaning |
|---|---|
| `-s`, `--session` | Target session |
| `-w`, `--window` | Target window by name or id (default: focused) |
| `-f`, `--format` | `png`, `svg`, `ansi`, `html` or `txt` |
| `--frame` | `window`, `plain` or `none` |
| `-o`, `--out` | Write here instead of a generated name under `screenshot.directory` |
| `-S`, `--scrollback` | Put the pane's history above the screen |
| `--lines` | Bound the history to the last N rows (with `--scrollback`) |
| `--theme` | Render in this theme instead of the session's |
| `--cursor` | Draw the cursor cell |
| `--copy` / `--no-copy` | Try, or do not try, to copy the image to the clipboard (default: try) |
| `--json` | Print the result as JSON |

```sh
tuios screenshot                                   # focused window, PNG
tuios screenshot -s work -w build                  # detached is fine
tuios screenshot --scrollback --lines 200 -o build-log.png
tuios screenshot --format svg --frame plain --out docs/demo.svg
tuios screenshot --format txt -w build --out /tmp/build.txt
tuios screenshot --theme catppuccin_mocha --no-copy
```

| Format | What you get |
|---|---|
| `png` | A raster image with the frame, at `screenshot.scale` |
| `svg` | A vector image with the frame; text stays text |
| `html` | One self-contained HTML file with inline styles, selectable text and links; the frame becomes CSS |
| `ansi` | The bare ANSI stream, no frame |
| `txt` | Plain text, no frame |

::: note
With no theme set, basic and indexed colours fall back to the xterm defaults,
since only your terminal knows its own palette; the result says so. Pass
`--theme NAME` to render in a named palette instead.
:::

The `screenshot` verb on the socket takes the same parameters.

### The [screenshot] table

| Option | Type | Default | Meaning |
|---|---|---|---|
| `screenshot.format` | `png`, `svg`, `ansi`, `html`, `txt` | `png` | Default output format |
| `screenshot.copy` | bool | `true` | Try to copy the capture to the clipboard |
| `screenshot.preview` | bool | `true` | Open the preview panel after an in-app capture |
| `screenshot.directory` | path | `~/Pictures/tuios` | Where generated files land |
| `screenshot.frame` | `window`, `plain`, `none` | `window` | A window card, a plain card, or nothing |
| `screenshot.background` | `auto`, `none`, hex, `hex..hex` | `auto` | The wash behind the card; `auto` derives it from the theme, `a..b` is a gradient |
| `screenshot.padding` | int 0-128 | `48` | Space around the card, in pixels |
| `screenshot.radius` | int 0-32 | `10` | Card corner radius, in pixels |
| `screenshot.shadow` | bool | `true` | Soft shadow under the card |
| `screenshot.controls` | `auto`, `macos`, `glyphs`, `none` | `auto` | Window control marks: the macOS lights, your glyph set, or none |
| `screenshot.title_format` | string | `{title}` | Title bar text; tokens `{title}`, `{index}`, `{cwd}` |
| `screenshot.font_family` | string | `JetBrains Mono, monospace` | Font stack named in SVG and HTML output |
| `screenshot.font_file` | path | empty | A `.ttf` to draw PNG with and embed in SVG and HTML; wins over every other font choice |
| `screenshot.scale` | int 1-4 | `2` | PNG size multiplier |
| `screenshot.cursor` | bool | `false` | Draw the cursor cell |

```toml
[screenshot]
format = "svg"
frame = "plain"
background = "#1e1e2e..#313244"
title_format = "{index}: {title}  {cwd}"
copy = false
```

::: tip
For README images, `svg` with `frame = "plain"` stays sharp at any size and
keeps the text searchable. For a bug report, `txt` or `capture-pane` is easier
to paste. `tuios set-config screenshot.padding 0` changes an option without
editing the file; see [Configuration](configuration.md).
:::

## Scripted workflows from a shell

The control commands are the dependable way to automate tuios. They talk to the
daemon, so most of them work whether or not a client is attached, they address
windows by name or id rather than by focus, and they fail with an error that
names the cause. Run them from any shell: inside a tuios pane they default to
the pane's own session, outside they default to the most recently active one.
Pass `-s SESSION` in scripts so the target never depends on which session you
last touched. The complete command reference is in [CLI](cli.md); this section
covers the commands a script is built from.

### Building blocks

| Command | What it does | Needs a client |
|---|---|---|
| `tuios new NAME --detach` | Create a headless session with one window | No |
| `tuios new-window [NAME] [CMD...]` | Open a window, print its id | No |
| `tuios send-text TEXT` | Write text to a pane's terminal, unparsed | No |
| `tuios send-keys KEYS` | Send named keys (`Enter`, `ctrl+c`, `Up`) | With `-w`, no |
| `tuios run -- CMD` | Type a command at the prompt, wait, print its output, exit with its status | No |
| `tuios wait-for CONDITION` | Block until an event matches | No |
| `tuios capture-pane` | Print a pane's text | No |
| `tuios screenshot` | Render a pane to a file | No |
| `tuios focus-window` | Move the focus by name, position or direction | Only for `--direction` |
| `tuios move-window N` | Move a window to a workspace | No |
| `tuios set-window` | Rename, minimize or restore a window | No |
| `tuios split-window`, `tuios set-layout` | Split, tile, equalize, rotate | Yes |
| `tuios xpanes` | One pane per item, multifocus on | For layout and multifocus |
| `tuios close-workspace [N]` | Close every pane on a workspace | No |
| `tuios popup -- CMD` | A floating pane for one command | Yes |
| `tuios run-command CMD [ARGS]` | Any tape command by name | Mostly |
| `tuios list-windows --json` | Every window, with prompt state | No |
| `tuios subscribe` | The daemon's event stream, one JSON object per line | No |

### Targeting windows

`-w` takes, in this order: the full window id, the index `list-windows`
prints, the exact window name, then a unique id prefix. A name set with
`new-window NAME`, `--name` or `set-window --name` wins over a program's title.
An ambiguous target is an error that lists the matches. Names are the easiest
handle in scripts; ids are the safest when several scripts run at once.

```sh
id=$(tuios new-window -s work build --print-id)   # full id, nothing else
tuios send-text -s work -w "$id" 'make
'
tuios send-text -s work -w build 'make
'                                                 # same window, by name
```

### Opening windows: new-window

```text
tuios new-window [name] [command...] [--flags]
```

`--cwd DIR` sets the starting directory (default: the daemon's),
`--workspace N` the workspace, `--no-focus` leaves the focus alone,
`--print-id` prints only the full id, `--json` prints `window_id` and the
placement (`unplaced: true` on a detached session, where the size is nominal
until a client attaches), `--host NAME` runs the process on a `[hosts]`
machine, and `--grants LIST` limits what the process may do through tuios.

Without a command the window runs your shell. With one, the argv after the
name is the window's own process, not re-parsed by any shell, and the window
closes when it exits. Put `--` before a command that has flags of its own.

```sh
tuios new-window -s work tests --workspace 2 --cwd ~/src/api --no-focus
tuios new-window -s work top /usr/bin/htop
tuios new-window -s work log -- git log --oneline -20
tuios new-window -s work --json | jq -r .window_id
```

The plain output is the short id and the name, for example `d6b97fe4  build`.

::: warning
Close what you open. On a detached session a window whose shell has exited
stays in the list until something closes it:
`tuios run-command -s work CloseWindow "$id"`.
:::

### Typing: send-text and send-keys

`send-text` writes its argument to the pane's terminal unchanged. End the text
with a newline to run it.

```sh
tuios send-text -s work -w build 'go build ./...
'
printf 'go build ./...\n' | xargs -0 tuios send-text -s work -w build
tuios send-text -s work -w build $'go test ./...\n'              # bash and zsh
```

`send-keys` maps names to keys. It splits its argument on spaces and commas, so
it cannot type text: `send-keys 'echo hello'` types `echohello`.

| Key | Names | Other spellings |
|---|---|---|
| Arrows | `Up` `Down` `Left` `Right` | `up`, `UP`, `arrow-up`, `ArrowUp`, `KEY_UP`, `<Up>` |
| Page keys | `PageUp` `PageDown` | `PgUp`, `PgDn`, `Page_Down`, `NPage`, `PPage` |
| Line ends | `Home` `End` | `KEY_HOME`, `<End>` |
| Enter | `Enter` | `Return`, `CR`, `KEY_ENTER` |
| Escape | `Escape` | `Esc` |
| Editing | `Tab` `BTab` `Space` `Backspace` `Delete` `Insert` | `shift+Tab`, `BSpace`, `BS`, `Del`, `Ins` |
| Comma | `Comma` | a bare `,` splits keys |
| Function keys | `F1` to `F12` | `f5`, `KEY_F5` |
| A character | `q` `j` `G` `/` | any single character |
| Modifiers | `ctrl+c` `alt+b` `shift+Up` `ctrl+Right` | `C-c`, `M-b`, `S-Up`, `^C` |
| Raw sequence | `\e[A` | `\x1b[A`, `\033[A` |
| Leader key | `PREFIX` | only without `-w`, with a client attached |

| Flag | Meaning |
|---|---|
| `-w WINDOW` | Write to that window's terminal, attached or not, whatever has the focus |
| `-N`, `--repeat N` | Send the whole sequence N times (1 to 1000) |
| `-l`, `--literal` | Write the argument unchanged, no key names |
| `-r`, `--raw` | Treat each character as its own key, no splitting |
| `--json` | Print the result as JSON |

```sh
tuios send-keys -s work -w build ctrl+c
tuios send-keys -s work -w docs Down --repeat 10
tuios send-keys -s work -w docs 'PageDown PageDown'
tuios send-keys -s work "PREFIX n"          # the leader then n, through the client
```

Without `-w`, keys go to the attached client as if the person pressed them,
which drives the window manager or the focused window; with no client, they go
to the focused window. Arrows, `Home` and `End` are sent in the form the
program asked for (`ESC O A` to vim, `ESC [ A` to a shell). A word that looks
like a misspelled key (`Dwon`, `F13`) is refused and nothing is sent. The
command prints where the keys went: `sent 5 keys to window docs (d6b97fe4)`.

### Reading: capture-pane

| Flag | Meaning |
|---|---|
| `-w WINDOW` | The pane (default: focused) |
| `-S`, `--scrollback` | Include the full scrollback |
| `--lines N` | Keep only the last N lines (0 keeps all) |
| `--last-command` | Only what the last finished command printed (needs OSC 133) |
| `--ansi` | Keep ANSI escape codes |
| `--resolved` | Rewrite indexed colours to 24-bit RGB |
| `--palette LIST` | 16 `#rrggbb` colours to resolve against (default: xterm) |
| `--json` | Print the result as JSON |
| `-s SESSION` | Target session |

```sh
tuios capture-pane -s work -w build --scrollback --lines 40
tuios capture-pane -s work -w build --last-command
tuios capture-pane -s work -w editor --scrollback > pane.txt
```

A capture from another machine (`-s host:session`) is fenced as untrusted
content; with `--json` it carries `"untrusted": true`.

### Running: tuios run and exit codes

```text
tuios run [-s SESSION] [-w WINDOW] [--timeout MS] [--lines N] [--json] -- <command line>
```

`run` types one command line at a pane's prompt, waits for the shell to report
that the command finished, prints exactly what that command printed, and exits
with the command's exit status. It reads where the command starts and ends from
the shell's OSC 133 prompt marks, so it needs shell integration: fish 4 on its
own, zsh and bash 4.4 or newer with the lines `tuios doctor shell` prints.

```sh
tuios run -s work -w build --timeout 600000 -- go test ./...
echo "tests exited $?"
tuios run -s work -w build --lines 40 -- make
tuios run -s work -w build --json -- make lint | jq '{exit_code, duration_ms}'
```

| Situation | Result |
|---|---|
| The command exits 0 | `run` prints its output and exits 0 |
| The command exits N | `run` prints its output and exits N |
| The shell sent no status | Exits 0 and says `the shell reported no exit status for this command` |
| Output longer than `--lines` | The end is kept; stderr says `the output was cut` |
| `--json` | Prints `window`, `cmdline`, `exit_code`, `output`, `truncated`, `duration_ms`, `command_seq` |
| The pane runs no shell integration | Refused with `no_shell_integration`; nothing typed |
| The pane is busy | Refused with `not_at_prompt`; nothing typed |
| The timeout (default 30000 ms) passes | Fails with `timeout`; the command keeps running, and the error names the `wait-for command-finished --command-seq N` that picks it up |

The words after `--` are joined with spaces into one line for the shell, so
quote them as you would at a prompt: `tuios run -w build -- 'make test && echo ok'`
passes the `&&` to the pane, while an unquoted `&&` belongs to your own shell.

### Waiting: tuios wait-for

`wait-for` blocks until the daemon reports that a condition matched, then exits
0. A condition that does not match before `--timeout` exits non-zero with the
`timeout` error. The daemon watches its own events, so there is no polling.

| Condition | Matches when | Required flags |
|---|---|---|
| `session-exists` | The named session is present | `-s` |
| `window-output` | The window printed something matching `--pattern` (a Go regex), including what is already in its scrollback | `--pattern` |
| `window-exit` | The window's process exited | |
| `window-idle` | The window printed nothing for `--idle` ms (default 500) | |
| `agent-state` | An agent pane reached one of the `--until` states (`none`, `working`, `needs_input`, `idle`, `done`, `errored`, `unknown`) | `--until` |
| `agent-message` | Mail arrived (with `-w`, unread mail for that inbox, including mail queued before the wait) | |
| `command-finished` | A shell with OSC 133 marks finished a command; prints the exit code | |

| Flag | Meaning |
|---|---|
| `-s`, `--session` | Target session (default: most recently active) |
| `-w`, `--window` | Target window (default: focused; for `agent-state`, any) |
| `--timeout MS` | Give up after this long (default 30000, at most 24 hours) |
| `--pattern RE` | For `window-output` |
| `--idle MS` | For `window-idle` |
| `--until STATES` | For `agent-state`, comma-separated |
| `--any-session` | For `agent-state`: every session |
| `--select SELECTOR` | For `agent-state`: the panes a selector matches |
| `--every` | With `--select`: wait until every matched pane is in an `--until` state |
| `--thread ID` | For `agent-message`: one conversation |
| `--command-seq N` | For `command-finished`: match once the pane has finished more than N commands (at once if that already happened) |
| `--json` | Print the result as JSON |

```sh
tuios wait-for session-exists -s work --timeout 10000
tuios wait-for window-output -s work -w build --pattern 'BUILD (OK|FAILED)' --timeout 600000
tuios wait-for window-idle -s work -w build --idle 2000
tuios wait-for window-exit -s work -w job --timeout 600000
tuios wait-for command-finished -s work -w build --timeout 600000
tuios wait-for agent-state -s work --until needs_input
tuios wait-for agent-state --select 'group:fan/retry' --until idle,done --every --timeout 3600000
tuios wait-for agent-message -s work -w "$TUIOS_PANE_ID" --timeout 600000
```

See [Agents](agents.md) for `agent-state`, `agent-message` and selectors.

#### Markers and the one trap in window-output

`window-output` matches the whole scrollback, including text that was there
before the wait started. The pane echoes the command you typed, so a marker
written literally in the command matches its own echo at once, and a fixed
marker from an earlier run matches again next time. Make the marker fresh, and
let the shell assemble it so the echo cannot match:

```sh
n=$(date +%s)
tuios send-text -s work -w build "go test ./... ; printf 'tests_done_%s_rc=%s\n' $n \$?
"
tuios wait-for window-output -s work -w build --pattern "tests_done_${n}_rc=[0-9]+" --timeout 300000
rc=$(tuios capture-pane -s work -w build --scrollback --lines 200 |
     grep -o "tests_done_${n}_rc=[0-9]*" | tail -1 | cut -d= -f2)
echo "exit status: $rc"
```

The echoed line reads `printf 'tests_done_%s_rc=%s\n' 1791367393 $?`, which the
pattern does not match; the output reads `tests_done_1791367393_rc=0`, which it
does. This is the fallback for panes without shell integration. With it, prefer
`tuios run`, or `wait-for command-finished`, which reports the exit code
directly.

A third pattern needs neither: run the work in a window that exits, and wait for
the exit.

```sh
tuios new-window -s work job
tuios send-text -s work -w job 'go test ./... > /tmp/test.log 2>&1; exit
'
tuios wait-for window-exit -s work -w job --timeout 300000
tail -60 /tmp/test.log
```

### Arranging: focus, workspaces and layout

```sh
tuios focus-window -s work build              # by name or id; switches to its workspace
tuios focus-window -s work --relative next    # next or prev on this workspace
tuios focus-window -s work --direction left   # needs an attached client
tuios move-window -s work 2 -w build --follow
tuios select-workspace -s work 2
tuios set-window -s work -w build --name "api tests"
tuios split-window -s work vertical -w build --name logs   # needs a client and tiling
tuios set-layout -s work --tiling true --equalize           # needs a client
tuios close-workspace -s work 2               # close every pane on workspace 2
```

`focus-window` takes exactly one of a window, `--relative` or `--direction`, and
prints the pane that ended up focused. `close-workspace` without a number closes
the current workspace's panes; scratch panes stay open; from a pane it needs the
`admin` grant. Commands that need geometry (`split-window`, `set-layout`,
`focus-window --direction`, popups) fail with `needs_client` on a detached
session.

### Fanning out: tuios xpanes

`xpanes` opens one pane per item on the first empty workspace, tiles them and
turns multifocus on, so what you type reaches every pane, as tmux-xpanes does.

```text
tuios xpanes [items...] [--flags]
```

| Flag | Meaning |
|---|---|
| `-c`, `--command CMD` | Command per pane; `{}` becomes the item, shell-quoted |
| `-I`, `--replace STR` | Use STR instead of `{}` |
| `-n`, `--items-per-pane N` | N items per pane, joined with spaces (default 1) |
| `-l`, `--layout L` | `tiled`, `even-horizontal`, `even-vertical` (`t`, `eh`, `ev`) |
| `--no-sync` | Do not turn multifocus on |
| `-s`, `--speedy` | Run the command with `sh -c`, no interactive shell; hold the pane until Enter. `-ss` closes it when the command stops |
| `--ssh` | `-s -c 'ssh -- {}'` |
| `--interval SECS` | Wait between panes, for example `0.5` |
| `--session NAME` | Target session (note: `-s` is speedy mode here) |
| `--workspace N` | Workspace to use; it must be empty |
| `--force` | Allow more than 64 panes |
| `--json` | Print the window ids |

With no item arguments, items are read one per line from stdin (empty lines
ignored). Each pane is named after its item and gets `TUIOS_XPANES_ITEM` and
`TUIOS_XPANES_INDEX` (from 1). Without `-s`, `-c` is typed into the pane's
shell, which stays. Layout and multifocus need an attached client with tiling
on and the `bsp` layout; otherwise the panes still open and tuios says what it
could not do.

```sh
tuios xpanes --ssh web1 web2 web3
printf 'a\nb\nc\n' | tuios xpanes -c 'echo {}; exec $SHELL'
ls /var/log/*.log | tuios xpanes -l even-horizontal --no-sync -c 'tail -f {}'
tuios xpanes -n 2 -c 'diff {}' a.txt b.txt c.txt d.txt
tuios xpanes -ss --interval 1 -c 'curl -s https://{}/health' web1 web2 web3
tuios close-workspace 2      # close them all again
```

### Popups

`popup` runs one command in a floating pane centred over the layout. The pane
closes when the command exits; it is not tiled, not in the window cycle, and
cannot be minimized. It needs an attached client.

| Flag | Meaning |
|---|---|
| `--width`, `--height` | Cells or percent of the pane region (defaults 80% and 60%) |
| `--wait` | Stay until the command exits, and exit with its status |
| `--capture-stdout` | Print the command's stdout here instead of in the popup (implies `--wait`; not on Windows) |
| `--timeout MS` | With `--wait` |
| `--name`, `--cwd`, `--workspace`, `-s` | Placement |
| `--json` | Print the popup's id |

```sh
file=$(tuios popup --capture-stdout -- fzf)
tuios popup --wait -- gum confirm "Deploy?" && ./deploy.sh
tuios popup --width 60 --height 20 -- gum choose one two three
tuios popup --width 90% --height 80% -- htop
```

A popup closed by hand exits 130.

### Error codes a script should know

Over the socket every failure carries a stable code; the CLI folds it into its
message. The ones scripts meet most:

| Code | Meaning | What to do |
|---|---|---|
| `session_not_found`, `window_not_found` | Bad target; the error lists what exists | Fix the name, or create it first |
| `session_exists` | `new` with a name already taken | Attach to it, or pick another name |
| `needs_client` | A geometry command on a detached session | Attach, or use a verb that needs none |
| `timeout` | `wait-for` or `run` gave up | Capture the pane; for `run`, continue with `wait-for command-finished --command-seq N` |
| `no_shell_integration`, `not_at_prompt` | From `run`; nothing typed | Use `send-text` and a marker |
| `forbidden` | The calling pane lacks a grant | See `tuios pane-grants` |

`tuios ls` signals the daemon's state by exit code: 0 for a running daemon
(even with no sessions), 3 for no daemon (saved sessions are listed with
`"saved": true`), 1 for a failure.

## Worked scripts

Six complete scripts. Each is bash, uses only commands from this chapter, and
takes the session name as its first argument so you can run several at once.

### 1. Open a dev layout: editor, server, logs

Creates the session if it is missing, opens three named windows in the project
directory, starts each program, and attaches. Running it again just attaches.

```bash
#!/usr/bin/env bash
# dev-layout.sh SESSION [DIR]
set -euo pipefail
S=${1:-dev}
DIR=$(cd "${2:-$PWD}" && pwd)

exists() {
  tuios ls --json 2>/dev/null | jq -e --arg s "$S" 'any(.[]; .name == $s)' >/dev/null
}

if ! exists; then
  tuios new "$S" --detach
  tuios wait-for session-exists -s "$S" --timeout 10000

  # The detached session starts with one window: make it the editor.
  tuios set-window -s "$S" --name editor
  tuios send-text -s "$S" -w editor "cd $(printf '%q' "$DIR") && \${EDITOR:-vi} .
"
  tuios new-window -s "$S" server --cwd "$DIR" --no-focus
  tuios new-window -s "$S" logs   --cwd "$DIR" --no-focus

  # Let each shell draw its prompt before typing into it.
  tuios wait-for window-idle -s "$S" -w server --idle 300 --timeout 10000
  tuios send-text -s "$S" -w server 'npm run dev
'
  tuios wait-for window-idle -s "$S" -w logs --idle 300 --timeout 10000
  tuios send-text -s "$S" -w logs 'tail -n 50 -F log/development.log
'
  tuios focus-window -s "$S" editor
fi

exec tuios attach "$S"
```

::: note
The windows are opened on a detached session, so they get a nominal size; the
layout is computed when the client attaches. With `startup.tiled = true` (the
default for a new install) they come up tiled. To split instead of tile, run
`tuios split-window` after `attach` from another shell, since splits need an
attached client.
:::

### 2. Run the test suite in a pane and wait for a marker

Uses `tuios run` when the pane's shell has OSC 133 integration, and falls back
to a fresh marker otherwise. Either way the script's exit status is the suite's.

```bash
#!/usr/bin/env bash
# test-in-pane.sh SESSION [WINDOW] [COMMAND...]
set -uo pipefail
S=${1:?session}; W=${2:-tests}; shift 2 || true
CMD=${*:-go test ./...}

# Make sure the pane exists.
if ! tuios list-windows -s "$S" --json |
     jq -e --arg w "$W" 'any(.windows[]; .display_name == $w)' >/dev/null; then
  tuios new-window -s "$S" "$W" --cwd "$PWD" --no-focus >/dev/null
  tuios wait-for window-idle -s "$S" -w "$W" --idle 500 --timeout 10000
fi

marks=$(tuios list-windows -s "$S" --json |
        jq -r --arg w "$W" '.windows[] | select(.display_name == $w) | .marks_commands // false')

if [ "$marks" = true ]; then
  tuios run -s "$S" -w "$W" --timeout 1800000 --lines 80 -- "$CMD"
  exit $?
fi

n=$(date +%s)$$
tuios send-text -s "$S" -w "$W" "$CMD ; printf 'tdone_%s_rc=%s\n' $n \$?
"
if ! tuios wait-for window-output -s "$S" -w "$W" \
       --pattern "tdone_${n}_rc=[0-9]+" --timeout 1800000; then
  echo "timed out; last lines:" >&2
  tuios capture-pane -s "$S" -w "$W" --scrollback --lines 40 >&2
  exit 124
fi
out=$(tuios capture-pane -s "$S" -w "$W" --scrollback --lines 400)
rc=$(printf '%s\n' "$out" | grep -o "tdone_${n}_rc=[0-9]*" | tail -1 | cut -d= -f2)
printf '%s\n' "$out" | tail -80
exit "${rc:-1}"
```

```sh
./test-in-pane.sh work tests make test
echo "suite exited $?"
```

### 3. Fan work over xpanes

Runs one command per item in its own pane, waits for every pane's marker,
reports each result, and closes the workspace.

```bash
#!/usr/bin/env bash
# fan-xpanes.sh SESSION ITEM...
# Example: fan-xpanes.sh work ./api ./web ./worker
set -euo pipefail
S=${1:?session}; shift
[ $# -gt 0 ] || { echo "usage: $0 SESSION ITEM..." >&2; exit 2; }

ids=$(tuios xpanes --session "$S" --no-sync --json \
        -c 'cd {} && make test; printf "xp_done_%s_rc=%s\n" "$TUIOS_XPANES_INDEX" $?' \
        "$@" | jq -r '.. | .window_id? // empty')

fail=0; i=0
for id in $ids; do
  i=$((i + 1))
  tuios wait-for window-output -s "$S" -w "$id" \
    --pattern "xp_done_${i}_rc=[0-9]+" --timeout 1800000
  rc=$(tuios capture-pane -s "$S" -w "$id" --scrollback --lines 200 |
       grep -o "xp_done_${i}_rc=[0-9]*" | tail -1 | cut -d= -f2)
  name=$(tuios get-window -s "$S" "$id" --json | jq -r '.display_name // .title')
  printf '%-20s rc=%s\n' "$name" "$rc"
  [ "$rc" = 0 ] || fail=1
done

ws=$(tuios get-window -s "$S" "$(printf '%s\n' $ids | head -1)" --json | jq -r '.workspace')
[ "$fail" = 0 ] && tuios close-workspace -s "$S" "$ws"
exit "$fail"
```

::: note
The marker is printed with `"$TUIOS_XPANES_INDEX"`, a variable the echo shows
unexpanded, so the echo never matches. The script leaves the workspace open
when anything failed so you can read the panes. The `jq` expression collects
every `window_id` in the JSON, whatever its nesting; run
`tuios xpanes --json ...` once and look at it if you want a tighter filter.
The `display_name` and `workspace` keys come from `get-window --json`.
:::

### 4. Watch a log for a regex, then notify

Tails a log in a dedicated window and blocks until a line matches. Then it
raises a tuios notification, a desktop notification, and a screenshot of the
window for the record.

```bash
#!/usr/bin/env bash
# watch-log.sh SESSION LOGFILE [REGEX]
set -euo pipefail
S=${1:?session}; LOG=${2:?logfile}; RE=${3:-'ERROR|FATAL|panic:'}
W=watch-$(basename "$LOG")

# -n 0: start at the end, so old lines already in the file cannot match.
id=$(tuios new-window -s "$S" "$W" --no-focus --print-id -- tail -n 0 -F "$LOG")

if tuios wait-for window-output -s "$S" -w "$id" --pattern "$RE" --timeout 86400000; then
  line=$(tuios capture-pane -s "$S" -w "$id" --scrollback | grep -E "$RE" | tail -1)
  shot=$(tuios screenshot -s "$S" -w "$id" --no-copy --format png)
  tuios run-command -s "$S" ShowNotification "$W: ${line:0:80}" error ||
    true                                   # needs an attached client
  if command -v notify-send >/dev/null; then
    notify-send "tuios: $W" "$line"
  elif command -v osascript >/dev/null; then
    osascript -e "display notification \"${line//\"/}\" with title \"tuios: $W\""
  fi
  echo "matched: $line"
  echo "screenshot: $shot"
fi
tuios run-command -s "$S" CloseWindow "$id" || true
```

::: warning
`window-output` keeps matching once the text is in the scrollback, so do not
loop on the same window: the second wait returns at once. To watch again, close
the window and open a new one (run the script in a loop), or follow the stream
in your own process instead (`tail -n 0 -F "$LOG" | grep -m1 -E "$RE"`).
:::

### 5. A startup script with [startup]

The `[startup]` table decides how a new session starts. It has no option that
runs commands: there is no startup script hook in v0.8.5. You combine it with a
script (or with a [project tape](#project-tapes)) to get a scripted start.

| Option | Type | Default | Meaning |
|---|---|---|---|
| `startup.open_default_window` | bool | `false` | Open one terminal when a session starts empty |
| `startup.tiled` | bool | `true` | Start a new session tiled instead of floating |
| `startup.start_in_terminal_mode` | bool | `false` | Start focused in terminal mode when a window is present |
| `startup.layout` | string | `bsp` | Tiling scheme a new session starts in; an existing session keeps its own |
| `startup.daemon` | bool | `true` | Make a bare `tuios` attach to a daemon-backed session; `TUIOS_NO_DAEMON=1` or `--standalone` overrides it |

::: default
The booleans have no fill-in for a missing key. A config file that predates
them and does not name them reads them as `false`, so an existing install keeps
its floating, standalone start; the `true` defaults reach a new install only.
Name them explicitly if you rely on them.
:::

```toml
# ~/.config/tuios/config.toml
[startup]
daemon = true
tiled = true
layout = "master-stack"
start_in_terminal_mode = true
open_default_window = false

[appearance]
master_position = "left"
master_ratio = 60
```

Run the script below instead of `tuios`. It builds the `main` session once per
daemon start, then attaches. If you call it from a shell rc file, guard it with
`[ -z "$TUIOS_SESSION" ]`, which tuios sets in its panes, so a pane's shell
does not try to attach to tuios from inside tuios.

```bash
#!/usr/bin/env bash
# tuios-up: build the main session once, then attach
set -euo pipefail
S=main

tuios ls >/dev/null 2>&1 || true        # exit 3 just means no daemon yet

if ! tuios ls --json 2>/dev/null | jq -e --arg s "$S" 'any(.[]; .name == $s)' >/dev/null; then
  tuios new "$S" --detach
  tuios wait-for session-exists -s "$S" --timeout 10000
  tuios set-window -s "$S" --name shell
  tuios new-window -s "$S" notes  --cwd ~/notes --no-focus -- "${EDITOR:-vi}" .
  tuios new-window -s "$S" top    --no-focus -- htop
  tuios new-window -s "$S" mail   --workspace 2 --no-focus
  tuios set-workspace-name -s "$S" 2 comms
  tuios focus-window -s "$S" shell
fi

exec tuios attach "$S"
```

### 6. A hook-driven workflow

Hooks run a shell command when an event happens, with the facts in `TUIOS_*`
variables. The full schema (all ten events, which side runs each, every
variable) is in [Configuration](configuration.md) and upstream
[HOOKS.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/HOOKS.md).
This workflow uses `after-command-finished`, which the daemon fires when a
pane's shell reports through OSC 133 that a command finished: when a command
that ran longer than 30 seconds fails, it takes a screenshot of the pane and
sends a desktop notification. It also logs every new window.

```toml
[hooks]
after-command-finished = "sh ~/.config/tuios/hooks/long-fail.sh"
after-new-window = "printf '%s %s %s\\n' \"$(date +%T)\" \"$TUIOS_SESSION_ID\" \"$TUIOS_WINDOW_NAME\" >> ~/.cache/tuios-windows.log"
```

```sh
#!/bin/sh
# ~/.config/tuios/hooks/long-fail.sh
# Gets TUIOS_COMMAND, TUIOS_EXIT_CODE, TUIOS_DURATION_MS, TUIOS_SESSION_ID,
# TUIOS_WINDOW_ID and TUIOS_WINDOW_NAME from the daemon.
[ -n "$TUIOS_EXIT_CODE" ] || exit 0                 # shell sent no status
[ "$TUIOS_EXIT_CODE" -ne 0 ] || exit 0              # success: nothing to do
[ "${TUIOS_DURATION_MS:-0}" -ge 30000 ] || exit 0   # quick failures are noise

TUIOS=/opt/homebrew/bin/tuios                       # full path: the daemon's PATH is not yours
dir=$HOME/Pictures/tuios/failures
mkdir -p "$dir"
out="$dir/$(date +%Y%m%d-%H%M%S)-${TUIOS_WINDOW_NAME:-pane}.png"
"$TUIOS" screenshot -s "$TUIOS_SESSION_ID" -w "$TUIOS_WINDOW_ID" --no-copy -o "$out" >/dev/null

msg="$TUIOS_WINDOW_NAME: '$TUIOS_COMMAND' failed ($TUIOS_EXIT_CODE) after $((TUIOS_DURATION_MS / 1000))s"
if command -v notify-send >/dev/null; then
  notify-send "tuios" "$msg"
elif command -v osascript >/dev/null; then
  osascript -e "display notification \"$(printf '%s' "$msg" | tr -d '\"')\" with title \"tuios\""
fi
```

Then load and check it:

```sh
chmod +x ~/.config/tuios/hooks/long-fail.sh
tuios list-hooks                      # the rows show whether each command was loaded
tuios list-hooks --event after-command-finished --json |
  jq '.hooks[] | {runs, last_exit_code, last_error}'
```

::: warning
The daemon reads `[hooks]` only when it starts, so a change to a daemon-run
hook takes effect after `tuios kill-server`, which ends every shell (the layout
comes back from saved state with new shells). A daemon hook gets the daemon's
environment, not your shell's, hence the full paths. And do not let a hook
cause its own event: an `after-new-window` hook that runs `tuios new-window`
feeds itself. Screenshots and notifications are safe.
:::

`TUIOS_COMMAND` is the command line cut to 512 bytes with likely secrets
masked, and `TUIOS_EXIT_CODE` is empty when the shell sent no status. A pane
without shell integration never fires the event, and a standalone tuios with no
daemon does not fire it at all.

## Shell completion

`tuios completion` prints a completion script for bash, zsh, fish or
PowerShell. Each takes `--no-descriptions`.

| Shell | Current session | Every new session |
|---|---|---|
| bash (needs `bash-completion`) | `source <(tuios completion bash)` | `tuios completion bash > /etc/bash_completion.d/tuios` (Linux) or `> $(brew --prefix)/etc/bash_completion.d/tuios` (macOS) |
| zsh | `source <(tuios completion zsh)` | `tuios completion zsh > "${fpath[1]}/_tuios"` (Linux) or `> $(brew --prefix)/share/zsh/site-functions/_tuios` (macOS) |
| fish | see below | `tuios completion fish > ~/.config/fish/completions/tuios.fish` |
| PowerShell | see below | add the output of the command below to your PowerShell profile |

For the current session in fish and PowerShell:

```sh
tuios completion fish | source
tuios completion powershell | Out-String | Invoke-Expression
```

For zsh, completion must be enabled once (`autoload -U compinit; compinit` in
`~/.zshrc`). Start a new shell after installing a script.

## Scripting tips: --json and jq

Almost every command takes `--json`. Use it whenever a script reads a result,
rather than parsing the table output.

```sh
# Ids and names of every window, tab-separated
tuios list-windows -s work --json | jq -r '.windows[] | "\(.window_id)\t\(.display_name)"'

# Panes at a prompt whose last command failed
tuios list-windows -s work --json |
  jq -r '.windows[] | select(.at_prompt and (.last_exit_code // 0) != 0)
         | "\(.display_name)\t\(.last_exit_code)\t\(.last_cmdline)"'

# Ids of what you create
id=$(tuios new-window -s work job --json | jq -r .window_id)
logs=$(tuios split-window -s work vertical --name logs --json | jq -r .window_id)

# Exit code and duration of a run; does a session exist; which hooks failed
tuios run -s work -w build --json -- make lint | jq '{exit_code, duration_ms}'
tuios ls --json | jq -e 'any(.[]; .name == "work")' >/dev/null && echo yes
tuios list-hooks --json | jq '.hooks[] | select(.last_error != "")'

# React to events instead of polling
tuios subscribe -s work --types window-created | jq -c .
```

`list-windows --json` returns `windows`, `total`, `focused_window_id`,
`focused_index`, `current_workspace` and `workspace_windows`. Each window has
`window_id`, `index`, `display_name` (its name), `title`, `workspace`,
`focused`, `minimized`, `cwd`, `foreground_cmd`, its geometry and
`agent_state`, plus, for a shell with OSC 133 marks, `marks_commands`,
`at_prompt`, `command_seq`, `running_cmdline`, `last_cmdline`,
`last_exit_code` and `last_duration_ms`.

Habits that keep scripts deterministic: always pass `-s SESSION`; name every
window you create or keep its id, and never rely on the focus; wait on events
(`wait-for`, `run`) rather than `sleep`; make markers fresh; use `--no-focus`
so a script does not pull the person away; close what you open. Every command
is also a JSON verb on the daemon's socket (`tuios list-verbs`); see
[Extending tuios](howto-extending.md).

## Glossary

Tape
: A text file of tuios commands, one per line, played back by `tuios tape play`,
  `tuios tape exec` or the tape manager.

Project tape
: A `.tuios.tape` file in a project directory, written in the layout body
  language, run only after you review and trust it.

Capture mode
: The screenshot gesture (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>C</kbd>) for picking
  a window, the screen or a region.

OSC 133
: The terminal escape sequences a shell uses to mark its prompt and each
  command's start and end; `tuios run`, `wait-for command-finished`,
  `capture-pane --last-command` and the `after-command-finished` hook depend on
  them.

Marker
: A unique string a script makes a command print so that `wait-for
  window-output` can tell when it finished.

Hook
: A shell command in `[hooks]` run on an event, with the facts in `TUIOS_*`
  variables.
