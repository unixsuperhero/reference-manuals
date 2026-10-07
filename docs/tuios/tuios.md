---
title: "TUIOS: Start Here"
template: tuios-manual
manual: tuios
chapter: 1
summary: What tuios is, how to install it, the mental model behind sessions, workspaces, windows and panes, a first session, and a map of the rest of this manual.
tags:
  - tuios
  - terminal
  - multiplexer
  - manual
---

tuios (Terminal UI Operating System) is a terminal window manager and multiplexer written in Go. It runs inside the terminal you already use, tiles or floats any number of terminal panes across nine workspaces, keeps those panes alive in a daemon so they survive the window they started in, and understands the coding agents that run inside them. This manual documents tuios **v0.8.5** as installed by Homebrew on macOS in October 2026, from the project's own source tree and the output of the binary itself.

This chapter is the orientation. It installs tuios, explains the handful of objects every other chapter refers to, walks through a first session, and tells you where each topic lives in the manual.

## What tuios is, in one screen

Think of tuios as three things stacked on top of each other:

```text
┌──────────────────────────────────────────────────────────────────┐
│  CLIENT      the `tuios` TUI drawn in your terminal              │
│              modes, keybindings, palette, dock, rail, overlays   │
├──────────────────────────────────────────────────────────────────┤
│  DAEMON      `tuios daemon`, one per user, on a unix socket      │
│              owns every session, window and pty; survives you    │
│              detaching; reaches other machines over ssh          │
├──────────────────────────────────────────────────────────────────┤
│  VERBS       the JSON protocol every `tuios <command>` speaks    │
│              from a shell, a script, an agent, an MCP client,    │
│              a tmux-only tool through the shim, or herdr clients │
└──────────────────────────────────────────────────────────────────┘
```

- The **client** is what you look at. It is a Bubble Tea v2 application with a vim-like modal interface: a window-management mode for arranging panes and a terminal mode for typing into one.
- The **daemon** is what keeps state. A session lives there, not in your terminal window, so closing the window, losing an ssh link or rebooting (with resurrection) does not lose the session.
- The **verbs** are how everything else talks to the daemon. Every subcommand of `tuios`, the agent skill, the MCP server, the tmux shim and the herdr adapter are all thin clients of the same protocol.

::: note
The project calls itself TUIOS, tuios and "Terminal UI Operating System". The binary and the daemon are both `tuios`. The web front end is a separate binary, `tuios-web`, kept apart for security isolation.
:::

## Installing

tuios is a single static binary. Pick one route:

```sh
# Homebrew (macOS and Linux); this manual was written against this build
brew install tuios

# Arch Linux
yay -S tuios-bin

# Nix: a release, the newest main, or the nixpkgs package
nix run github:Gaurav-Gosain/tuios/v0.8.5#tuios
nix run github:Gaurav-Gosain/tuios#tuios
nix run nixpkgs#tuios

# Install script (Linux and macOS)
curl -fsSL https://raw.githubusercontent.com/Gaurav-Gosain/tuios/main/install.sh | bash

# Go toolchain (needs Go 1.26.6 or newer)
go install github.com/Gaurav-Gosain/tuios/cmd/tuios@latest

# Docker
docker run -it --rm ghcr.io/gaurav-gosain/tuios:latest
```

Pre-built binaries for Linux, macOS, Windows, FreeBSD and OpenBSD are on the [GitHub releases page](https://github.com/Gaurav-Gosain/tuios/releases) with a `checksums.txt`. The `tuios-ghostty_*` archives are the same program built on the libghostty-vt terminal emulator instead of the pure-Go one.

Check what you have:

```sh
tuios --version
```

```text
tuios version 0.8.5 [pure-Go backend]
Commit: Homebrew
Built: 2026-10-02T05:38:20Z
```

::: tip
`tuios update` fetches the newest release when you installed from the script or a release binary. When a package manager owns the binary, it detects that and prints the right command instead of overwriting the file.
:::

**Requirements.** A terminal with true colour. For images, a terminal that speaks the kitty graphics protocol or sixel (Ghostty, Kitty, WezTerm). A Nerd Font makes the chrome prettier; `--ascii-only` or a glyph set in the config removes the need for one (see [Configuration](configuration.md#glyph-sets)).

## The mental model

Every chapter uses these words, in this exact sense.

| Word | Meaning |
| --- | --- |
| **Daemon** | The background process that owns everything. One per user, addressed over a unix socket under `XDG_RUNTIME_DIR`. |
| **Session** | A named collection of workspaces, like a tmux session. `tuios new work`, `tuios attach work`, `tuios ls`. A session can be *global* and hold panes from several machines. |
| **Workspace** | One of nine numbered screens inside a session. Each has its own layout and its own set of windows. |
| **Window** | One rectangle on a workspace. It has an id (a uuid), an index, an optional name you gave it, and the title its program sets. It is either tiled or floating, and can be minimized or zoomed. |
| **Pane** | The terminal inside a window. One window owns exactly one pane, so the words are used interchangeably: `TUIOS_PANE_ID` and `TUIOS_WINDOW_ID` are the same uuid. |
| **Focus** | The window that receives keys. The daemon remembers the most recently active session too, which is what commands use when you omit `-s`. |
| **Mode** | Window-management mode (keys rearrange windows) or terminal mode (keys go to the program). Copy mode is a third, for scrollback. |
| **Prefix** | The chord leader, <kbd>Ctrl</kbd>+<kbd>b</kbd> by default. <kbd>Prefix</kbd> <kbd>d</kbd> means press the prefix, release, press d. |
| **Dock** | The bar along the bottom: workspace tabs, session buttons, agents, clock and your own components. |
| **Rail** | The sidebar on the right: sessions, terminals, files, git state and agents. |
| **Agent** | A coding assistant (Claude Code, Codex, Gemini CLI, opencode, ...) running in a pane. tuios tracks its state and gives it a mailbox. |
| **Verb** | One request type in the daemon's JSON protocol. `tuios list-verbs` prints them all. |

A picture of the same thing:

```text
daemon
└── session "work"            (tuios new work)
    ├── workspace 1
    │   ├── window 0  name "editor"   tiled      pane: nvim
    │   ├── window 1  name "server"   tiled      pane: npm run dev
    │   └── window 2  name "scratch"  floating   pane: zsh
    ├── workspace 2
    │   └── window 0  name "claude"   tiled      pane: claude   agent: working
    └── workspace 3..9           (empty until you use them)
```

From inside any of those panes, the shell knows where it is:

```sh
echo "$TUIOS_ENV $TUIOS_SESSION $TUIOS_PANE_ID"
```

```text
1 work 98db8226-1829-468e-89a8-41a2baa0ddab
```

That is the whole model. Sessions hold workspaces, workspaces hold windows, a window is a pane, and a verb can reach any of them by session name and window id, index or name.

## A first session

Start tuios with no arguments:

```sh
tuios
```

It starts the daemon if none is running, creates or attaches a session, and draws one pane with your shell. You begin in **window-management mode**: the pane has a highlighted border and typing does not reach the shell yet.

::: howto
1. **Make a second pane.** Press <kbd>n</kbd>. The screen splits; tuios tiles new panes by default using binary space partitioning.

2. **Type into a pane.** Press <kbd>i</kbd> or <kbd>Enter</kbd> to enter terminal mode. Run something, for example `htop`.

3. **Get back out.** Press <kbd>Prefix</kbd> <kbd>Esc</kbd> (that is <kbd>Ctrl</kbd>+<kbd>b</kbd>, then <kbd>Esc</kbd>) or <kbd>Alt</kbd>+<kbd>Esc</kbd>. A bare <kbd>Esc</kbd> goes to the program, as it should.

4. **Move focus.** In window-management mode, <kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd> move between panes like vim. <kbd>Tab</kbd> cycles.

5. **Open the command palette.** Press <kbd>Ctrl</kbd>+<kbd>p</kbd> from either mode. Type a few letters of any action ("zoom", "layout", "rename") and press <kbd>Enter</kbd>. Everything in this manual that has a key also has a palette entry, so the palette is the way to discover keys.

6. **Zoom and unzoom.** Press <kbd>z</kbd> in window-management mode. The focused pane takes 95% of the screen; press again to restore.

7. **Switch workspace.** Press <kbd>2</kbd> for an empty workspace, make a pane there, press <kbd>1</kbd> to come back.

8. **Detach.** Press <kbd>Prefix</kbd> <kbd>d</kbd>. Your terminal is back to its own shell. The panes are still running in the daemon.

9. **Reattach.** Run `tuios ls` to see the session, then `tuios attach <name>` (or just `tuios`).

10. **Quit for real.** <kbd>Prefix</kbd> <kbd>q</kbd> quits the client. `tuios kill-session <name>` ends the session itself.
:::

::: tip
Run `tuios --show-keys` once while learning. It draws every key you press in an overlay, which makes mode switching and chords visible. <kbd>Prefix</kbd> <kbd>?</kbd> opens the help overlay, and holding <kbd>Prefix</kbd> shows the which-key popup of available chords.
:::

### The keys you will use on day one

| Key | Does |
| --- | --- |
| <kbd>Ctrl</kbd>+<kbd>p</kbd> | Command palette: search and run any action |
| <kbd>Alt</kbd>+<kbd>Space</kbd> | Launcher: start any program on `$PATH` |
| <kbd>n</kbd> | New pane (window-management mode) |
| <kbd>i</kbd> or <kbd>Enter</kbd> | Enter terminal mode |
| <kbd>Prefix</kbd> <kbd>Esc</kbd> or <kbd>Alt</kbd>+<kbd>Esc</kbd> | Back to window-management mode |
| <kbd>Prefix</kbd> <kbd>d</kbd> | Detach |
| <kbd>z</kbd> or <kbd>Prefix</kbd> <kbd>z</kbd> | Toggle pane zoom |
| <kbd>Prefix</kbd> <kbd>Space</kbd> | Toggle BSP tiling |
| <kbd>Prefix</kbd> <kbd>[</kbd> | Copy mode (vim scrollback) |
| <kbd>Prefix</kbd> <kbd>S</kbd> | Session switcher |
| <kbd>Prefix</kbd> <kbd>i</kbd> | The Inbox: everything your agents are waiting on |
| <kbd>Prefix</kbd> <kbd>,</kbd> | Settings page |
| <kbd>Prefix</kbd> <kbd>k</kbd> | Keybind manager |
| <kbd>Prefix</kbd> <kbd>?</kbd> | Help overlay |
| <kbd>Prefix</kbd> <kbd>q</kbd> | Quit |

The full tables, per mode and per config section, are in [Keybindings](keybindings.md).

## Driving it from a shell

Everything the keyboard can do, a command can do. Three commands cover most scripting:

```sh
# open a named window in this session without stealing focus
tuios new-window -s "$TUIOS_SESSION" build --cwd ~/proj/app --no-focus

# type a command into it and press Enter
tuios send-text -s "$TUIOS_SESSION" -w build 'make test' --enter

# read back what it printed, bounded
tuios capture-pane -s "$TUIOS_SESSION" -w build --scrollback --lines 40
```

Inside a pane, always pass `-s "$TUIOS_SESSION"` and address yourself as `-w "$TUIOS_PANE_ID"`; the defaults follow focus, and focus moves under you. [Sessions](sessions.md) has the addressing rules and the full pane toolkit, [Automation](automation.md) builds whole workflows from them, and [CLI Reference](cli.md) lists every command and flag.

## Agents, briefly

tuios is unusual among multiplexers in that it knows what the program in a pane is doing when that program is a coding agent. A pane running Claude Code, Codex, Gemini CLI, opencode or one of 24 detected CLIs shows a state (working, needs input, idle, done, errored) in its title and on the rail; <kbd>Prefix</kbd> <kbd>i</kbd> opens an Inbox listing every approval, question and finished turn across every session and machine; agents mail each other and ask you questions with fixed answers; `tuios fan` starts one prompt across several agents in separate git worktrees; and `tuios mcp` offers all of it as MCP tools. One command wires a harness up:

```sh
tuios integration install claude-code --mcp --statusline
tuios doctor agents
```

That whole world is [Agents](agents.md).

## How this manual is organised

| Chapter | Read it when you want to |
| --- | --- |
| [1. Start Here](tuios.md) | Install, learn the vocabulary, run a first session (this page) |
| [2. Core Concepts and the Screen](concepts.md) | Understand modes, tiling, layouts, the dock, the rail, overlays, copy mode, images and the mouse |
| [3. Keybindings and the Command Palette](keybindings.md) | Look up a key, rebind one, add command keys, use the palette and hints |
| [4. Configuration, Themes, Glyphs and Hooks](configuration.md) | Edit `config.toml` with every table and key, pick or write a theme, run hooks on events |
| [5. Daemon, Sessions, Hosts and Shims](sessions.md) | Detach and reattach, survive restarts, reach other machines, use the ssh server, the web client and the tmux shim |
| [6. Agents, Inbox, Mail, Fleets and MCP](agents.md) | Run coding agents in panes, answer them from the Inbox, let them talk, fan out fleets, serve MCP, scope grants |
| [7. CLI and Protocol Reference](cli.md) | Find any subcommand or flag, parse `--json`, speak the socket protocol, subscribe to events |
| [8. Tapes and Scripted Workflows](automation.md) | Script and record sessions with tapes, take screenshots, build startup layouts and shell-driven workflows |
| [9. How To: Extend tuios](howto-extending.md) | Add a command to the palette, add a dock component, write hooks, themes, harness integrations, MCP tools, verbs and more |
| [10. Ecosystem and Plugin Directory](ecosystem.md) | Find third-party dock components, themes, integrations, editor plugins and related tools, with links |

### Conventions used throughout

- Keys are drawn as keycaps: <kbd>Ctrl</kbd>+<kbd>b</kbd> is one chord; <kbd>Prefix</kbd> <kbd>d</kbd> (with a space) is press-release-press.
- Every example is for v0.8.5 and was checked against the binary's own `--help`, the `tuios list-verbs` catalogue, or the source tree at tag `v0.8.5`.
- Callouts mark notes, tips, warnings, worked examples and default values. Green numbered steps mark a how-to.
- `$TUIOS_SESSION` and `$TUIOS_PANE_ID` in examples are the environment variables a pane already has; outside a pane, substitute a session name and a window name.
- Press <kbd>/</kbd> on any page of this manual to search its sections, <kbd>[</kbd> and <kbd>]</kbd> to move between chapters, and <kbd>t</kbd> to switch between light, dark and automatic themes.

## Where to get more

| Source | What it is |
| --- | --- |
| `tuios --skill` and `tuios --skill all` | The agent-facing guide embedded in the binary; always matches the build you run |
| `tuios <command> --help` | Authoritative flags for that build |
| `tuios list-verbs [VERB]` | The protocol catalogue with every argument |
| `tuios keybinds list`, `tuios keybinds explain <key>`, `tuios keybinds doctor` | Your effective keys |
| `tuios list-options` | Every configuration option |
| [tuios.dev](https://tuios.dev) | Hosted documentation |
| [tuios.dev/learn](https://tuios.dev/learn) | The guided tour: the real app compiled to WebAssembly |
| [github.com/Gaurav-Gosain/tuios](https://github.com/Gaurav-Gosain/tuios) | Source, releases, `docs/` folder |
| [deepwiki.com/Gaurav-Gosain/tuios](https://deepwiki.com/Gaurav-Gosain/tuios) | Generated wiki over the source |
