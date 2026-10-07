---
title: "TUIOS: How To Extend tuios"
template: tuios-manual
manual: tuios
chapter: 9
summary: Step-by-step recipes for extending tuios v0.8.5, from adding a command to the command palette and a component to the dock, through hooks, themes, harness integrations, MCP tools, protocol verbs, tape commands and more, each marked as config-only or needing Go.
tags:
  - tuios
  - howto
  - extending
  - plugins
  - go
---

tuios has no plugin loader. What it has is a set of deliberate seams: a config file that can declare commands and dock cells, hooks that run shell commands on events, JSON theme and glyph files, TOML harness manifests, a protocol anyone can speak, and a Go codebase with tests that enforce the few invariants a contributor must keep. This chapter is a cookbook for those seams. Every recipe says up front whether it needs Go, lists the exact files and keys, shows real code, and ends with how to verify the result. Everything was checked against the v0.8.5 source tree and binary; where a recipe was applied to a copy of the tree and built, the section says so.

The first two recipes, adding a command to the command palette and adding a dock component, are the ones most people want and are written at full length. The rest follow in the order a contributor meets them.

## Where tuios opens up

| Extension point | Needs Go? | Where it lives | Recipe |
| --- | --- | --- | --- |
| A command in the command palette, bound to a key | no | `[[keybindings.command]]` in `config.toml` | [How to add a command to the command palette](#how-to-add-a-command-to-the-command-palette) |
| A built-in palette row or a new keybinding action | yes | `internal/app/command_palette.go`, `internal/input/actions.go` | same, Go route |
| A dock component | no | `[dock.custom.NAME]` in `config.toml`, a shell script | [How to add a dock component](#how-to-add-a-dock-component) |
| A built-in dock component | yes | `internal/config/dock.go`, `internal/app/dock_*.go` | same, Go route |
| A shell command on an event | no | `[hooks]` | [Hooks](#how-to-run-a-shell-command-on-an-event-hooks) |
| A theme | no (yes for a bundled one) | `~/.config/tuios/themes/*.json` | [Themes](#how-to-write-a-theme) |
| A glyph set | no | `[appearance]` and a glyph file | [Glyph sets](#how-to-define-a-glyph-set) |
| A new keybinding action | yes | `internal/input`, `internal/config` | [Keybinding action](#how-to-add-a-new-keybinding-action-in-go) |
| Support for a new coding-agent harness | no for detection, yes for hooks | `~/.config/tuios/harnesses/*.toml`, `internal/integration` | [Harness integration](#how-to-add-a-harness-integration) |
| An MCP tool | yes | `internal/mcp/tools.go` | [MCP tool](#how-to-add-an-mcp-tool) |
| A protocol verb and CLI subcommand | yes | `internal/session`, `cmd/tuios` | [Verb](#how-to-add-a-protocol-verb-and-its-cli-subcommand) |
| A skill topic for agents | yes (Go embed) | `skills/tuios/*.md` | [Skill topic](#how-to-add-a-skill-topic) |
| A tape command | yes | `internal/tape` | [Tape command](#how-to-add-a-tape-command) |
| A context-menu entry | yes | `internal/app/contextmenu_build.go` | [Context menu](#how-to-add-a-context-menu-entry) |
| A config option | yes | `internal/config/options.go`, settings page | [Config option](#how-to-add-a-config-option-end-to-end) |
| A sound cue, quiet hours | no | `[notifications.agent]` | [Sounds](#how-to-add-a-sound-cue-and-quiet-hours) |
| Another machine | no | `[hosts]`, `tuios hosts add` | [Hosts](#how-to-add-another-machine-hosts) |
| tuios inside your own Go program | yes | `pkg/tuios` | [Library](#how-to-embed-tuios-in-a-go-program) |
| A herdr tool talking to tuios | no | the `.herdr` socket | [herdr client](#how-to-talk-to-tuios-as-a-herdr-client) |

::: tip
Before any Go recipe, read [Contributor conventions](#contributor-conventions) at the end of this chapter for the build, test and lint commands, and the note about leaving the machine usable while the suite runs.
:::

## How to add a command to the command palette

The command palette (<kbd>Ctrl</kbd>+<kbd>p</kbd>, or <kbd>Prefix</kbd> <kbd>P</kbd>, or <kbd>/</kbd> with the rail focused) is a fuzzy-searchable list of rows. There are two ways to put a row of your own in it.

| | Config route: `[[keybindings.command]]` | Go route: a built-in row |
| --- | --- | --- |
| Needs Go | no | yes |
| Palette category | always `Commands` | any (`Window`, `Layout`, ...) or a new one |
| Key required | yes; an entry without a key is ignored | no; a row can exist with no key at all |
| Takes effect | on save, for the row and the command; a new key in the next client | after rebuilding the binary |
| Rebindable in the keybind manager | no, edit `config.toml` | only if you also add an action |

::: note
Everything in this section was verified on a patched copy of the v0.8.5 tree: the config examples were loaded through the real config loader and validator and turned into palette rows, and the Go example was applied, built and run through the test suite. Line references are into the v0.8.5 source.
:::

### How the palette is put together

A palette row is plain data (`internal/app/command_palette.go:79-110`):

```go
type CommandPaletteItem struct {
	Name       string // "Split horizontal"
	Shortcut   string // the muted text on the right: a key such as "prefix+v", written by hand
	Category   string // "Window", "Layout", "Session", "Navigation", "Clipboard", ...
	Match      []int  // filled in by the fuzzy filter
	AgentState string // session and window rows only; what "@" filters on
	AgentSeen  bool
	Keybind    bool   // reachable only behind the "#" token
	Setting    bool   // settings-page row: hidden from the empty query
	Action     func(m *OS) (*OS, tea.Cmd)
}
```

A row has no link to a keybinding action: `Shortcut` is a literal string, and the palette calls `Action` directly rather than going through the key dispatcher. When the palette opens, `rebuildPaletteItems` (`command_palette_nav.go:22-45`) concatenates five lists in this order, and that order decides the category headers you see with an empty query:

```js
PaletteItems = [
  // 1. the static built-ins, GetCommandPaletteItems()           command_palette.go:113
  { Name: "Rotate split", Shortcut: "prefix+R", Category: "Layout", Action: fn },
  // 2. your [[keybindings.command]] entries, commandPaletteItems()  command_keys.go:272
  { Name: "Lazygit in a new pane", Shortcut: "prefix+alt+g", Category: "Commands", Action: fn },
  // 3. sessions, windows and mail, getSessionPaletteItems()
  { Name: "Window: nvim", Category: "Sessions", AgentState: "working", Action: fn },
  // 4. one row per bound action, only behind "#"
  { Name: "Rotate split  rotate_split", Shortcut: "ctrl+b R", Category: "Keybind", Keybind: true },
  // 5. one row per settings-page row, only when typed for
  { Name: "Pane gap", Category: "Settings", Setting: true },
]
```

With an empty query the rows are grouped by category in order of first appearance: `Run`, `View`, `Window`, `Clipboard`, `Layout`, `Navigation`, `Session`, `Keybind`, `Agents` (only after an agent has been seen), then `Commands` (your entries), then `Sessions`. A typed query runs the fuzzy matcher over `Name`; rows that match only by category come after, so typing `commands` lists every config entry. Two prefixes change the search: `@state` keeps only session and window rows in that agent state (`@a` attention, `@w` working, `@n` needs input, `@d` done, `@i` idle, `@e` errored), and `#` lists one row per bound action with its current keys. The full usage is in [Keybindings](keybindings.md#the-command-palette).

### Config route: a `[[keybindings.command]]` entry

Each entry is one element of a TOML array of tables. The struct is `internal/config/command_keys.go:47-66`.

| Field | Type | Required | Default | Meaning |
| --- | --- | --- | --- | --- |
| `key` | string | **yes** | none | The key that runs it. `prefix+X` means after the leader (the `prefix_mode` scope). Any other key is global, which covers window mode and terminal mode. |
| `type` | string | no | `popup` | `scratch`, `popup`, `pane` or `shell`, case-insensitive. |
| `command` | string | yes, except for `scratch` | none | Run with `sh -c`. A `scratch` entry with no command runs your shell. |
| `description` | string | no | `Run <command>` | The row name in the palette and in `tuios keybinds list`. |
| `name` | string | no | a slug of the description, else of the command, else of the key | Stable identity; the action is `command:<name>`. A slug is lowercase ASCII letters and digits joined by single dashes, at most about 40 characters. |
| `width`, `height` | string | no | `80%` | Size of a `scratch` or `popup` box, in cells (`"100"`) or percent (`"80%"`). |

What each `type` does when the key is pressed or the row is run:

| type | What happens | Where it runs | Ends |
| --- | --- | --- | --- |
| `scratch` | Shows or hides a scratch terminal of its own, keyed by `name`; each press toggles it | the local daemon only; refused in a session on another machine | when the command exits; the next press starts it again |
| `popup` (default) | Opens a floating pane sized by `width` and `height`, titled with the description, with focus and terminal mode | local only; in a remote session the dock says "A popup command works only in a session on this machine." | when the command exits |
| `pane` | Opens a new tiled pane next to the focused one, titled with the description; the keyboard goes to it | the session's own daemon, so on the remote machine in a remote session | when the command exits |
| `shell` | Runs in the background with stdin, stdout and stderr on `/dev/null`, in its own session with no controlling terminal | the machine of the tuios client (the server for `tuios ssh` or tuios-web) | waits for exit; a nonzero exit shows "The command <description> failed: exit status N", success shows nothing |

The command always runs as `sh -c "<command>"`, started in the focused pane's directory when that is local and exists (otherwise `$HOME`; in a remote session, the directory the remote pane reported with OSC 7). There are no timeouts. It receives these variables on top of the new pane's environment (or, for `shell`, the client's environment):

| Variable | Value |
| --- | --- |
| `TUIOS_SESSION` | the session name |
| `TUIOS_ACTIVE_PANE_ID` | the focused pane's id (absent if nothing has focus) |
| `TUIOS_ACTIVE_PANE_CWD` | the start directory above |
| `TUIOS_SOCKET` | the local daemon socket; set only in a daemon session on this machine |

::: howto
1. **Pick a key nothing else uses.** Check with `tuios keybinds explain <key>`; "free" is what you want. The leader's own keys in v0.8.5 are listed in [Keybindings](keybindings.md#keybindings.prefix_mode).

    ```sh
    tuios keybinds explain alt+g
    ```

2. **Add the entry** to `~/.config/tuios/config.toml` (`tuios config edit` opens it in `$EDITOR`, `tuios config path` prints its path).

    ```toml
    [[keybindings.command]]
    key = "prefix+alt+g"
    type = "pane"
    command = "lazygit"
    description = "Lazygit in a new pane"
    ```

3. **Save.** The palette row and the command are live immediately: the palette re-reads your config every time it opens. The key itself works in the next client you start, because a reload does not rebuild the key map.

4. **Open the palette and type a few letters.** With an empty query the row sits under the **Commands** header, named by its description, with `prefix+alt+g` in muted text on the right. The palette always writes `prefix+`, never your actual leader key.

5. **Confirm from a shell.**

    ```sh
    tuios keybinds list        # a Commands table after the built-in sections
    tuios keybinds doctor      # reports dead or shadowed entries
    ```

    ```text
    ctrl+b alt+g │ Lazygit in a new pane
    ```
:::

#### Example: run a script against the focused pane

A `shell` entry can call `tuios` itself, because `TUIOS_ACTIVE_PANE_ID` names the focused pane. This one saves the pane's scrollback to a file:

```toml
[[keybindings.command]]
key = "prefix+alt+s"
type = "shell"
command = "mkdir -p ~/tuios-captures && tuios capture-pane -s \"$TUIOS_SESSION\" -w \"$TUIOS_ACTIVE_PANE_ID\" --scrollback > ~/tuios-captures/\"$TUIOS_ACTIVE_PANE_ID\"-$(date +%Y%m%d-%H%M%S).txt"
description = "Save pane scrollback to a file"
```

The palette row is "Save pane scrollback to a file" with `prefix+alt+s`. Nothing appears on screen when it works; on failure the dock shows the error notification. `tuios` must be on the client's `PATH`, since a `shell` entry inherits the client's environment. To see a script's output instead, use `type = "popup"`.

#### Example: a palette-first entry

`key` is mandatory, so there is no true palette-only entry. The clean workaround is a key nobody presses:

```toml
[[keybindings.command]]
key = "prefix+f12"
type = "popup"
command = "htop"
description = "System monitor (htop)"
width = "90%"
height = "90%"
```

Typing `htop` makes it the first hit. The alternative, giving the entry a key a built-in already owns, produces a row with an empty right-hand column but costs a conflict warning at every start and a `dead:` line in `tuios keybinds doctor`; use the unused-key form unless the empty column matters.

#### Validation and the keybind tools

Every problem with an entry is a warning, never an error, and a faulty entry is simply left out of the key map and the palette. The messages, each ending in "tuios ignores this entry.", are:

| Condition | Message |
| --- | --- |
| no `key` | The entry has no key. Add a key, for example key = "prefix+alt+g". |
| unknown `type` | The type "x" is not known. Use scratch, popup, pane or shell. |
| no `command` (not scratch) | The entry has no command. Add a command. |
| no usable name | The entry has no name tuios can use. Add a name with letters or digits. |
| name is `scratch` | The name scratch belongs to the built-in scratch terminal. Use a different name. |
| bad width or height | The width is not valid: ... |
| duplicate name | An earlier entry has the name "x". Add a different name. |

Two warnings keep the entry: a global key that is a single printable character ("The key y has no modifier and no prefix+, so tuios takes it from every pane"), and a key already used by a built-in action, which keeps the key while the entry becomes dead ("ctrl+b c runs prefix_new_window. These never run: command:...").

::: warning
Warnings are reported only when a client starts, as `Config:` lines in the log viewer and a toast counting them. A live reload reports nothing, so after editing, run `tuios keybinds doctor`.
:::

`tuios keybinds` has `list`, `list-custom`, `doctor`, `explain <key>`, `free <key>` and `unbind <action> [key]`; there is no `edit` subcommand. Pass the bare key to `explain` (`alt+g`, not the full chord). Command entries show up in the keybind manager (<kbd>Prefix</kbd> <kbd>k</kbd>) and under the palette's `#` token, but rebinding or unbinding them there is a no-op and `tuios keybinds unbind command:<name>` fails; the way to move a command key is to edit `key` in the file. The settings page has no rows for them.

::: note
A config reload never runs an entry. Only a key press or a palette row does. A pane holding the `respond` grant can press keys through `run-command`, so it can trigger one.
:::

### Go route: a built-in palette row

A built-in row lives in the static list in `GetCommandPaletteItems` and can sit in any category, with or without a key. The worked example is **"Show the focused pane's id"**, which puts `Pane id: <id>` on the dock, the id that `tuios send-keys -w` accepts. "Rotate split" already exists in v0.8.5 (`command_palette.go:324-335`, action `rotate_split`, `prefix+R`), so it is not the example. The snippets below were applied to a copy of the tree, built, and run through the tests.

#### Step 1 to 4: the row alone

::: howto
1. **Write the behaviour as a method on `OS`.** New file `internal/app/pane_id.go`:

    ```go
    package app

    // ShowFocusedPaneID puts the focused pane's id on the dock: the id that
    // tuios send-keys -w and the other verbs take.
    func (m *OS) ShowFocusedPaneID() {
    	w := m.GetFocusedWindow()
    	if w == nil {
    		m.ShowNotification("No pane has the focus", "warning", m.Settings.NotificationDuration)
    		return
    	}
    	m.ShowNotification("Pane id: "+w.ID, "info", m.Settings.NotificationDuration)
    }
    ```

    `ShowNotification(message, type string, duration time.Duration)` is in `internal/app/os_notify.go:202`; the types are `info`, `success`, `warning` and `error`.

2. **Add the row.** In `internal/app/command_palette.go`, inside the `items := []CommandPaletteItem{` literal of `GetCommandPaletteItems` (line 113), among the `Window` rows, before `"Toggle zoom"` (line 216):

    ```go
    		{
    			Name:     "Show the focused pane's id",
    			Category: "Window",
    			Action: func(m *OS) (*OS, tea.Cmd) {
    				m.ShowFocusedPaneID()
    				return m, nil
    			},
    		},
    ```

    Conventions of the surrounding rows: `Shortcut` is the default key spelled `prefix+X` (or `prefix+D l` for a sub-prefix, or a bare key such as `S` for window mode), left out when there is no default key; settings are read from the function's `s *config.Settings` parameter; return `m, cmd` when the method returns a `tea.Cmd`. To show a row only in some states, filter it in `rebuildPaletteItems` (`command_palette_nav.go:22-36`) rather than making `GetCommandPaletteItems` depend on state, because tests call it with `&config.Global` alone.

3. **Build and run the palette tests.**

    ```sh
    go build ./cmd/tuios
    go test ./internal/app/ -run 'Palette|TestEveryWayOfTurningTilingOffAgrees|Agent' -count=1
    go test ./internal/input/ ./internal/config/ -count=1
    ```

    No coverage test requires a palette row to have an action, a description or a key; a row by itself passes. The tests that touch rows are listed below.

4. **Check it in the palette.**

    ```sh
    go build -o /tmp/tuios ./cmd/tuios
    /tmp/tuios --standalone
    ```

    Press <kbd>Ctrl</kbd>+<kbd>p</kbd>, type `pane id`, press <kbd>Enter</kbd>. The dock shows `Pane id: <id>`; compare with `/tmp/tuios list-windows`. With an empty query the row appears in the **Window** run with nothing on the right.
:::

Tests that run or inspect the static rows:

| Test | What it does | What it means for a new row |
| --- | --- | --- |
| `TestEveryWayOfTurningTilingOffAgrees` (`internal/app/tiling_switch_test.go`) | runs the `Action` of every `Layout` row | a new `Layout` row must not panic and must keep the tiling invariants |
| `TestPaletteFindsAgentActionsByWord` (`internal/app/agent_discover_test.go`) | `agent` must rank four `Agents:` rows first; `inbox` and `mailbox` must find an Agents row first | do not put "agent", "inbox" or "mailbox" in a non-Agents name |
| `TestUnbindIsFindableByItsOwnWord` (`command_palette_keybinds_test.go`) | `unbind` and `rebind` must hit an action row first | do not outrank them |
| `TestPaletteStateFilterDropsCommands` (`command_palette_reach_test.go`) | `@w` returns only stateful rows | do not set `AgentState` on a static row |
| `runPaletteCommandForTest` (`internal/input/rename_titles_hidden_test.go`) | looks rows up by exact `Name` | do not rename existing rows |

At this point the row is in the palette only: no key, no `#` row, nothing in help or `tuios keybinds`.

#### Step 5 to 9: make it a real action

::: howto
5. **Register a handler.** In `internal/input/actions.go`, in `NewActionDispatcher` next to `d.Register("start_screensaver", ...)` (line 148):

    ```go
    	d.Register("show_pane_id", handleShowPaneID)
    ```

    and the handler, next to the others (for example after `handleScreenshotScreen`, line 701):

    ```go
    // handleShowPaneID shows the focused pane's id on the dock.
    func handleShowPaneID(_ tea.KeyPressMsg, o *app.OS) (*app.OS, tea.Cmd) {
    	o.ShowFocusedPaneID()
    	return o, nil
    }
    ```

    The row and the handler call the same `OS` method; that is the pattern for every action (compare `smart_split`: row at `command_palette.go:296`, handler at `actions.go:717`). Prefix-only actions are named `prefix_*` and registered in `prefix_actions.go`.

6. **Describe it.** In `internal/config/registry.go`, in `ActionDescriptions` (line 418), for example after `"screenshot_screen"`:

    ```go
    	"show_pane_id":       "Show the focused pane's id",
    ```

    Run `gofmt`. Skipping this is not fatal: the action falls back to the name with underscores replaced by spaces in the keybind manager, `#` rows and `tuios keybinds`. Adding a description **without** a handler fails `TestEveryDescribedActionIsHandled`.

7. **Choose: no default key, or a default key.**

    *No default key:* add it to `actionsWithNoDefaultBinding` in `internal/input/reachability_test.go` (line 388 onward, next to `screenshot_screen`):

    ```go
    	// The focused pane's id on the dock. No key is clearly free.
    	"show_pane_id": "palette row, user binding",
    ```

    Skip it and the suite fails with:

    ```text
    --- FAIL: TestEveryRegisteredActionIsBoundOrListed
        reachability_test.go:494: "show_pane_id" is registered, has no default key, and is not listed in actionsWithNoDefaultBinding: say which surface reaches it, or bind it
    ```

    *A default key:* add it to a section of `DefaultConfig()` in `internal/config/userconfig.go`, for example `PrefixMode` after `"prefix_command_palette": {"P"},` (line 998):

    ```go
    				"show_pane_id":              {"I"},
    ```

    Then remove it from `actionsWithNoDefaultBinding` if you added it there, add a which-key row in `internal/config/keybindings.go` (the leader's groups in `GetPrefixKeybindingGroups`, line 72 onward):

    ```go
    		kb("I", "Show pane id"),
    ```

    and set the palette row's `Shortcut: "prefix+I"`. Skipping the which-key row fails `TestWhichKeyTablesMatchTheKeymap/leader` ("leader prefix binds "show_pane_id" to [I], and the which-key panel lists none of them"). `TestEveryDefaultBindingReachesItsAction` then presses the key in window mode and terminal mode for you. Check the key is free first: in v0.8.5 the leader already uses `c x r , k n tab p shift+tab arrows ) ( a 0-9 space w m t d X esc [ ? D T q z - | \ R = s C P f b S W L e j M i o v O F g V`.

8. **Optional surfaces** that no test enforces: the help overlay's `prefixActions` list (`internal/app/help.go:584-603`) so it shows under <kbd>Prefix</kbd> <kbd>?</kbd>; a section in `cmd/tuios/keybinds_commands.go:51-101` so `tuios keybinds list` shows it (that list is hand-written; `doctor` shows every action); `internal/app/learn_mode.go` if the web demo must block it.

9. **Run the guards.**

    ```sh
    go build ./cmd/tuios
    go test ./internal/input/ -run 'TestEveryRegisteredActionIsBoundOrListed|TestEveryDescribedActionIsHandled|TestEveryDefaultBindingReachesItsAction|TestReachabilityTableCoversEveryBindingSection' -count=1
    go test ./internal/config/ -run 'TestWhichKeyTablesMatchTheKeymap|TestWhichKeyLeaderCoversTheDaemonRows' -count=1
    go test ./internal/app/ -run 'Palette|TestEveryWayOfTurningTilingOffAgrees|Agent' -count=1
    ```
:::

What you get: with a default key, typing `#show` or `#pane id` in the palette lists `Show the focused pane's id  show_pane_id` with `ctrl+b I`, and <kbd>Enter</kbd> opens the keybind manager on that action. Without a default key the `#` list shows nothing for it until someone binds it, which they can do in the keybind manager, with `tuios keybinds unbind show_pane_id I`, or in `config.toml`:

```toml
[keybindings.prefix_mode]
show_pane_id = ["alt+i"]
```

::: note
On a Mac, eight tests fail before any change: four kitty-graphics tests in `internal/app` (`/private/var` versus `/var` paths), `TestMultiCopySavePathMessages`, `TestMCPServerWithoutAPaneReachesNothing` in `cmd/tuios`, and `TestHerdrConformanceCollie` and `TestTerminalWindowFromPaneIsAllowed` in `internal/session`. They are environmental. With the whole worked example applied, `go test -short ./...` showed no new failures.
:::

#### Files touched

| File | Change |
| --- | --- |
| `internal/app/pane_id.go` (new) | `ShowFocusedPaneID()` |
| `internal/app/command_palette.go` (~216) | the palette row, with `Shortcut: "prefix+I"` if you chose a default key |
| `internal/input/actions.go` (148, ~705) | `d.Register("show_pane_id", handleShowPaneID)` and the handler |
| `internal/config/registry.go` (504) | `ActionDescriptions["show_pane_id"]` |
| `internal/input/reachability_test.go` (472) | `actionsWithNoDefaultBinding` entry, if no default key |
| `internal/config/userconfig.go` (998), `internal/config/keybindings.go` (140) | default key and which-key row, if a default key |
| optional | `internal/app/help.go`, `cmd/tuios/keybinds_commands.go`, docs |

#### Docs the maintainer updates

`docs/KEYBINDINGS.md` is organised as one `##` section per feature, not as a table of keys; follow the pattern of "Close every pane on a workspace": name the action, say whether it has a default key, name the palette row in quotes, and give a TOML binding example. The house phrase for a keyless action is "The action has no default key. The command palette has the entry "...". To bind it, add it to a section:" followed by a `[keybindings.prefix_mode]` snippet. Also `docs/release-notes/vX.Y.Z.md`, and `skills/tuios/config.md` if agents should know about it. Commit messages follow conventional commits (`feat: ...`, `docs: ...`).

## How to add a dock component

The dock is the bar along the top or bottom of the screen. Its cells are *components*, and tuios lets you add your own without touching Go: a `[dock.custom.<name>]` table in `config.toml` names a shell command, and whatever that command prints becomes a cell. This is what tuios calls a dock component and what most people mean by a dock plugin. The second route, a built-in component written in Go, is for a value that must be computed inside the client with no subprocess; it is covered at the end of this section.

::: note
Everything in this section was verified against the v0.8.5 binary. Each recipe was run in the project's own end-to-end harness against an isolated daemon, and the dock text quoted is what it drew. File and line references are into the v0.8.5 source tree.
:::

### The contract in one page

| Aspect | Rule |
| --- | --- |
| Declaration | `[dock.custom.NAME]` with `command`, and optionally `refresh`, `on-click`, `max-width`. There are no other keys. |
| Placement | Add `custom/NAME` to `dock.left`, `dock.center` or `dock.right`. A defined table that is on no list draws nothing and warns. |
| What runs | `sh -c "<command>"`, stdin closed, stderr discarded, cwd is the client's, timeout fixed at 3 seconds, 64 KiB of stdout read at most. |
| What shows | The first line of stdout. ANSI colour (SGR) is kept; every other escape, every C0 control and tab is stripped. Empty output hides the cell. Nonzero exit hides the cell and counts as a failure. |
| Width | Truncated to `max-width` cells (default 24, maximum 80) with an ellipsis; one column of padding is added on each side. |
| Refresh | `once` (default), `push`, `event:TYPE[,TYPE...]`, or a duration such as `"30s"` (floor 1s). |
| Clicks | `on-click` is a separate command run with `TUIOS_CLICK_BUTTON` set; right-click opens the dock menu instead. The cell does not re-run after a click unless the click command asks for it. |
| Failure | The first failure of a streak is announced once as a toast and a log line. After five consecutive failures the component stops until `tuios refresh-dock NAME`. |
| Reload | Editing `config.toml` hot-reloads the whole dock engine. The settings page's dock editor edits only the lists. `tuios set-config` cannot set `dock.left`, `dock.right`, `dock.center` or `dock.custom.*`. |
| Where it runs | In the client process: your machine for a local client, the server for tuios-web or SSH clients. |

::: warning
Spelling matters and nothing warns you. The keys are `on-click` and `max-width` with hyphens, unlike every other tuios table. `on_click` and `max_width` are silently ignored, and the JSON that `tuios list-dock-components --json` prints uses the underscore spelling, which makes the mistake easy. Keys that do not exist at all, such as `interval`, `timeout`, `icon`, `color`, `tooltip`, `env` or `cwd`, are likewise ignored.
:::

### The `[dock]` table

The three region lists and the built-in components come first, because a custom cell is placed among them.

```toml
# These are the defaults; a config with no [dock] table draws exactly this bar.
[dock]
left   = ["mode", "workspaces", "trail", "tape"]
center = ["windows"]
right  = ["notifications", "copy-help", "cpu", "ram", "clock", "session-controls"]

[dock.clock]
format = ""      # Go layout; empty follows appearance.clock_format (15:04:05)
```

A list that is omitted keeps its default. A list set to `[]` draws nothing on that side. Both survive a save from the settings page.

| Built-in | Draws | Its own gate | Side |
| --- | --- | --- | --- |
| `mode` | The mode pill (terminal, window, copy, tiling, zoom `Z`, `SIDEBAR`, `HOLD`) | none | left only |
| `workspaces` | The clickable workspace strip | `appearance.dock_workspace_tabs`, and at least two tabs | left only |
| `trail` | The `workspace:windows` readout; a host relink notice while one is live | none | left only |
| `tape` | The project-tape badge when the focused cwd has `.tuios.tape` | badge present | left only |
| `windows` | Minimized windows plus a clickable `...` overflow marker | some window minimized | pinned centre |
| `notifications` | The transient message block | a live message | pinned right |
| `copy-help` | Copy-mode key help | focused pane in copy mode | pinned right |
| `cpu` | `CPU:` sparkline and percentage | `appearance.show_cpu` | right |
| `ram` | `RAM: NN.N%` | `appearance.show_ram` | right |
| `clock` | The clock cell, formatted by `[dock.clock] format` | `appearance.show_clock` | any side |
| `session-controls` | Leave, close and new-session buttons | width of at least 34 columns | pinned right, always last |

::: warning
Only custom cells and `clock` can be moved freely between sides. `mode`, `workspaces`, `trail` and `tape` are drawn by the left block's loop alone (`internal/app/render_dock.go:308-335`): listed in `center` or `right` they draw nothing, and there is no warning. The pinned components (`windows`, `notifications`, `copy-help`, `session-controls`) are moved back to their side with a warning. `cpu` and `ram` form one segment, emitted where the first of them is listed, and are meant for the right.
:::

The clock's cadence follows its format: a layout containing seconds (`05`, `.0`, `.9` or `5.`) refreshes every second, anything else every minute. `dock.clock.format` is the only `[dock]` key that `tuios set-config` accepts.

Config mistakes in the `[dock]` table are warnings, never fatal, and they appear **only at client startup** as `Config:` lines in the log viewer with a five-second toast counting them. A mistake introduced by a hot reload is not announced, so after editing, check with `tuios list-dock-components`.

### The `[dock.custom.NAME]` schema

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `command` | string | required | Run as `sh -c`. Empty or missing drops the component from the plan with the warning "component has no command, so it can never draw anything". |
| `refresh` | string | `"once"` | `once`: run at startup, reload and `refresh-dock`. `push`: a long-running command; each line it prints replaces the cell. `event:TYPE,...`: re-run 200 ms after any listed event. A Go duration (`"5s"`, `"1m"`): poll; values under 1s are raised to 1s. Anything else warns and falls back to `once`. |
| `on-click` | string | none | Run as `sh -c` when the cell is left- or middle-clicked, with `TUIOS_CLICK_BUTTON` set to `1` or `2`. No timeout. |
| `max-width` | int | 0, meaning 24 | Width in cells before truncation with an ellipsis. Values below 1 or above 80 warn and fall back to 24. |

The event types accepted by `refresh = "event:..."` are the nine hook events, each also accepted under its event-hub alias:

| Hook name | Alias |
| --- | --- |
| `after-new-window` | `window-created` |
| `after-close-window` | `window-closed` |
| `after-focus-change` | `window-focused` |
| `after-workspace-switch` | `workspace-switched` |
| `after-agent-state` | `agent-state` |
| `after-layout-change` | `layout-changed` |
| `after-attach` | `attached` |
| `after-detach` | `detached` |
| `after-resize` | `resized` |

`after-command-finished` is deliberately not accepted, because only the daemon sees the OSC 133 marks that raise it. Events fire whether or not a `[hooks]` table exists.

### What your command sees

The command inherits the client's whole environment plus:

| Variable | Value |
| --- | --- |
| `TUIOS_DOCK_COMPONENT` | The short name, without `custom/` |
| `TUIOS_SESSION` | The client's session name, re-stamped on attach, session switch and host reconnect; empty for an unnamed standalone session |
| `TUIOS_SOCKET` | The daemon socket path, for information; `XDG_RUNTIME_DIR` still decides which daemon a `tuios` call reaches |
| `TUIOS_CLICK_BUTTON` | `on-click` only: `1` left, `2` middle |

`TUIOS_PANE_ID` is **not** set, because the dock belongs to the client, not to a pane. A component that needs "the focused pane" asks for it:

```sh
tuios list-windows ${TUIOS_SESSION:+-s "$TUIOS_SESSION"} --json | jq -r '.windows[] | select(.focused) | .cwd'
```

The working directory is the client's, the shell is always `sh`, and a leading `~` in `command` is expanded by `sh`.

### What your command may print

- **One line.** Trailing newlines are trimmed, then everything after the first newline is discarded.
- **Colour, yes.** `ESC[...m` sequences made of digits and semicolons are kept: `\033[31m`, `\033[1;32m`, `\033[38;5;208m`, `\033[38;2;r;g;bm` and the bare reset `\033[m`. Colon-form SGR (`38:2:...`) is dropped.
- **Nothing else.** Cursor movement, OSC titles, DCS, every C0 control and DEL are removed, including tabs: `tab\tseparated` draws as `tabseparated`. Use spaces to separate.
- **Empty means hidden.** Printing nothing, or an empty line from a `push` command, hides the cell and is not a failure.
- **Nonzero exit means hidden and failed**, even if something was printed.
- The cell is drawn as one space, your text, one space, on the theme's panel colour in the dimmed foreground colour. A reset inside your text returns to the terminal default foreground, not to a transparent hole.

### Step by step: your first component

::: howto
1. **Make a directory for dock scripts and write one.**

    ```sh
    mkdir -p ~/.config/tuios/dock
    cat > ~/.config/tuios/dock/hello.sh <<'SH'
    #!/bin/sh
    printf '\033[36mhello\033[0m %s\n' "$(date +%H:%M)"
    SH
    chmod +x ~/.config/tuios/dock/hello.sh
    ```

2. **Run it by hand with the environment the dock would give it.** stderr is never shown by the dock, so this is where you see errors.

    ```sh
    TUIOS_DOCK_COMPONENT=hello TUIOS_SESSION="$TUIOS_SESSION" sh -c '~/.config/tuios/dock/hello.sh'; echo "exit $?"
    ```

3. **Declare it and place it.** Add to `~/.config/tuios/config.toml`:

    ```toml
    [dock]
    right = ["notifications", "copy-help", "custom/hello", "cpu", "ram", "clock", "session-controls"]

    [dock.custom.hello]
    command = "~/.config/tuios/dock/hello.sh"
    refresh = "30s"
    ```

    Keep the whole `right` list when you add to it; a list you write replaces the default.

4. **Save.** The file watcher reloads the dock engine; the cell appears without a restart.

5. **Check it from a shell.**

    ```sh
    tuios list-dock-components
    ```

    ```text
    │ COMPONENT    │ SIDE  │ SOURCE │ REFRESH      │ STATE │ READS       │
    │ custom/hello │ right │ custom │ interval 30s │ drawn │ hello 14:05 │
    ```

6. **Force a run whenever you like.**

    ```sh
    tuios refresh-dock hello
    ```

    ```text
    Refreshed dock component "hello".
    ```
:::

::: tip
Both `list-dock-components` and `refresh-dock` need an attached client in the session. Without one they fail with `needs_client` and the message "no client is attached, so no dock is drawn". Pass `-s SESSION` when you are not inside the session.
:::

### Recipe: git branch of the focused pane, event-driven

This improves on the shipped `examples/dock/git-branch.sh`, which asks the most recently active session instead of the client's own and, in v0.8.5, is missing its icon glyph between two escape sequences, so it draws with a bare leading space.

`~/.config/tuios/dock/git-branch.sh`:

```sh
#!/bin/sh
# Dock component: git branch of the focused pane's directory, "*" when dirty.
set -eu
dir=""
if command -v jq >/dev/null 2>&1; then
	dir=$(tuios list-windows ${TUIOS_SESSION:+-s "$TUIOS_SESSION"} --json 2>/dev/null |
		jq -r '.windows[] | select(.focused) | .cwd // empty' 2>/dev/null) || dir=""
fi
[ -n "$dir" ] || dir=$PWD
branch=$(git -C "$dir" branch --show-current 2>/dev/null) || exit 0
[ -n "$branch" ] || exit 0
if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
	branch="$branch*"
fi
printf '\033[35mgit:\033[0m%s\n' "$branch"
```

```toml
[dock]
left = ["mode", "workspaces", "trail", "tape", "custom/branch"]

[dock.custom.branch]
command = "~/.config/tuios/dock/git-branch.sh"
refresh = "event:after-focus-change,after-attach"
```

The dock shows `git:feat/demo*` after the trail, with `git:` in magenta and `*` meaning a dirty tree. Outside a repository the script prints nothing and the cell is hidden. For a Nerd Font icon, put the glyph (for example U+E0A0) between the two escape sequences.

### Recipe: battery, polled every minute

The shipped `battery.sh` has a bug in v0.8.5: its `*charging*` pattern also matches `discharging`, so on macOS a draining battery shows `+` and never turns red. This version matches `discharging` first.

`~/.config/tuios/dock/battery.sh`:

```sh
#!/bin/sh
# Dock component: battery charge; "+" while charging; red under 20%.
# Prints nothing (cell hidden) on a machine without a battery.
set -eu
capacity=""
status=""
for bat in /sys/class/power_supply/BAT*; do
	[ -r "$bat/capacity" ] || continue
	capacity=$(cat "$bat/capacity")
	[ -r "$bat/status" ] && status=$(cat "$bat/status")
	break
done
if [ -z "$capacity" ] && command -v pmset >/dev/null 2>&1; then
	line=$(pmset -g batt | sed -n '2p')
	capacity=$(printf '%s' "$line" | sed -n 's/.*[^0-9]\([0-9][0-9]*\)%.*/\1/p')
	case "$line" in
	*discharging*) status=Discharging ;;
	*"AC attached"* | *charging* | *charged*) status=Charging ;;
	*) status=Discharging ;;
	esac
fi
[ -n "$capacity" ] || exit 0
case "$status" in
Charging | Full) glyph="+" ;;
*) glyph="" ;;
esac
if [ "$capacity" -le 20 ] && [ "$glyph" != "+" ]; then
	printf '\033[31m%s%%%s\033[0m\n' "$capacity" "$glyph"
else
	printf '%s%%%s\n' "$capacity" "$glyph"
fi
```

```toml
[dock]
right = ["notifications", "copy-help", "custom/battery", "cpu", "ram", "clock", "session-controls"]

[dock.custom.battery]
command   = "~/.config/tuios/dock/battery.sh"
refresh   = "60s"
max-width = 8
```

Charging at 80% draws `80%+`; discharging at 15% draws `15%` in red. On a desktop Mac or a server with no battery the cell is hidden. `list-dock-components` reports the refresh as `interval 1m0s`.

### Recipe: unread agent mail count, pushed

There is no dock event for mail, so this component blocks on the daemon with `wait-for` instead of polling, and re-counts whenever a message arrives.

`~/.config/tuios/dock/mail.sh`:

```sh
#!/bin/sh
# Dock component: unread agent mail for one inbox, pushed (no polling).
# INBOX defaults to "human", the person's inbox. --peek keeps the count
# from marking anything as read.
set -u
INBOX=${TUIOS_MAIL_INBOX:-human}
S=${TUIOS_SESSION:+-s "$TUIOS_SESSION"}

emit() {
	n=$(tuios read-agent-messages $S -w "$INBOX" --unread --peek --json --limit 1 2>/dev/null |
		sed -n 's/^ *"total": *\([0-9][0-9]*\).*/\1/p')
	if [ "${n:-0}" -gt 0 ]; then
		printf '\033[33mmail %s\033[0m\n' "$n"
	else
		printf '\n'   # an empty line clears (hides) the cell
	fi
}

emit
while :; do
	tuios wait-for agent-message $S -w "$INBOX" --timeout 600000 >/dev/null 2>&1 || sleep 1
	emit
done
```

```toml
[dock]
right = ["notifications", "copy-help", "custom/mail", "cpu", "ram", "clock", "session-controls"]

[dock.custom.mail]
command = "~/.config/tuios/dock/mail.sh"
refresh = "push"
```

::: warning
`--peek` is not optional. `tuios read-agent-messages -w INBOX --unread` marks what it returns as read, so a counter without `--peek` would empty the inbox every time the dock refreshed. Count with `total` from the JSON, not `unread`: `unread` counts only the messages returned, which `--limit` caps.
:::

With nothing unread the cell is hidden and `list-dock-components` shows `push │ hidden`. After two `tuios send-agent-message -w human ...` calls it reads `mail 2` in yellow. Mail to `human` also raises tuios's own dock notification, which holds the right block until it clears, so the count appears a few seconds after the message.

A `push` command that exits is restarted after a backoff from 0.5 s doubling to 8 s. If it exits five times in a row without printing a line, the reader gives up until `tuios refresh-dock mail`. `refresh-dock` on a running push component does nothing.

### Recipe: a clickable cell

`~/.config/tuios/dock/clicks.sh`:

```sh
#!/bin/sh
# Dock component: a clickable counter. "show" draws the cell; "click" bumps
# the count and asks the dock to re-run the component.
set -eu
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/tuios-dock-clicks
case "${1:-show}" in
show)
	n=$(cat "$STATE" 2>/dev/null || echo 0)
	printf '[clicks %s]\n' "$n"
	;;
click)
	n=$(cat "$STATE" 2>/dev/null || echo 0)
	echo $((n + 1)) >"$STATE"
	echo "button=${TUIOS_CLICK_BUTTON:-} component=${TUIOS_DOCK_COMPONENT:-}" >>"$STATE.log"
	tuios refresh-dock ${TUIOS_SESSION:+-s "$TUIOS_SESSION"} "$TUIOS_DOCK_COMPONENT" >/dev/null 2>&1 || true
	;;
esac
```

```toml
[dock]
left = ["mode", "workspaces", "trail", "custom/clicks"]

[dock.custom.clicks]
command  = "~/.config/tuios/dock/clicks.sh show"
on-click = "~/.config/tuios/dock/clicks.sh click"
```

A left click turns `[clicks 0]` into `[clicks 1]` and logs `button=1`; a middle click logs `button=2`; a right click opens the dock's context menu and never reaches `on-click`.

A button that needs no state at all is two lines:

```toml
[dock.custom.newwin]
command  = "printf '[+ shell]\\n'"
on-click = "tuios new-window"
```

Branch on `$TUIOS_CLICK_BUTTON` to give one cell two actions. The shipped `examples/dock/dock.toml` opens a git log with `on-click = "tuios new-window log -- git log --oneline -20"`.

::: note
Every successful `tuios refresh-dock` raises an info toast, `Remote: refresh-dock NAME`, which takes over the right block for a few seconds and hides the right-hand custom cells while it is up. A `[hooks]` entry such as `after-agent-state = "tuios refresh-dock agents"` therefore flashes that toast on every agent state change. Prefer `refresh = "event:after-agent-state"`, which refreshes silently.
:::

### The other shipped examples

`examples/dock/` in the source tree also ships `agents.sh` (event `after-agent-state`, counts agent states from `list-windows --json`), `inbox.sh` (a maildir count, `push`, with `inotifywait` on Linux and a 60-second loop elsewhere) and `kube-context.sh` (every 30 s, red when the context name matches `prod`, `production` or `live`). Their README is the upstream contract. Note that `inbox.sh` has the same missing-glyph issue as `git-branch.sh` in v0.8.5.

### How the engine runs your components

Knowing the process model explains most surprises.

- One engine per attached client. Every `once`, `event` and interval component runs once at startup, each in its own goroutine; a `push` component starts its reader. The bar draws without the value until it arrives.
- One timer for everything, armed for the earliest deadline; with nothing due, no timer exists. An idle dock costs nothing.
- An interval of exactly 1s or 1m is aligned to the wall clock. If the previous run is still going when the next tick arrives, the tick is skipped, so there is never more than one process per component.
- Events are debounced: a burst of events within 200 ms causes one run.
- One-shot runs are placed in their own process group and the whole group is killed on timeout, so `sleep 30 &` inside your script does not outlive it. Output printed before the timeout is discarded.
- Any error blanks the cell; a stale value is never kept. The first failure of a streak is reported once as `Dock component NAME: exit N` (or `timed out after 3s`). After five consecutive failures the component is stopped and skipped until `refresh-dock`. A reload rebuilds the engine, which restarts push processes and resets failure state.
- An update whose text equals the current text draws no frame.
- When the right block runs out of room, segments are dropped in this order: the last custom cell, then the next, then the CPU graph, then RAM. Built-in cells such as the clock are never dropped. Custom cells on the left and centre are never dropped; the bar is cut at the session controls instead.

### The dock editor

Settings page (<kbd>Prefix</kbd> <kbd>,</kbd>), **Dock**, **Components** opens an editor for the three lists. It cannot create or edit a `[dock.custom]` table.

| Key | Action |
| --- | --- |
| <kbd>↑</kbd> <kbd>↓</kbd> | Select |
| <kbd>Shift</kbd>+<kbd>↑</kbd> / <kbd>Shift</kbd>+<kbd>↓</kbd>, <kbd>K</kbd> / <kbd>J</kbd> | Move one place; past the end of a region the item crosses into the next. A pinned component refuses. |
| <kbd>Enter</kbd> / <kbd>Space</kbd> | Remove a placed component, or add one from "Not on the bar" (to its pinned side, otherwise appended to `right`) |
| <kbd>r</kbd> | Reset all three lists to the defaults, written out explicitly |
| <kbd>u</kbd> | Undo this session's edits |
| <kbd>Esc</kbd> | Close; every edit was already saved |

::: warning
Every edit is saved by rewriting the whole `config.toml` with a TOML marshaller. Comments in the file are lost. Keep a copy, or keep your dock tables in version control.
:::

### Troubleshooting

1. **Not listed by `tuios list-dock-components`.** It was dropped from the plan: a typo in the `custom/NAME` entry, no matching `[dock.custom.NAME]` table, an empty `command`, or the name listed twice. Open the log viewer and look for `Config:` lines from startup.
2. **STATE `hidden`.** The command exited 0 with empty output. That may be intended.
3. **STATE `failed`.** READS shows `exit N: exit status N` or `exit -1: timed out after 3s`. stderr is never shown, so run the command by hand with `TUIOS_SESSION` set.
4. **STATE `gave up`.** Five failures in a row. Fix the script, then `tuios refresh-dock NAME`.
5. **The value never changes.** Check `refresh`. `once` runs only at startup, reload and `refresh-dock`. A misspelled event type warns at startup and falls back to `once`.
6. **The cell comes and goes.** Messages and copy-mode help take over the right block, and right-hand custom cells are the first to yield when the bar is narrow. Put an important cell on the left.
7. **Nothing happens on click.** The key is `on-click`, with a hyphen. Right-click never reaches it. The cell does not refresh itself after a click; the click command must call `tuios refresh-dock`.
8. **tuios-web or SSH.** Components run on the serving machine, and a warning says so at startup. Restricted connections, including every connection `tuios mcp` opens, are refused the dock verbs.

### The Go route: a built-in component

Write a built-in only when the value must come from inside the client with no subprocess, for example from model state or a library call that is fast. There is no component interface or registry; a component is a string name consulted at a handful of switch points. The cheap path is an *engine-scheduled value cell* like the clock: the engine supplies a deadline, the model computes the text, and the text draws through the same cell code a custom component uses, so width negotiation, truncation, all three sides, the change gate and `list-dock-components` come for free.

The following adds a `loadavg` cell showing the 1, 5 and 15 minute load averages. It was implemented and tested on a copy of the v0.8.5 tree: `go build`, `go vet` and `gofmt` clean, the dock and settings tests green, and the real binary drew `load 8.78 11.41 10.14`.

::: howto
1. **Name it.** In `internal/config/dock.go`, add a constant and put it in `dockBuiltins`. The "unknown component" warning, the editor's "Not on the bar" list and `IsDockBuiltin` all pick it up from that slice. Do not add it to the default lists, or `TestDockDefaultListsDrawTheSameBar` fails.

    ```go
    	DockComponentSessionControls = "session-controls"
    	DockComponentLoadAvg         = "loadavg"
    )
    // ... and in dockBuiltins:
    	DockComponentSessionControls,
    	DockComponentLoadAvg,
    ```

    A component that may live on one side only also goes into `dockFixedSides`. A value cell should not.

2. **Schedule it.** In `internal/app/dock_components.go`, inside `dockRefreshableComponents` after the RAM block, gated on the plan so an unlisted component costs nothing:

    ```go
    	// Being in a list is what turns the load average on.
    	if plan.Has(config.DockComponentLoadAvg) {
    		comps = append(comps, &dockComponent{
    			Name:    config.DockComponentLoadAvg,
    			Builtin: true,
    			Refresh: config.DockRefresh{Kind: config.DockRefreshInterval, Interval: dockLoadAvgInterval},
    		})
    	}
    ```

    and beside `dockMeterInterval`:

    ```go
    // The kernel recomputes the load average every five seconds.
    const dockLoadAvgInterval = 5 * time.Second
    ```

3. **Make it draw as a cell on any side.** In the same file:

    ```go
    func dockCellComponent(name string) bool {
    	return strings.HasPrefix(name, config.DockCustomPrefix) ||
    		name == config.DockComponentClock || name == config.DockComponentLoadAvg
    }
    ```

    This single change makes the left loop's default branch, the centre loop, `renderDockRightCells` and the layout reserve in `dockCustomWidth` all handle it. Skip it and the component is scheduled but never drawn or measured.

4. **Compute the value on the model goroutine.** In `internal/app/dock_runtime.go`, `refreshBuiltinDockComponent`:

    ```go
    	case config.DockComponentLoadAvg:
    		return m.dockEngine.SetBuiltinText(name, dockLoadAvgText())
    ```

    and in `internal/app/sysinfo.go`, importing `github.com/shirou/gopsutil/v4/load` (gopsutil is already a dependency):

    ```go
    // dockLoadAvgText is the load-average cell. Empty when the platform
    // cannot say, which hides the cell rather than drawing zeros.
    func dockLoadAvgText() string {
    	avg, err := load.Avg()
    	if err != nil || avg == nil {
    		return ""
    	}
    	return fmt.Sprintf("load %.2f %.2f %.2f", avg.Load1, avg.Load5, avg.Load15)
    }
    ```

    This runs on the render goroutine. Anything slow, such as a network call or a subprocess, belongs in a custom component, which runs off that goroutine under a timeout.

5. **Add tests** to `internal/app/dock_components_test.go`: one that the component is scheduled only when placed (build a `UserConfig` with `Dock.Right` set to `["loadavg", "session-controls"]`, call `buildDockPlan` and `dockRefreshableComponents`, and assert a `Builtin` entry with `Refresh.Kind == config.DockRefreshInterval` and `Interval == dockLoadAvgInterval`, plus `dockCellComponent` returning true), and one that the bar shows it (`newNarrowOS(t, 120, 24)`, set `m.UserConfig.Dock.Right`, `m.InitDockComponents()`, read `m.dockEngine.Text(config.DockComponentLoadAvg)`, and assert `renderDockString()` contains it after `stripANSIForTrace`).

6. **Build and test.**

    ```sh
    go build ./...
    go vet ./internal/app ./internal/config
    go test ./internal/app -run 'Dock|Settings' -count=1     # about a minute
    go test ./internal/config -count=1
    cd e2e/tui && TUIOS_E2E=1 go test -count=1 -run TestDock ./...
    ```

7. **Install, enable, verify.**

    ```sh
    go build -o ~/bin/tuios ./cmd/tuios
    ```

    ```toml
    [dock]
    right = ["notifications", "copy-help", "loadavg", "cpu", "ram", "clock", "session-controls"]
    ```

    ```sh
    tuios list-dock-components | grep loadavg
    ```

    ```text
    │ loadavg │ right │ builtin │ interval 5s │ drawn │ load 8.72 11.35 10.13 │
    ```

8. **Update the hand-maintained lists of built-ins**: `examples/dock/README.md`, the "The dock's components" section of `docs/CONFIGURATION.md`, and `skills/tuios/config.md`.
:::

What the value-cell route does not give you:

- **Clicks.** Hit rectangles are recorded only for `custom/*` names. A clickable built-in records a hit in each of the three render sites and dispatches it in `internal/input/mouse_click.go`.
- **Yielding.** In `renderDockRightCells` a segment yields to space pressure only when its name starts with `custom/`. Set that flag for your component if it should give way like a custom cell.
- **Colour.** The text draws in the dimmed foreground. Embed SGR in the string, or style it in `dockCustomCell` with theme tokens; never hard-code colours.
- **An on/off switch.** To mirror `show_cpu`, add a settings field, a registry option in `internal/config/options.go`, a row in the Dock category of `settings.go`, a label in `settings_registry.go`, and gate the component on it. `TestSettingsPanelReachesEveryOption` fails until the row exists.

A component with its own interaction, such as a new pill, is the expensive kind: it needs its own measurement in `buildDockLeftText` or `calculateDockRightWidth`, its own drawing in `renderDockString` that records hit rectangles *while drawing* (every hit list in the package works that way because recomputing columns once produced unclickable entries), click dispatch in `mouse_click.go` in the right order of precedence, and a geometry test like `TestDockMinimizedEntriesAreClickableWhereTheyAreDrawn`.
## How to run a shell command on an event (hooks)

A hook is a shell command that tuios runs when one of ten fixed events happens: a window opens, an agent needs input, a client attaches, and so on. You declare hooks in the `[hooks]` table of `config.toml`. Writing a hook needs no Go. You need Go only to add a new *event*, which is covered at the end of this section. The daemon fires the events it owns, so those hooks run even when nobody is attached. A client fires the events that need its terminal. The user-facing reference upstream is [docs/HOOKS.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/HOOKS.md).

### The ten events

The event names are the constants in `internal/hooks/hooks.go:22-40`. `AllEvents()` (`hooks.go:43-50`) is the list of valid names. No other name is accepted.

| Event | Fired by | Fires with nobody attached | When |
|---|---|---|---|
| `after-new-window` | daemon (standalone: the client) | yes | a window is created |
| `after-close-window` | daemon (standalone: the client) | yes | a window is closed |
| `after-focus-change` | daemon (standalone: the client) | yes | focus moves to another window |
| `after-workspace-switch` | daemon (standalone: the client) | yes | the current workspace changes |
| `after-agent-state` | daemon (standalone: the client), gated by `[notifications.agent]` | yes | an agent enters a state the alert policy alerts on |
| `after-command-finished` | daemon only | yes | a shell with OSC 133 marks reports that a command finished |
| `after-attach` | client | no | a client attaches to the session |
| `after-detach` | client | no | a client detaches |
| `after-resize` | client | no | the client's terminal is resized |
| `after-layout-change` | client | no | the tiling layout changes |

The daemon and the client split the events using one map, `sessionHookEvents` (`internal/session/daemon_hooks.go:45-52`). The client imports the same set and runs a hook only when `!m.IsDaemonSession || !sessionSideHooks[event]` (`internal/app/os_notify.go:98-100`). Because both sides read one map, the split cannot drift, and three attached clients still produce one firing of a session-side event.

A standalone tuios (no daemon) fires every event itself, except `after-command-finished`: only the daemon follows the OSC 133 marks.

### Environment variables

Every hook receives all 16 variables below, on top of the environment of the process that fires it. A variable that does not apply to the event is empty, or `0` for an integer (`hooks.go:52-93`, `executeHook` at `hooks.go:253-270`).

| Variable | Set for | Value |
|---|---|---|
| `TUIOS_EVENT` | all | the event name |
| `TUIOS_SESSION_ID` | all | the session **name** (not a uuid) |
| `TUIOS_WINDOW_ID` | window events, agent state, resize | window uuid |
| `TUIOS_WINDOW_NAME` | same | window name |
| `TUIOS_WORKSPACE` | all | workspace number; the client fills in the current one when the value is 0 |
| `TUIOS_PREV_WORKSPACE` | `after-workspace-switch` | the workspace you left |
| `TUIOS_LAYOUT` | `after-layout-change` | `bsp`, `master-stack`, `scrolling` or `floating` |
| `TUIOS_WIDTH`, `TUIOS_HEIGHT` | `after-resize` | size in cells |
| `TUIOS_AGENT_STATE`, `TUIOS_AGENT_PREV_STATE` | `after-agent-state` | `needs_input`, `errored`, `done`, `idle`, `working` |
| `TUIOS_AGENT_HARNESS` | `after-agent-state` | harness id, for example `claude-code` |
| `TUIOS_AGENT_MESSAGE` | `after-agent-state` | the agent's free text (untrusted) |
| `TUIOS_COMMAND` | `after-command-finished` | the command line, at most 512 bytes, control characters removed, likely secrets masked |
| `TUIOS_EXIT_CODE` | `after-command-finished` | string; empty when the shell sent no status |
| `TUIOS_DURATION_MS` | `after-command-finished` | string |

The ranked *source* of an agent state (report, osc, screen) is deliberately not passed to the hook (`hooks.go:79-81`). Read it with `tuios get-agent-state` if you need it.

### Steps

::: howto
1. **Write the command, or a script it calls.**

   Put anything longer than one line in a script under `~/.config/tuios/hooks/`. tuios runs every hook as `sh -c "<command>"` (`hooks.go:250`), also on Windows, so a `sh` must be on `PATH`.

   ```sh
   mkdir -p ~/.config/tuios/hooks
   $EDITOR ~/.config/tuios/hooks/needs-input.sh
   ```

2. **Add the `[hooks]` table to `config.toml`.**

   Edit the file that `tuios config path` prints. Each key is an event name and each value is either a string or an array of strings (`HooksConfig` is `map[string]any`, `internal/config/userconfig.go:682-683`).

   ```toml
   [hooks]
   after-new-window  = "notify-send 'tuios' \"new window $TUIOS_WINDOW_NAME\""
   after-agent-state = ["sh ~/.config/tuios/hooks/phone.sh", "logger -t tuios \"$TUIOS_AGENT_STATE\""]
   ```

   Several commands on one event each run in their own goroutine, so they run **concurrently**, not in order.

3. **Restart whichever side owns the event.**

   Session-side events (the first six in the table) load once, when the daemon starts. Client-side events load once, when a client starts or attaches.

   ```sh
   tuios kill-server   # closes every pane; needed for session-side hooks
   tuios               # start again
   ```

4. **Check that the hook is registered and that it ran.**

   ```sh
   tuios list-hooks
   tuios list-hooks --event after-agent-state
   ```
:::

::: warning
Hooks are **not hot-reloaded** on either side. The config watcher reloads most of `config.toml` live, but nothing calls `LoadFromConfig` again after start (`internal/app/factory.go:337`, `internal/session/daemon_hooks.go:154-181`). `tuios config apply` does not reload them either: `loadHooks` is called only from the daemon constructor (`internal/session/daemon.go:722`). Restart the daemon with `tuios kill-server` for session-side events, and re-attach for client-side events.
:::

### Example: notify when an agent needs input

This hook runs on the daemon, so it fires while you are detached.

```sh
#!/bin/sh
# ~/.config/tuios/hooks/needs-input.sh
[ "$TUIOS_AGENT_STATE" = "needs_input" ] || exit 0
# macOS
osascript -e "display notification \"$TUIOS_WINDOW_NAME needs input\" with title \"tuios $TUIOS_SESSION_ID\""
# Linux alternative: notify-send "tuios" "$TUIOS_WINDOW_NAME needs input"
```

```toml
[hooks]
after-agent-state = "sh $HOME/.config/tuios/hooks/needs-input.sh"

[notifications.agent.states]
needs_input = true
errored = false
done = false
```

`after-agent-state` does not fire on every state change. It is an alert sink, and the daemon gates it (`fireAgentStateHook`, `daemon_hooks.go:268-329`):

1. Every new transition cancels the alert already parked for that pane.
2. `[notifications.agent] enabled` must be true, and `[notifications.agent.states].<state>` must be true. The defaults are `needs_input`, `errored` and `done` on, `idle` and `working` off.
3. The current time must be outside `quiet_hours`.
4. If `settle_seconds` is above 0 (default 2), the alert is parked on a timer. When the timer fires, the daemon reads the window again and fires only if the pane is still in that state.
5. `suppress_focused` (default true) drops the alert only when a TUI client is attached, the attached terminal has not reported losing focus, and the pane is the focused window. With nobody attached, the hook always fires.

`[notifications.agent] command = "..."` is a shorthand that adds one more `after-agent-state` command to the `[hooks]` entries. It does not replace them (`daemon_hooks.go:168-174`).

::: tip
The phone-push recipe in `tuios --skill recipes` sends the request with `curl -s -m 5 ... https://ntfy.sh/<topic>` and deliberately keeps `TUIOS_AGENT_MESSAGE` off the network. Copy that pattern: the message is text an agent wrote.
:::

### Example: log window creation

```toml
[hooks]
after-new-window   = 'printf "%s new %s %s ws=%s\n" "$(date +%FT%T)" "$TUIOS_WINDOW_ID" "$TUIOS_WINDOW_NAME" "$TUIOS_WORKSPACE" >> "$HOME/.local/state/tuios-windows.log"'
after-close-window = 'printf "%s close %s\n" "$(date +%FT%T)" "$TUIOS_WINDOW_ID" >> "$HOME/.local/state/tuios-windows.log"'
```

### Example: run a command on attach

`after-attach` runs in the client, on the machine you are sitting at, once per attaching client.

```toml
[hooks]
after-attach = 'tmux display-message "attached to $TUIOS_SESSION_ID" 2>/dev/null || true'
after-detach = 'date +%s > "$HOME/.cache/tuios-last-detach"'   # must finish within 2s
```

### Example: log every failing shell command

This needs a shell that sends OSC 133 marks. Check with `tuios doctor shell`.

```toml
[hooks]
after-command-finished = '[ -n "$TUIOS_EXIT_CODE" ] && [ "$TUIOS_EXIT_CODE" != 0 ] && echo "$TUIOS_DURATION_MS ms exit $TUIOS_EXIT_CODE: $TUIOS_COMMAND" >> ~/.cache/tuios-fail.log; true'
```

### Verify it

```sh
tuios list-hooks                       # table: EVENT SIDE COMMAND RUNS STATE LAST
tuios list-hooks --json | jq '.hooks[] | select(.last_error != "")'
tuios daemon --log-level=basic         # one log line per firing: hooks: the <event> event fires: <cmd>
```

The `list-hooks` verb returns `hooks[]` rows with `event`, `side` (`session` or `client`), `command`, `runs`, `last_exit`, `last_run` (RFC 3339), `last_error` and `last_ms`, plus `total`, `events[]` and `client_attached` (`internal/session/verb_protocol.go:375-391`). Read the table like this:

| What you see | What it means |
|---|---|
| no row for your hook | the event name is wrong, or the hook belongs to the other side |
| `RUNS 0` | the event never happened |
| non-zero `last_exit` and a `last_error` | the command ran and failed; the error is the last 1 KiB of its stderr |
| `client_attached: false` | client-side rows are missing; attach a client to see them |

A failed hook also logs a warning that is never suppressed: `hooks: warning: the <event> hook failed. Exit <n> after <d>. Command: <cmd>. Stderr: <tail>` (`internal/hooks/status.go:151-154`).

### Gotchas

- Event names use hyphens (`after-new-window`), not underscores. An unknown name is skipped with only a log line, `hooks: ignoring unknown event "..."` (`hooks.go:196`). No config validation warning is raised: `internal/config/validation.go` has no check for hooks.
- There is **no per-hook timeout** (`cmd.Run()` at `hooks.go:281` has no deadline). A command that never exits holds its goroutine forever. Put the timeout in the command: `curl -m 5`, `timeout 10 ...`.
- stdout is discarded. Only the last 1024 bytes of stderr are kept.
- At daemon shutdown and at client detach, tuios waits at most 2 s for running hooks, then logs `hooks: gave up waiting for hooks to finish after 2s`. An `after-detach` hook that needs longer may be killed.
- A hook run by the daemon has the daemon's environment: the environment of the shell that first started the daemon, not your current shell's. Use full paths. It does not inherit `TUIOS_PANE_ID`; act on the pane with `$TUIOS_WINDOW_ID` and `tuios` verbs.
- `[notifications.agent]` is resolved by the daemon once, in `loadHooks` (`daemon_hooks.go:175`). Editing the states, quiet hours or settle time changes the client's dock, sound and OSC alerts at once, but the daemon's gating of the hook only after a restart.
- `TUIOS_AGENT_MESSAGE` and `TUIOS_COMMAND` hold text an agent or a user wrote. Quote them. The secret masking in `TUIOS_COMMAND` is best-effort.
- A failing hook is never retried and never disables other hooks.

### Adding a new event (Go)

::: howto
1. **Add the constant.**

   `internal/hooks/hooks.go:22-40`, and append it to `AllEvents()` (`hooks.go:43-50`). That one change makes the name valid in config, in `list-hooks` `events[]` and in `ParseEventName`.

   ```go
   AfterSessionRename Event = "after-session-rename"
   ```

2. **Carry new data, if any.**

   Add a field to `Context` (`hooks.go:57-93`) and a matching `TUIOS_*` line in `executeHook` (`hooks.go:253-270`). An unrelated event must receive an empty value.

3. **Fire it from the side that owns the fact.**

   For a session-owned fact, add a daemon stream event, map it in `sessionHookEvents` (`internal/session/daemon_hooks.go:45-52`) and fill it in `hookContext` (`daemon_hooks.go:211-236`). The client's `firesHere` picks up the change. For a client-owned fact, call the manager from `internal/app`:

   ```go
   m.FireHookContext(hooks.AfterSessionRename, hooks.Context{SessionID: name})
   ```

4. **Refresh dock components on it (optional).**

   Add an alias to `dockEventAliases` (`internal/app/dock_runtime.go:187-197`).

5. **Document it and test it.**

   Update the side table and the variable table in `docs/HOOKS.md`. Write tests with `Manager.SetRunner` (`hooks.go:123-130`), which captures firings without a shell, and `Manager.Wait()`, following `internal/app/hooks_events_test.go` and `internal/session/daemon_hooks_test.go`.

   ```sh
   go test ./internal/hooks/ ./internal/session/ -run Hook -count=1
   go test ./internal/app/ -run 'Hook|Detach|AgentAlert' -count=1
   ```
:::

## How to write a theme

A theme is the colour half of the chrome. It supplies the 16 ANSI colours plus `fg`, `bg` and `cursor`, which is the colour table programs inside panes paint with, and an optional `chrome` object that names tuios's own furniture colours. tuios ships 342 built-in themes from bubbletint (`github.com/lrstanley/bubbletint/v2 v2.0.2`, sourced from iTerm2-Color-Schemes). A custom theme is a JSON file and needs no Go. A new *built-in* theme, a new JSON key or a new chrome role needs Go. See [Configuration](configuration.md) for the `[appearance]` options that sit next to the theme.

| Route | Needs Go |
|---|---|
| JSON file in `~/.config/tuios/themes/` | no |
| `tuios import-theme` from a kitty, ghostty, alacritty or wezterm file | no |
| a built-in theme shipped in the binary | yes |
| a new theme key or chrome role | yes |

### The schema

The top-level object is unmarshalled straight into bubbletint's `tint.Tint`, and the same bytes are parsed a second time for `"chrome"` (`internal/theme/custom.go:149-153`). Every key is optional. The fallbacks are in `fillDefaults` (`custom.go:132-224`).

| Key | Type | Used for | When omitted |
|---|---|---|---|
| `id` | string | the name you select | file name, lowercased, extension stripped; error `theme has no ID` if still empty |
| `display_name` | string | picker label | `id` |
| `fg` | colour | pane default foreground | `#e5e5e5` |
| `bg` | colour | theme background (light/dark ramp) | `#000000` |
| `cursor` | colour | cursor | copy of `fg` |
| `black` | colour | ANSI 0 | `#000000` |
| `red` | colour | ANSI 1 | `#cd0000` |
| `green` | colour | ANSI 2 | `#00cd00` |
| `yellow` | colour | ANSI 3 | `#cdcd00` |
| `blue` | colour | ANSI 4 | `#0000ee` |
| `purple` | colour | ANSI 5 | `#cd00cd` |
| `cyan` | colour | ANSI 6 | `#00cdcd` |
| `white` | colour | ANSI 7 | `#e5e5e5` |
| `bright_black` | colour | ANSI 8 | copy of `black` |
| `bright_red` | colour | ANSI 9 | copy of `red` |
| `bright_green` | colour | ANSI 10 | copy of `green` |
| `bright_yellow` | colour | ANSI 11 | copy of `yellow` |
| `bright_blue` | colour | ANSI 12 | copy of `blue` |
| `bright_purple` | colour | ANSI 13 | copy of `purple` |
| `bright_cyan` | colour | ANSI 14 | copy of `cyan` |
| `bright_white` | colour | ANSI 15 | copy of `white` |
| `selection_bg` | colour | parsed, not used (selection colour is `appearance.selection.bg`) | none |
| `dark` | bool | reported by `list-themes` only | `false` |
| `credit_sources` | array of `{name, link}` | metadata only | none |
| `chrome` | object | tuios's own furniture (below) | derived from the slots |

::: warning
ANSI 5 is **`purple`**, not `magenta`, and ANSI 13 is `bright_purple`. A `magenta` key in a theme file is silently ignored. Only `tuios import-theme` translates `magenta` to `purple` (`internal/theme/import.go:253-285`).
:::

A colour is either a hex string `"#rrggbb"` or an object `{"r":0-255,"g":...,"b":...,"a":...}`. In the object form all four fields are required. A bad colour fails the whole file.

The `chrome` object (`internal/theme/chrome.go:71-84`) takes these string keys:

| Key | Colours | Derived from when absent |
|---|---|---|
| `accent` | logo, selected row, window-mode pill | `bright_blue` |
| `accent_bright` | secondary accent, focused border in window mode | `bright_cyan` |
| `success` | terminal-mode pill, focused border in terminal mode, success toasts | `bright_green` |
| `warning` | copy-mode pill, warning toasts | `yellow` |
| `error` | error toasts, alert ink | `red` (alert ink from `bright_red`) |
| `info` | info toasts | `blue` |
| `surface` | fill of every dialog (palette, pickers, context menu, which-key) | a constant neutral ramp |
| `canvas` | darkest ramp step | darker than `surface` |
| `panel` | outer band, selected-row bar | darker than `surface` |
| `card` | inset chips, input fields | lighter than `surface` |

A chrome colour may be written `#rgb` or `#rrggbb`, and a missing `#` is added. Anything else turns off that one role only: "a typo costs one colour, not the theme" (`parseChromeColor`, `chrome.go:198-215`). Text ink tiers are deliberately not settable.

### Steps

::: howto
1. **Create the file in the themes directory.**

   The directory is `$XDG_CONFIG_HOME/tuios/themes/` (default `~/.config/tuios/themes/`). It is flat: subdirectories are skipped, and only `*.json` files are read (`custom.go:46`). The file name becomes the id.

   ```sh
   mkdir -p ~/.config/tuios/themes
   cat > ~/.config/tuios/themes/amber.json <<'JSON'
   {
     "display_name": "Amber",
     "fg": "#e6e1cf", "bg": "#0f1419", "cursor": "#ffb454",
     "black": "#000000", "red": "#ff3333", "green": "#b8cc52", "yellow": "#e7c547",
     "blue": "#36a3d9", "purple": "#f07178", "cyan": "#95e6cb", "white": "#ffffff",
     "bright_black": "#323232", "bright_red": "#ff6565", "bright_green": "#eafe84",
     "bright_yellow": "#fff779", "bright_blue": "#68d5ff", "bright_purple": "#ffa3aa",
     "bright_cyan": "#c7fffd", "bright_white": "#ffffff",
     "chrome": { "accent": "#ffb454", "accent_bright": "#ffd580" }
   }
   JSON
   ```

2. **Or import one from another terminal.**

   `tuios import-theme <file> [--name ID] [--json]` sniffs the format by content: TOML first (wezterm `[colors]` with `ansi`/`brights` arrays, alacritty `[colors.primary]`/`[colors.normal]`/`[colors.bright]`), otherwise kitty `key value` or ghostty `key = value` lines. It writes `<themes dir>/<id>.json` with mode 0600, overwriting a file of the same name, and never writes a `chrome` block.

   ```sh
   tuios import-theme ~/.config/ghostty/themes/mytheme --name mytheme
   ```

   It prints `Select it with: tuios set-config appearance.theme <id>` when it succeeds, and `read as <fmt> and found no colours in it` when it does not.

3. **Check that it parsed and is legible.**

   `tuios list-themes` re-reads the directory on every call (`internal/session/verb_themes.go:43`).

   ```sh
   tuios list-themes amber
   tuios list-themes --json | jq '.problems'
   tuios list-themes amber --json | jq -r '.palette.illegible[]'
   ```

4. **Preview it.**

   ```sh
   tuios --preview-theme amber            # prints the 16 swatches in truecolour
   tuios screenshot --theme amber         # renders a capture in that palette
   ```

5. **Select it.**

   Live, from any shell:

   ```sh
   tuios set-config appearance.theme amber
   ```

   Or permanently in `config.toml`, or for one run with `tuios --theme amber`:

   ```toml
   [appearance]
   theme = "amber"
   ```

   In the app, the palette's "Theme picker" and the settings page Appearance tab "Theme" row open the same searchable picker. Cancelling restores the theme that was active when it opened.
:::

### Verify it

`tuios list-themes amber` prints the palette with a contrast ratio for each colour. Text colours are held to a floor of 4.5 and marks (the cursor and the 16 slots) to 3.0 (`internal/overlay/contrast.go:14,19`). The JSON form has `type: "theme_list"`, `total`, `matched`, `themes` (at most 100), `truncated`, `themes_dir`, `themes_dir_error`, `problems`, `session`, `active`, `active_source` and `palette`:

```js
palette = { id: "amber", display_name: "Amber", dark: false /* file has no "dark" key */, bg: "#0f1419",
            swatches: [ { name: "fg", hex: "#e6e1cf", ratio: /* contrast vs bg */, floor: 4.5, passes: true },
                        /* then cursor, then the 16 in index order (floor 3.0) */ ],
            illegible: [] }
```

A file that fails to parse appears in `problems` as `skipping custom theme <file>: failed to parse theme JSON: ...`.

### Gotchas

- Omitting every `bright_*` key makes the bright colours identical to the normal ones.
- `tuios --preview-theme <unknown>` does not fail. It logs a warning and prints the current tint (default `dracula_plus`) under the unknown name. Use `tuios list-themes <id>` to check that an id exists.
- Editing a theme file that is already registered is **not** picked up by selecting the same id again. Run `tuios list-themes` (which replaces the registration), save under a new id, or restart. There is no filesystem watcher on the themes directory.
- `set-config appearance.theme ""` passes validation but does not switch theming off in a running client, because `ApplyAppearanceConfig` skips an empty name (`internal/config/userconfig.go:2203`). The settings picker's `none` entry does turn it off.
- The `set-config` path does not push the new palette into every pane's emulator, which the settings row does (`UpdateAllWindowThemes`, `internal/app/settings.go:194`). Per the source comment, pane content may keep the old palette until fresh output arrives. This is inferred from source, not observed.
- The theme is process-global. On a served `tuios ssh` or web session, one client changing it changes it for everyone.
- `appearance.border_focused_color` and `border_unfocused_color` override the theme's borders and are not part of the theme file.
- At 16 colours the chrome uses slot numbers, so you see the host terminal's palette, and `chrome` RGB values are ignored. Over mosh, set `COLORTERM=truecolor` on the remote side.

### Adding a built-in theme (Go)

Built-in themes are not embedded with `go:embed`. `internal/theme/gen_tints.go` (build tag `ignore`) iterates `tint.DefaultTints()` and writes the generated table `internal/theme/tints_gen.go`, which `builtinTints()` (`tints.go:32-63`) rebuilds at first use. There is no hand-maintained list, and a hand edit to `tints_gen.go` is overwritten by the next generation.

::: howto
1. **Get the theme into bubbletint upstream.**

   bubbletint takes its themes from iTerm2-Color-Schemes. Once a release has it, bump the dependency in `go.mod`.

   ```sh
   go get github.com/lrstanley/bubbletint/v2@latest
   ```

2. **Regenerate the table from the repo root.**

   ```sh
   go run ./internal/theme/gen_tints.go
   git diff --stat internal/theme/tints_gen.go
   ```

   Review the diff by hand: no test compares the generated table to `DefaultTints` any more (`tints.go:9-17`).

3. **Test.**

   ```sh
   go test ./internal/theme/... -count=1
   ```
:::

::: note
The findings sketch an in-tree alternative that registers an embedded JSON file right after `newBuiltinRegistry()` inside `EnsureRegistry` (`internal/theme/themes.go:44-51`), using the same `fillDefaults`, `tint.Register` and chrome registration that custom files use. **Nothing like it exists in v0.8.5**; the comment at `chrome.go:109-111` states that no built-in has a chrome object. If you build it, a user file with the same id loaded later still wins, because `tint.Register` replaces. Model its test on `TestLoadCustomThemeFile_Partial` (`internal/theme/custom_test.go:12`).
:::

Any render code that consumes theme colours must take them from `theme.UI()`, `theme.GroundUI()` or a named token. `TestNoHardCodedColoursInRenderCode` (`internal/lint/colors_test.go:39`) rejects `lipgloss.Color("#...")`, constant `color.RGBA{}`, `charmtone.*` and constant `ansi.BasicColor`/`IndexedColor` in `internal/app` and `internal/overlay`, unless the line is marked `//tuios:allow-color <reason>`.

## How to define a glyph set

A glyph set is the shape half of the chrome: border runes and junctions, window controls, rules, separators, rail marks, files-section marks, the scrollbar, the ellipsis and the sigil. One option, `appearance.glyphs`, names the set. A set is a JSON file that can inherit from another set. Writing one needs no Go. A new built-in set or a new *role* needs Go. Glyph sets never change colour. The upstream reference is [docs/GLYPHS.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/GLYPHS.md).

### Built-in sets

| id | What it draws (`internal/theme/glyphs.go:141-200`) |
|---|---|
| `default` | nothing of its own: the shipped glyphs (rounded border, Nerd Font caps, `✕`/`□`) |
| `unicode` | box-drawing and geometric shapes only: `×`, `□`, `−`, `●`, `▏▕`, `─`, `‹›`, `▎`, `·`, `+`, `«»`, `├─ `, `└─ `, `▾▸`, `…`, `›`, `╌` |
| `heavy` | heavy border with junctions `━┃┏┓┗┛╋┳┻┣┫`, `rule ━`, `focus`/`attention █`, `bullet •`, scrollbar `█`/`│` |
| `ascii` | all 7-bit: border `- \| +`, `X O - o [ ]`, `separator " \| "`, `< >`, `...`, and so on |

### The schema

Every field is optional. Widths are measured with `lipgloss.Width` and come from `glyphRoles` (`glyphs.go:324-358`). A role whose glyph has the wrong width is dropped and keeps its default.

```js
// ~/.config/tuios/glyphs/mine.json
{
  id: "mine",            // optional; else the file name, lowercased, minus extension
  display_name: "Mine",  // optional; else id
  inherits: "heavy",     // optional; a built-in or user set id; empty = shipped defaults
  ascii: false,          // IGNORED on input: recomputed on load

  border: {              // 13 runes, each exactly 1 cell
    top, bottom, left, right,
    top_left, top_right, bottom_left, bottom_right,
    middle, middle_top, middle_bottom, middle_left, middle_right
  },

  // scalar roles: name -> required width in cells (0 = any width)
  close: 1, maximize: 1, minimize: 1, dot: 1, pill_left: 1, pill_right: 1,
  rule: 1, separator: 0, arrow_left: 1, arrow_right: 1,
  focus: 1, attention: 1, bullet: 1, add: 1,
  tree_branch: 3, tree_last: 3,
  fold_open: 1, fold_shut: 1,
  folder: 1, parent: 1, file: 1,
  collapse: 0, expand: 0,
  scrollbar_thumb: 1, scrollbar_track: 1,
  ellipsis: 0, sigil: 1, dash_rule: 1
}
```

Roles are named for what they draw, not where: `rule` is both the pane hairline and the dock's.

Resolution rules:

- Inheritance walks from the most specific set and fills only empty roles, up to 8 levels (`maxGlyphInherit`, `glyphs.go:514`). A loop stops rather than hangs.
- A role still empty after the walk is drawn with the caller's own default (`internal/config/glyphs.go:28-36`).
- The set's border draws only when `appearance.border_style = "glyphs"`. Unnamed border runes fall back to rounded.
- `appearance.scrollbar.thumb` and `.track` still win over the set.
- A user file whose id is a built-in id (`heavy`, `ascii` and so on) replaces that built-in.

### Steps

::: howto
1. **Create the file in the glyphs directory.**

   The directory is `$XDG_CONFIG_HOME/tuios/glyphs/` (`GetGlyphsDir`, `glyphs.go:207`). It is flat, and only `*.json` is read.

   ```sh
   mkdir -p ~/.config/tuios/glyphs
   cat > ~/.config/tuios/glyphs/square.json <<'JSON'
   {
     "display_name": "Square corners",
     "inherits": "unicode",
     "focus": "▌",
     "border": { "top_left": "┌", "top_right": "┐", "bottom_left": "└", "bottom_right": "┘" }
   }
   JSON
   ```

2. **Select the set.**

   ```sh
   tuios set-config appearance.glyphs square
   ```

   The settings page row opens the glyph picker (`internal/app/glyph_picker.go`).

3. **Turn on the glyph border if the set has one.**

   ```sh
   tuios set-config appearance.border_style glyphs
   ```

   ```toml
   [appearance]
   glyphs = "square"
   border_style = "glyphs"
   ```

4. **Inspect what draws.**

   ```sh
   tuios list-glyphs square
   tuios list-glyphs square --json | jq -r '.problems[]?'
   ```
:::

### Verify it

`tuios list-glyphs` lists the sets, the roles, the glyphs directory and the terminal detection verdict ("this terminal: ... glyphs, because ..."). `tuios list-glyphs <id>` prints, for each role, what the set says next to what is drawn, and `ascii: true` when the set is drawable anywhere. Dropped roles appear in `problems`:

```text
glyph set mine: close is 2 cells wide and the layout budgets 1, so it keeps the default
a border rune must be one cell, so "…" keeps the default
skipping glyph set <file>: failed to parse glyph set JSON: ...
```

The glyph directory is re-read on every lookup of an unknown id and on each `list-glyphs`, and `ReloadGlyphSets` re-resolves the active set. So editing the active set's file and then running `tuios list-glyphs` applies the edit.

### ASCII mode and terminal detection

- `--ascii-only` forces ASCII per role: a role whose glyph is 7-bit is kept, and the rest fall back to their ASCII default.
- Automatic detection runs only when the config names no set (or `default`) and `--ascii-only` is not given (`internal/config/glyph_env.go:81-102`). The first of `LC_ALL`, `LC_CTYPE`, `LANG` that is set and lacks `utf-8`/`utf8` turns on ASCII mode. `TERM=linux` selects `unicode` and turns Nerd Font icons off.
- `get-config appearance.glyphs` keeps reporting the configured id, not the forced one.
- Detection is per local client. `tuios ssh` and `tuios-web` clients are not detected.

::: warning
`docs/GLYPHS.md` says "`--ascii-only` (or `ascii_only` in the config)". **No `ascii_only` key exists** in the v0.8.5 config structs (no `toml:"ascii...` tag anywhere in `internal/config`). Only the command-line flag sets ASCII mode.
:::

### Gotchas

- `tree_branch` and `tree_last` must be exactly **3 cells**, including the trailing space (`glyphs.go:339-343`). The "Cell Widths" table in `docs/GLYPHS.md` lists only the any-width roles and does not mention this.
- The `ascii` field in a file is ignored; tuios computes it.
- A set's border is ignored unless `border_style = "glyphs"`.
- Dock semantic icons (mode chip, counts, session controls) and the hovered traffic-light symbols are not roles and cannot be changed.
- A user set with a built-in id is listed once, under the built-ins.

### Adding a role (Go)

::: howto
1. **Add the field.**

   `internal/theme/glyphs.go:62-126`, in `GlyphSet`, with a JSON tag.

   ```go
   Pin string `json:"pin,omitempty"`
   ```

2. **Add one `glyphRoles` entry.**

   `glyphs.go:324`. This single entry drives sanitizing, merging, the ASCII check, `GlyphRoleNames()` and the `list-glyphs` output. Do not write a second table.

   ```go
   {"pin", func(g *GlyphSet) *string { return &g.Pin }, 1},
   ```

   The entry is positional: role name, field accessor, required width in cells (0 means any width), the same shape as `{"focus", func(g *GlyphSet) *string { return &g.Focus }, 1}` at `glyphs.go:335`.

3. **Give the built-ins a value.**

   `glyphs.go:141-200`, for `unicode`, `heavy` and `ascii` where it makes sense. `TestEveryBuiltinSetIsDrawableWhereItSaysItIs` checks the `ascii` claim.

4. **Add an accessor and use it.**

   In `internal/config/glyphs.go`, add a `Settings` accessor built on `glyphOr(role, shippedDefault, asciiDefault)` and call it from the renderer instead of a literal. A role drawn by `internal/overlay` (which may not import `theme`) needs a field on `overlay.Chrome` and a line in `refreshActiveGlyphs` (`glyphs.go:619-633`).

5. **Document and test.**

   Add the role to the Roles list in `docs/GLYPHS.md`.

   ```sh
   go test ./internal/theme/... ./internal/config/... ./internal/app/... -count=1
   ```
:::

## How to add a new keybinding action in Go

An *action* is a named thing a key can do, such as `toggle_zoom` or `prefix_inbox`. Rebinding an existing action, moving the leader or unbinding a key is config-only and is covered in [Keybindings](keybindings.md). A brand-new action needs Go in three packages: `internal/config` (default key and description), `internal/input` (handler and registration) and, for a prefix section, the which-key table and the help overlay in `internal/app`. A set of structural tests fails until every piece is wired, which is the point: an action that no key reaches cannot ship.

The worked example below adds `debug_prefix_repaint` on <kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>D</kbd> <kbd>r</kbd>, which forces a full repaint. The debug prefix is small and has every wiring point. In v0.8.5 it binds `l`, `c`, `a`, `k` and `esc`, so `r` is free.

### Where the pieces live

| Concern | File:line |
|---|---|
| default bindings | `internal/config/userconfig.go:754` `DefaultConfig()`; `DebugPrefix` at `:1078` |
| filling new defaults into an existing user config | `userconfig.go:2421` `fillMissingKeybinds`, `:2649` `fillMapDefaults` |
| action descriptions (one catalogue, about 271 entries) | `internal/config/registry.go:418-744` `ActionDescriptions` |
| handler type and dispatcher | `internal/input/actions.go:16` `ActionHandler`, `:86` `registerHandlers`, `:277` `Register`, `:282` `Dispatch` |
| prefix and terminal-mode registration | `internal/input/prefix_actions.go:29` `registerPrefixHandlers` (debug prefix at `:109-113`) |
| which-key rows (hand-written) | `internal/config/keybindings.go:60` `GetPrefixKeybindings`, `:72` `GetPrefixKeybindingGroups` |
| help overlay | `internal/app/help.go:30` `GetHelpCategories`, `:543` `generateDebugBindings` |
| Learn-mode blocking | `internal/app/learn_mode.go:85` `LearnBlocksAction` |

### Steps

::: howto
1. **Give it a default key.**

   `internal/config/userconfig.go:1078-1084`, in `DefaultConfig().Keybindings.DebugPrefix`:

   ```go
   DebugPrefix: map[string][]string{
       "debug_prefix_logs":       {"l"},
       "debug_prefix_cache":      {"c"},
       "debug_prefix_animations": {"a"},
       "debug_prefix_showkeys":   {"k"},
       "debug_prefix_repaint":    {"r"}, // new
       "debug_prefix_cancel":     {"esc"},
   },
   ```

   Existing users get it automatically: `fillMissingKeybinds` calls `fillMapDefaults`, which inserts actions that are absent from the user's table. Pick a key that is free in that section, because `fillMapDefaults` does **not** yield to a key the user already bound to another action (only `layout_prefix` uses the yielding variant). Moving an existing default needs a migration; `migrateCornerSnapDigits` and its tests in `internal/config/default_conflicts_test.go:9-75` show the pattern.

2. **Add a constant only if non-input code names the action.**

   Most actions are bare strings. Add a constant in `internal/config` only when code outside `internal/input` refers to the action, as `ActionPrefixNextFinished` (`userconfig.go:1235`) and `ActionCopyModeSearchForward` (`internal/config/copy_mode_actions.go:7`) do. The repaint action does not need one.

3. **Describe it.**

   `internal/config/registry.go`, in `ActionDescriptions` (the Debug Prefix block near `:714-718`):

   ```go
   "debug_prefix_repaint": "Repaint every pane",
   ```

   This one string feeds the help overlay, the keybind manager, `tuios keybinds list`, the palette's `#` action search, Learn's action list and the generic description fallback. Without it the UI falls back to `formatActionName` ("Debug Prefix Repaint").

4. **Write the handler.**

   `internal/input/prefix_actions.go` for prefix actions, `internal/input/actions.go` for window-mode actions. The signature is `func(tea.KeyPressMsg, *app.OS) (*app.OS, tea.Cmd)` (`actions.go:16`). Keep the handler thin and put real behaviour in an `*app.OS` method:

   ```go
   func handleDebugRepaint(_ tea.KeyPressMsg, o *app.OS) (*app.OS, tea.Cmd) {
       o.MarkAllDirty()
       o.ShowNotification("Repainted", "info", o.Settings.NotificationDuration)
       return o, nil
   }
   ```

5. **Register it with the dispatcher.**

   `internal/input/prefix_actions.go:109-113`, next to the other debug-prefix registrations:

   ```go
   d.Register("debug_prefix_repaint", handleDebugRepaint)
   ```

   `Dispatch` (`actions.go:282-314`) then gives you, for free: tape recording of the action, `o.NoteAction` (crash report and test probe), `o.OnAction` (the Learn page event) and the `LearnBlocksAction` check.

6. **Route it (only for a new section or sub-prefix).**

   Existing sections are already routed: window mode through `internal/input/keyboard_wm.go:140-148`, prefixes through `runPrefix(msg, o, (*config.KeybindRegistry).GetDebugPrefixAction)` (`internal/input/prefix_routing.go:129`). A *new section* needs a field in `KeybindingsConfig`, a `Section*` constant, a case in `section()` (`internal/config/keybind_scopes.go:224`), a `Scope` in `Scopes()`, a map in `sectionMaps` and `buildMappings` (`registry.go:37-97`), a `Get*Action` lookup, a nil-map init and a `fillMapDefaults` line in `fillMissingKeybinds`, a row in `reachSections` and routing in both `HandleKeyPress` and `HandleTerminalModeKey`. A new sub-prefix also needs a `prefix_<name>` gate action registered with `makeSubPrefixHandler` (`prefix_actions.go:72-77`) and a `*PrefixActive` flag on `app.OS`.

7. **Add the which-key row (prefix sections only).**

   `internal/config/keybindings.go`, case `"debug"` (`:98-105`):

   ```go
   case "debug":
       return one(
           kb("l", "Toggle log viewer"),
           kb("c", "Toggle cache statistics"),
           kb("k", "Toggle showkeys overlay"),
           kb("a", "Toggle animations"),
           kb("r", "Repaint every pane"), // new
           kb("Esc", "Cancel"),
       )
   ```

   Rows use reader notation (`"1-9"`, `"Shift+M"`) that the coverage test expands. Space is tight: the leader panel must fit 80x24.

8. **Add the help overlay row.**

   `internal/app/help.go`. Most categories pass an explicit action list to `generateCategoryBindings` (`:30-117`); add the name to the right list or the action is not shown. Debug and Tape rows are hand-written with literal keys (`generateDebugBindings`, `:543-550`):

   ```go
   {Keys: []string{s.LeaderKey + ", D, r"}, Description: "Repaint", Category: "Debug"},
   ```

   A new help category also needs a `helpTabNames` entry (`help.go:700`).

9. **Block it in Learn mode, if it cannot work in the browser.**

   Add it to `learnUnavailable` in `internal/app/learn_mode.go:37` with the note to show. A repaint works in the browser, so skip this step here.

10. **Update the docs.**

    The per-section defaults table is on the docs site (pointer at `docs/KEYBINDINGS.md:3`). Keep the prose in `docs/KEYBINDINGS.md` and `skills/tuios/config.md` accurate if they mention the area.

11. **Run the guards, then a negative control.**

    ```sh
    go test ./internal/config/ ./internal/input/ ./internal/app/ -count=1
    go test ./internal/input/ -run 'TestEveryDefaultBindingReachesItsAction/debug_prefix' -v
    ```

    The PR template asks for a negative control: delete the `d.Register(...)` line (the wiring, not the handler) and paste the failure, which reads `pressing ctrl+b D r did not reach "debug_prefix_repaint"`.
:::

### An action with no default key

An action reached only from the palette, a context-menu row or a user's own binding still has to be accounted for. Add it to `actionsWithNoDefaultBinding` (`internal/input/reachability_test.go:390-473`) with the surface that reaches it:

```go
"set_tiling_scheme_spiral": "palette row, user binding",
```

`TestEveryRegisteredActionIsBoundOrListed` (`:479`) fails both ways: a registered action with no key and no entry, or an entry that now has a default key or is no longer registered. An action bound "ahead of its work" belongs in `pendingActions` (`:244-254`), which `TestPendingActionsStillDoNothing` keeps honest.

### Verify it

| Test | File:line | Enforces |
|---|---|---|
| `TestEveryDefaultBindingReachesItsAction` | `internal/input/reachability_test.go:206` | every default key, pressed through the real `HandleKeyPress` (in both modes for prefix sections), runs its named action. It is table-driven from `DefaultConfig()`, so your binding is covered as soon as step 1 lands |
| `TestPendingActionsStillDoNothing` | same file `:260` | actions bound ahead of their work stay inert and listed |
| `TestEveryRegisteredActionIsBoundOrListed` | same file `:479` | every registered action has a default key or an `actionsWithNoDefaultBinding` entry |
| `TestReachabilityTableCoversEveryBindingSection` | same file `:358` | every map section of `KeybindingsConfig` has a `reachSections` row |
| `TestEveryDescribedActionIsHandled` | same file `:662` | every `ActionDescriptions` key is registered or named in package `input` |
| `TestWhichKeyTablesMatchTheKeymap` | `internal/config/whichkey_coverage_test.go:75` | which-key rows match prefix sections in both directions |
| `TestDefaultConfigLeavesNoActionUnbound` | `internal/config/default_conflicts_test.go:84` | no default action has zero keys |
| `TestValidateAgreesWithTheKeybindReport` | `internal/config/default_conflicts_test.go:97` | startup validation and `keybinds doctor` agree |
| `TestHelpSectionsHaveTabLabels` and others | `internal/app/help_coverage_test.go` | rail keys documented, rows fit, tabs labelled |
| `TestStockConfigOpensNoConflicts` | `e2e/tui` | a stock config shows no conflicts |

From a built binary:

```sh
go build -o /tmp/tuios ./cmd/tuios
/tmp/tuios keybinds list | grep -i repaint
/tmp/tuios keybinds explain r
/tmp/tuios keybinds doctor
```

::: note
`internal/app/hints_test.go` and `internal/app/command_palette_reach_test.go` sound like keybinding coverage, but **they do not enforce it**. `hints_test.go` tests the Hints overlay (file-opening safety, closing when the pane leaves, character counting). `command_palette_reach_test.go` tests that the palette reaches windows in other sessions and the `@state` filter. The test that fails when a key does not reach its action is `internal/input/reachability_test.go`.
:::

### Gotchas

- **Unknown action names in `config.toml` are silently inert.** Nothing validates that an action exists: the registry maps the key to the string, `HasAction` is false and the key falls through (in window mode nothing happens; after the leader in terminal mode it is typed into the pane). `tuios keybinds doctor` reports unreadable keys, collisions and swallowed keys, not unknown actions.
- Edits to `[keybindings]` in `config.toml` apply to the **next client**. `ApplyReloadedConfig` (`internal/app/command_palette.go:47-58`) never calls `KeybindRegistry.Reload`. The in-app keybind manager and `tuios keybinds unbind` do call it and take effect at once.
- `Scopes()` hard-codes the sub-prefix letters (`t`, `m`, `w`, `D`, `T`, `L`) for display. Rebinding `prefix_window` does not change that label.
- The help overlay's Debug and Tape rows show literal keys and do not follow a rebind.
- Workspace defaults differ by OS (`opt+N` on macOS, `alt+N` on Linux), so a test must not hard-code them.
- The which-key leader panel hides agent lines until an agent has been seen; the keys still work.
- `cmd/zzdumpacts/main.go` is a stray dev utility in the v0.8.5 tree that prints described-but-unbound actions. It is handy for auditing and is not a supported command.

## How to add a harness integration

A *harness* is a coding-agent CLI such as Claude Code, Codex or opencode. tuios learns about a harness through two independent layers, and they extend differently:

| Layer | Package | What it does | Needs Go |
|---|---|---|---|
| **Manifest** | `internal/harness` | answers "is this process harness X?" and "what does its screen, title or desktop notification say about its state?" | **no**: a TOML file in `~/.config/tuios/harnesses/` |
| **Hook integration** | `internal/integration`, `cmd/tuios` | `tuios integration install` writes entries into the harness's own hook config; each runs `tuios agent-hook <id>`, which turns the payload into `set-agent-state` | **yes** for a new harness; a config-only alternative is to point the harness's hooks at `tuios set-agent-state` |

The package doc states the goal: "adding a harness that shipped this morning is a file a user drops in a directory, not a tuios release" (`internal/harness/manifest.go:1-10`). A state reported by a hook outranks every screen rule: self report, then escape sequence (OSC title, progress, notify), then screen rule, then the stall heuristic. See [Agents](agents.md) for how states drive the Inbox and alerts.

### Route 1: a config-only manifest

#### Where manifests come from

- 24 bundled manifests are embedded with `//go:embed manifests/*.toml` (`internal/harness/registry.go:13-14`): aider, amp, antigravity, claude-code, cline, codex, copilot, crush, cursor-agent, devin, droid, gemini-cli, goose, grok, hermes, kilo, kimi, kiro, maki, omp, opencode, pi, qoder, qwen.
- The user directory is `$TUIOS_HARNESS_DIR` if set, else `$XDG_CONFIG_HOME/tuios/harnesses`, else `~/.config/tuios/harnesses` (`registry.go:110-123`). Only `*.toml` is read, in sorted file-name order.
- A user file **replaces** the bundled manifest with the same `id` whole. There is no merge: a block the user file leaves out is absent, not inherited.
- Lookup is by highest `priority`, then `id`, so the result is deterministic.
- A file that fails to load is reported and logged (`harness manifest <file>: <err>`) and never breaks the rest of the registry.

#### Schema (schema_version 1)

```toml
schema_version = 1            # REQUIRED; must equal 1, otherwise a load error
id             = "myagent"    # REQUIRED, non-empty
display_name   = "My Agent"   # optional; defaults to id
priority       = 50           # tie-break when two manifests match one process; higher wins

[detect]                      # REQUIRED: at least one predicate; predicates are alternatives
comm      = ["myagent"]       # base name of the kernel process name (lowercased)
argv0     = ["myagent"]       # base name of argv[0], script extension stripped, and of an interpreter's run token
argv_path = ["@scope/pkg"]    # package name in the path of the token an interpreter runs
exe_glob  = ["**/myagent"]    # component-wise glob on the resolved executable

[detect.require]              # corroboration for comm/argv0 only
exe_base = ["node", "bun"]
exe_glob = ["**/myagent/**"]

[screen]                      # rules against the bottom of the rendered pane
enabled   = true
fold_case = true              # lowercases screen and substrings; regex exempt (use (?i))
lines     = 6                 # non-empty lines from the bottom; default 6, max 200

[[screen.rule]]
state    = "needs_input"      # screen/title: working | needs_input | idle
priority = 30                 # highest first; first match wins; ties in declaration order
message  = "Waits for approval."
kind     = "approval"         # needs_input only: approval | question | "" (guess)
region   = "bottom_non_empty_lines(3)"
all       = ["..."]           # every substring present
any       = ["...", "..."]    # at least one present
not       = ["..."]           # none present
regex     = ['...']           # every RE2 pattern matches; compiled (?m), so ^/$ anchor lines
not_regex = ['...']           # no pattern matches
all_of    = [ { all = ["..."] } ]   # nested gates, same fields
any_of    = [ { any = ["..."] } ]
none_of   = [ { all = ["..."] } ]

[screen.rule.answers]         # needs_input screen/title rules only
approve        = { option = "yes", keys = ["y"] }
approve_always = { option = "yes, and don't ask again", keys = ["a"] }
deny           = { keys = ["esc"] }
choose         = "digit"      # screen rules only
text           = true

[title]                       # rules against the OSC 0/2 window title; same rule shape
enabled   = true
fold_case = true
[[title.rule]]
state  = "working"
region = "osc_title"          # default; or "osc_progress" (last OSC 9;4)
regex  = ['(?:^| )[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏](?: |$)']

[notify]                      # rules against OSC 9 / 777 / 99 notifications
enabled   = true
fold_case = true
[[notify.rule]]
state = "done"                # notify also allows "done"; no region allowed
regex = ['\S']

[input]                       # how a prompt is typed in
submit              = "cr"    # cr | lf ; empty = cr
bracketed_paste     = true    # unset = true
focus_before_submit = false   # send CSI I first when DECSET 1004 is on
source              = "where these values came from"

[resume]                      # how to reopen a conversation
argv   = ["myagent", "--resume", "{session_id}"]   # at least one token holds {session_id}; at most 16
source = "myagent --help"

[transcript]                  # optional transcript join
reader = "claude-code-jsonl"  # the only known reader
dir    = "{home}/.myagent/projects/{cwd:dashes}"   # placeholders {home}, {cwd:dashes}
glob   = "*.jsonl"
verify = ["cwd", "session_id"]   # subset of cwd | version | session_id
```

Screen regions (`internal/harness/region.go:11-62`):

| Region | Reads |
|---|---|
| `tail`, `whole_recent`, empty (default) | the bottom `lines` non-empty lines |
| `bottom_non_empty_lines(N)` | the last N lines; N from 1 to 200 and no more than `[screen] lines` |
| `prompt_box`, `prompt_box_body` | the lines between the last two border lines (a run of 3 or more `─` or `━`) |
| `above_prompt_box` | everything above that box |
| `last_non_empty_above_prompt_box` | the one line just above the box |
| `after_last_horizontal_rule` | everything under the last border line, or the whole tail with no border |
| title: `osc_title` (default), `osc_progress` | the window title, or the last OSC 9;4 report |

Load-time validation (each error names the file):

| Rule | Where |
|---|---|
| `schema_version` must be 1 | `manifest.go:308-311` |
| `id` non-empty, `[detect]` has a predicate | `manifest.go:312-318` |
| a `comm` or `argv0` name shorter than **5** characters needs `[detect.require]`; another predicate alongside does not count | `manifest.go:319-321` |
| `lines` at most 200 | `manifest.go:325-327` |
| an **idle screen rule** must read `region = "prompt_box"` or carry a regex on every path to a match | `manifest.go:403-410` |
| a regex at most 512 bytes, valid RE2 | `manifest.go:277-281` |
| gates nest at most 8 deep; at most 512 gates and 1024 predicates per file | `gate.go:46-53` |
| answers only on `needs_input`, never on notify; at most 8 keys; keys are `enter esc escape tab space up down left right backspace` or one printable character | `answers.go:63-175` |
| `input.submit` is `cr` or `lf` | `input.go:45-55` |
| resume tokens use only `[A-Za-z0-9_./:=+-]` | `resume.go:46-115` |
| transcript reader known, `dir` and `glob` present | `transcript.go:68-111` |

::: howto
1. **Find the process identity.**

   Run the harness in a tuios pane, then read what the detector sees: `comm`, `argv` and `exe`.

   ```sh
   tuios explain-agent-detect -w <pane> --json
   ```

   If the name is shorter than 5 characters, plan a `[detect.require]` block.

2. **Write the manifest with `[detect]` first.**

   `~/.config/tuios/harnesses/myagent.toml`. This exact file was validated against tuios 0.8.5 with `tuios doctor agents --json`:

   ```toml
   schema_version = 1
   id             = "myagent"
   display_name   = "My Agent"
   priority       = 50

   [detect]
   comm  = ["myagent"]
   argv0 = ["myagent"]

   [screen]
   enabled   = true
   fold_case = true
   lines     = 8

   [[screen.rule]]
   state    = "needs_input"
   priority = 30
   kind     = "approval"
   message  = "Waits for approval."
   region   = "bottom_non_empty_lines(4)"
   all      = ["allow this command?"]
   any      = ["[y/n]", "(y)es"]

   [screen.rule.answers]
   approve = { keys = ["y"] }
   deny    = { keys = ["n"] }

   [[screen.rule]]
   state    = "working"
   priority = 10
   message  = "Works on a turn."
   regex    = ['^[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] Thinking']

   [[screen.rule]]
   state    = "idle"
   priority = 5
   message  = "Waits at its prompt."
   region   = "prompt_box"
   regex    = ['^│ > ']

   [input]
   submit          = "cr"
   bracketed_paste = true
   source          = "guess; not measured"

   [resume]
   argv   = ["myagent", "--resume", "{session_id}"]
   source = "myagent --help"
   ```

   To override a bundled harness instead, copy `internal/harness/manifests/<id>.toml` into the user directory and edit the copy. Keep every block you still want.

3. **Validate it without a restart.**

   `tuios doctor agents` loads the directory **in the client process** (`cmd/tuios/doctor_commands.go:66-83`), so it sees a new file at once.

   ```sh
   tuios doctor agents --json | jq '.user_manifests, .manifest_errors'
   TUIOS_HARNESS_DIR=./draft tuios doctor agents --json   # validate a draft directory
   ```

4. **Restart the daemon so it loads the file.**

   ```sh
   tuios kill-server   # closes every pane
   tuios
   ```

5. **Confirm attribution, then write the screen rules against the live pane.**

   Bring the agent to each state (working, approval prompt, idle) and read the tail exactly as the classifier reads it. Before attribution works, `--harness` runs a harness's rules against an unclaimed pane.

   ```sh
   tuios explain-agent-detect -w <pane>
   tuios explain-agent-screen -w <pane> --lines 20
   tuios explain-agent-screen -w <pane> --harness myagent
   tuios peek-prompt -w <pane>          # what respond could answer, from the answers block
   ```

   Add `needs_input` first, then `working`, then `idle` with `region = "prompt_box"` or a regex that pins the input box. Keep idle priority lowest.

6. **Add the optional blocks.**

   `[title]` if the agent sets OSC 0/2, `[notify]` if it sends OSC 9/777/99, `[input]` (used by `ask-agent`, `send-text --submit` and queued prompts) and `[resume]` (used by resume-after-restart).

7. **Report state from the harness's own hooks, still with no Go.**

   If the harness has a hook system, point it straight at `tuios set-agent-state`. That gives `source: report`, which outranks every screen rule. Guard it so it is a no-op outside tuios:

   ```sh
   [ -n "$TUIOS_ENV" ] && tuios set-agent-state needs_input --kind approval -m "approve rm?" --harness myagent
   [ -n "$TUIOS_ENV" ] && tuios set-agent-state working --if-state needs_input --harness myagent
   [ -n "$TUIOS_ENV" ] && tuios set-agent-state done --harness myagent
   ```

   Use `--if-state` for "back to working only if blocked", because a report that is never cleared pins the pane. Alternatively the harness can speak herdr's pane-state protocol, as Crush does; see the herdr how-to below.

8. **For sandboxes, containers and ssh, name the harness explicitly.**

   ```sh
   TUIOS_AGENT=myagent docker run -it myimage myagent
   ```

   `TUIOS_AGENT` on the foreground process names the harness with identity tier `hint`. A real agent binary always wins over the hint.
:::

#### Drafting from herdr

`go run ./internal/harness/herdrconv path/to/herdr/agent.toml > draft.toml` converts a herdr agent manifest. It maps blocked to `needs_input`, sets `fold_case`, maps gates one to one and rewrites Rust regex to RE2, and it names every dropped rule. Its `[detect]` block is a **placeholder** that you must write by hand.

#### Verify it

| Command | What it tells you | Sees a new file without a restart |
|---|---|---|
| `tuios doctor agents [--json]` | `manifest_dir`, `user_manifests[].id/path/replaces_bundled`, `manifest_errors`, integration install state | **yes** |
| `tuios explain-agent-detect [-w win] [--json]` | the verdict in plain words, `comm`/`argv`/`exe`, the wrapper chain, every manifest in lookup order and what it compared | no (daemon's registry) |
| `tuios explain-agent-screen [-w win] [--harness id] [--lines N] [--json]` | the tail as classified, every rule and why each refused, the region text, the title, `manifest_source` | no |
| `tuios peek-prompt -w win` | the actions derived from the `answers` block | no |

The example manifest above returned `user_manifests: [{id: "myagent", replaces_bundled: false}]` with no error. A second file with `id = "pi2"` and `comm = ["pi2"]` returned:

```text
bad.toml: manifest "pi2" matches on the generic name "pi2" alone; add a [detect.require] block
```

::: warning
**Manifests are not hot-reloaded.** The daemon calls `harness.Load(harness.UserDir())` once, at start (`internal/session/agent_detect.go:83`). A new or edited manifest takes effect only after `tuios kill-server`, which closes every pane. `explain-agent-*` show the *daemon's* registry and will not see the new file until then; `tuios doctor agents` will.
:::

#### Gotchas

- A user file with a bundled `id` replaces the whole manifest. Leaving out `[input]` or `[resume]` loses those features for that harness.
- A failing file is only logged. Always check `tuios doctor agents`.
- `fold_case` lowercases substrings but **not** regexes; write `(?i)`. Regexes are `(?m)`, so `^` and `$` anchor lines and `\z` is end of text.
- `bottom_non_empty_lines(N)` must be no more than `[screen] lines`, whose default is only 6.
- An idle rule without `prompt_box` or a pinning regex fails the whole file.
- Title rules never attribute a pane and match whole tokens only (letters, digits, `_`, `-` and `.` continue a token). Notify rules match anywhere and are the only rules that may say `done`.
- An idle verdict must be confirmed by 3 further looks at least 100 ms apart, or hold for 700 ms, and is ignored for the first 3 s after a harness appears.
- `[daemon] agent_binaries = ["myagent"]` (or `TUIOS_AGENT_BINARIES`) marks a pane as an agent by name alone, with **no rules**. A manifest is the right way to add a harness.
- Self-wired `set-agent-state` hooks do not guarantee exit 0 or a 500 ms deadline, unlike `agent-hook`. A hook that misses interrupt or turn-end events pins `working`.

### Route 2: Go (bundle the manifest, add a hook integration)

#### Bundle the manifest

::: howto
1. **Add the file.**

   `internal/harness/manifests/<id>.toml`. It is embedded automatically. Cite the source (and the herdr version, if ported) in comments and set `[input] source`.

2. **Add a fixture for every screen rule.**

   `internal/harness/testdata/screens/rules/<id>.txt`. Each fixture has a header, a `---` line and the screen; fixtures in one file are separated by a `=====` line.

   ```text
   # harness: amp
   # want: needs_input
   # how: derived. The tool-approval prompt from the wordings in herdr's amp
   # manifest (approval_footer).
   ---
     Bash: go test ./...
     Waiting for approval
     [a] Allow all for this session   [d] Deny with feedback
   ```

   That is the first fixture of the real `rules/amp.txt`. The `# how:` line must say `measured` or `derived`.

   `TestEveryScreenRuleHasAFixture` fails until every enabled bundled screen rule decides at least one fixture.

3. **Allow-list an idle rule, if you ship one.**

   Add the id to `screenIdleHarnesses` in `internal/harness/registry_test.go:38-41`, and only if the idle screen was measured or herdr ships the rule. `TestBundledScreenRulesPolicy` also requires every bundled rule to be *corroborated*: a regex, an `all`, two or more `any`, or a corroborated nested group.

4. **Register the id with the integration package.**

   Add it to `integration.ManifestIDs` (`internal/integration/hook.go:106-110`), so a `TUIOS_AGENT=<id>` pane drops hooks from a foreign harness. Optionally add the binary to `defaultAgentBinaries` (`internal/session/agent_detect.go:22-45`); that is not needed when the manifest detects it.

5. **Update the docs.**

   The "Supported agents" table (`docs/AGENT_STATE.md:83`) and the screen-rule prose (`:1071-1100`).

   ```sh
   go test ./internal/harness/... -count=1
   ```
:::

::: note
The comment on `ManifestIDs` says "A test holds this to the manifests". No such test was found in v0.8.5, so nothing fails if you forget step 4.
:::

#### Add a hook integration

A `Target` (`internal/integration/targets.go:88-124`) describes one harness's hook config:

```go
type Target struct {
    ID        string            // harness id, same as manifest id
    Name      string            // display name
    Binary    string            // program checked on PATH by doctor
    Version   int               // integration version; bump when what is installed changes
    Source    string            // citation of the hook format
    Reports   string            // ReportsState ("state") | ReportsSession ("session")
    ConfigDir func(Env) string  // install refuses if it does not exist
    File      string            // file edited/written, relative to ConfigDir
    Events    []HookEvent       // {Name, Timeout} in the harness's own unit
    format    fileFormat        // how File is written
    extra     []extraFile       // more files (plugin manifest, enabling setting)
    ownedDir  string            // dir holding only tuios files; removed when empty
}
```

The file formats (`internal/integration/formats.go`) are `nestedHooks{matcher}` (Claude-style, used by Claude Code, Codex, Gemini CLI, Qwen, Qoder, Droid, Devin), `flatHooks` (Crush, Cursor), `ownedFile{render}` (a file tuios writes whole: opencode, Kilo, Amp, Pi, omp, Hermes, Copilot, Grok), `namedBlock{key}` (Antigravity) and `tomlBlock{}` (Kimi). None of them touches the disk; the target does the atomic write, the `.tuios.bak` backup and symlink handling.

::: howto
1. **Declare the id.**

   Add an id constant in `internal/integration/hook.go:22-42`, aliases in `harnessAliases` (`hook.go:47-84`, which must map the id to itself) and the id in `HarnessIDs()` (`hook.go:94-100`).

2. **Write the translator.**

   For a state integration, create `internal/integration/hook_<id>.go` and add a `case` to `Translate`'s switch (`hook.go:304-328`). Cite the harness's hook documentation in the file header. Shaped like `hook_gemini.go:26-59`:

   ```go
   func translateMyAgent(in Input, p fields) Decision {
       event := eventName(in, p)
       switch event {
       case "SessionStart":
           return send(MyAgent, event, identity(Report{State: "idle"}, p))
       case "PromptSubmit", "ToolStart":
           return send(MyAgent, event, identity(Report{State: "working"}, p))
       case "ApprovalNeeded":
           return send(MyAgent, event, identity(Report{State: "needs_input", Kind: "approval", Message: Clip(p.str("message"))}, p))
       case "ToolDone":
           return send(MyAgent, event, identity(Report{State: "working", IfState: claudeClearsBlock}, p))
       case "TurnEnd":
           return send(MyAgent, event, identity(Report{State: "done"}, p))
       case "SessionEnd":
           return send(MyAgent, event, identity(Report{State: "none"}, p))
       case "":
           return skip(MyAgent, event, "the payload names no event")
       default:
           return skip(MyAgent, event, "event not mapped")
       }
   }
   ```

   The rule stated at `hook.go:267-277`: never guess, a failure never becomes `done`, and an unknown event reports nothing. For a session-only integration, add entries to `identityEvents` and, if needed, `identitySessionKeys` (`hook_identity.go:37-52`) instead; the default branch does the rest.

3. **Answer on stdout if the harness parses it.**

   Add the id to `StdoutAnswer` (`hook.go:336-343`), which prints `{}` for Gemini CLI and Antigravity.

4. **Add the `Target`.**

   Append to `targets` (`targets.go:195+`) with `ID`, `Name`, `Binary`, `Version: 1`, `Reports`, `Source`, `ConfigDir` (for example `e.dirFromEnv("<HOME_ENV>", ".dir")` or `e.xdgConfig("app")`), `File`, `format` and `Events` with timeouts in the harness's unit. A plugin asset goes under `internal/integration/assets/<id>/` with a `//go:embed` var and `ownedFile{render: renderTemplate(...)}`; `renderTemplate` substitutes `__TUIOS_COMMAND__`, `__TUIOS_VERSION__`, `__TUIOS_HARNESS__` and `__TUIOS_NAME__`. A new file shape needs a new `fileFormat` in `formats.go`.

   The installed command is `HookCommand(tuios, id, version)`: `<tuios> agent-hook <id> --integration <N>`. The `--integration` marker lets install replace an older entry, lets uninstall remove exactly what tuios wrote and lets status tell current from outdated.

5. **Add the hook fixtures.**

   `internal/integration/testdata/hooks/<id>.json`, with one `want` case per registered event plus `skip` cases (subagent, unmapped, foreign). Each case is `{name, event?, env?, payload | raw, want: Report | skip: substring}`.

   ```json
   [
     {
       "name": "SessionStart",
       "payload": {"session_id": "g-1", "transcript_path": "/home/u/.gemini/tmp/chat.json", "cwd": "/src", "hook_event_name": "SessionStart", "timestamp": "2026-09-22T10:00:00Z", "source": "startup"},
       "want": {"state": "idle", "agent_session_id": "g-1", "transcript_path": "/home/u/.gemini/tmp/chat.json"}
     },
     {
       "name": "BeforeAgent",
       "payload": {"session_id": "g-1", "hook_event_name": "BeforeAgent", "prompt": "go"},
       "want": {"state": "working", "agent_session_id": "g-1"}
     }
   ]
   ```

   Those are the first two cases of the real `testdata/hooks/gemini-cli.json`. A missing file fails `TestTranslateFixtures`, and an event a `Target` registers without a reporting fixture fails `TestEveryInstalledEventHasAFixture`.

6. **Prove user content survives, for a shared file.**

   If the target edits a file the user also edits, add `userFiles[<id>]` and `keeps[<id>]` in `internal/integration/targets_rest_test.go:16-55`, so `TestEveryTargetRoundTrips` proves it.

7. **Wire the optional extras.**

   Inbox approvals (`internal/integration/approval.go`, `switch id` at `:136`), MCP registration (`mcpTargets`, `internal/integration/mcp.go:59-68`), the status line (`StatusLineHarnesses`, `ParseStatusLine`, `statusline.go:53,86-120`).

8. **Update the user-facing lists.**

   The `agent-hook` `Long` text "Supported harnesses: ..." (`cmd/tuios/agent_hook.go:87`), the `integration` help (`integration_commands.go:56-90`), the "Harness integrations" table in `docs/AGENT_STATE.md:2716-3060`, `skills/tuios/state.md` ("For nineteen harnesses", line 81) and every count ("nineteen", "Twelve", "seven") in those docs.

9. **Run the tests.**

   ```sh
   go test ./internal/harness/... ./internal/integration/... ./cmd/tuios/... -count=1
   ```
:::

#### Verify the hook path by hand

`tuios agent-hook <id> --explain` prints its decision as JSON on stderr and always exits 0, even with no daemon. These are real 0.8.5 outputs, run with `XDG_RUNTIME_DIR` set to an empty directory:

```sh
$ printf '%s' '{"hook_event_name":"Stop","session_id":"s1","last_assistant_message":"All tests pass.\nmore"}' \
    | tuios agent-hook claude-code --explain
{"harness":"claude-code","event":"Stop","report":{"state":"done","message":"All tests pass.","agent_session_id":"s1","activity":{"event":"turn_end","text":"All tests pass."}},"error":"failed to connect to daemon: ..."}

$ echo '{"hook_event_name":"Stop","session_id":"fd-1"}' | tuios agent-hook droid --explain
{"harness":"droid","event":"Stop","skip":"event not mapped"}
```

Then install into a real harness and check:

```sh
tuios integration install myagent
tuios integration status myagent --json
tuios doctor agents
tuios integration uninstall myagent
```

#### Gotchas

- `install` refuses when the harness's config directory does not exist yet ("run the harness once first"), when a file does not parse and when a symlink dangles.
- `agent-hook` has a 500 ms default deadline and always exits 0. The one blocking case is a permission prompt with `[agents.approvals]` on (claude-code, opencode, kilo, qwen), which waits up to `hold_seconds` (default 120).
- `agent-hook` asks `list-verbs` which params `set-agent-state` takes and sends only those, so it degrades against an older daemon. New verbs (`report-agent-activity`, `set-agent-session`) are not sent to a daemon that lacks them.
- Raw newlines inside a JSON string payload make `agent-hook` skip the event. zsh's `echo` expands `\n`; use `printf '%s'`.
- The old shim `integrations/claude-code/tuios-agent-state.sh` is now `exec tuios agent-hook claude-code`. Wiring it alongside an install reports every event twice.
- In v0.8.5, 19 targets exist: 12 report state and 7 report only the session. There is no integration for aider, cline, goose, kiro or maki; the reasons are in `UnsupportedHarnesses()` (`targets.go:464-474`).

## How to add an MCP tool

`tuios mcp` is a Model Context Protocol server. It speaks JSON-RPC 2.0 over stdio, one message per line, and exposes a **curated** list of daemon verbs as tools (`internal/mcp/server.go:1-24`). Each tool's input schema is generated at startup from the daemon's verb table (`session.VerbDocs()`), so the schema always matches the build. *Using* the server is config-only: register it with a harness. *Adding a tool* needs Go, because the catalog is a Go slice in `internal/mcp/tools.go`. The usage side, including `--write` and `--scope`, is covered in [Agents](agents.md) and [Automation](automation.md).

### What is in the catalog

`catalog` in `internal/mcp/tools.go:65-94` lists 15 verb tools, and `buildTools` appends a 16th, `tuios_events`:

| Tool | Verb | `--write` only | Notes |
|---|---|---|---|
| `tuios_list_agents` | `list-agents` | | `all_sessions` hidden under scope own |
| `tuios_list_windows` | `list-windows` | | |
| `tuios_get_agent_state` | `get-agent-state` | | |
| `tuios_capture_pane` | `capture-pane` | | `scrollback ansi resolved palette` hidden; result marked untrusted |
| `tuios_peek_prompt` | `peek-prompt` | | untrusted |
| `tuios_wait_for` | `wait-for` | | deadline `timeout` + 10 s |
| `tuios_read_agent_messages` | `read-agent-messages` | | `to` filled with your pane; untrusted |
| `tuios_send_agent_message` | `send-agent-message` | | `from` filled with your pane |
| `tuios_set_agent_state` | `set-agent-state` | | `window` filled with your pane |
| `tuios_set_agent_meta` | `set-agent-meta` | | `window` filled with your pane |
| `tuios_send_text` | `send-text` | yes | |
| `tuios_send_keys` | `send-keys` | yes | |
| `tuios_ask_agent` | `ask-agent` | yes | untrusted; deadline `ready_timeout` + `timeout` + 10 s |
| `tuios_respond` | `respond` | yes | refused from inside a pane unless `[daemon] respond_from_shell` |
| `tuios_fan` | `fan` | yes | 2 min deadline |
| `tuios_events` | `subscribe` (custom `run`) | | `wait_ms` default 30000, max 120000 |

### Before you start

The capability must already exist as a daemon verb with a `verbDoc` entry, and the verb must be classified in `verbScopes` (`internal/session/conn_scope.go:94`). A verb missing from `verbScopes` is treated as `scopeDeny`, so every restricted MCP call to it is `forbidden`. If the verb does not exist yet, follow the next how-to first.

::: warning
A new protocol verb is **not** added to MCP automatically. `tuios mcp` lists only the curated `catalog`. You must add the tool by hand in `internal/mcp/tools.go`, and `buildTools` **silently skips** a `toolSpec` whose verb is missing from the verb table (`tools.go:158-162`), so a typo in `verb` produces no error, just no tool.
:::

### Steps

The example exposes the existing read-only verb `get-window`, which is classified `scopeRead` but is not in the v0.8.5 catalog.

::: howto
1. **Add a `toolSpec` to `catalog`.**

   `internal/mcp/tools.go:65-94`. Order in `catalog` is the order of `tools/list`.

   ```go
   {name: "tuios_get_window", verb: "get-window"},
   ```

   The fields:

   | Field | Meaning |
   |---|---|
   | `name` | by convention `tuios_` plus the verb with `_` for `-` |
   | `write` | listed only with `--write`; set it for any verb the daemon classes `scopeWrite` or `scopeLaunch`, or every call fails `forbidden` |
   | `hide` | params an agent must never pass (human nonces, legacy spellings) |
   | `hideOwn` | params that reach across sessions, hidden under scope own |
   | `self` | params that default to the caller's own pane |
   | `untrusted`, `markUntrusted` | results that carry pane text or mail |
   | `waits`, `base` | so the client deadline covers blocking verbs (default 30 s) |
   | `note` | extra description text |

   Keep the list short. The comment at `tools.go:63-64` says why: every tool costs context in every harness session that loads the server.

2. **Write a custom `run` only for a tool that is not one verb call.**

   A streaming tool gets `run func(s *Server, c Conn, in map[string]any) map[string]any` and is appended in `buildTools`, as `eventsTool` is (`tools.go:165`, `:329-353`). Build its schema by hand, list every argument in `args` (the unknown-argument check uses it) and return through `s.success(...)` or `errorResult(...)`.

3. **Name the tool in the skill and the CLI reference.**

   `TestSkillNamesEveryMCPTool` (`cmd/tuios/mcp_command_test.go:302-322`) builds the server with `Write: true` from the real verb table and fails if any tool name is missing from the "The tools" paragraph of `skills/tuios/mcp.md` **or** from the `tuios mcp` section of `docs/CLI_REFERENCE.md` (around lines 3205-3240). It also requires at least 15 tools. Update `docs/AGENT_STATE.md` "The MCP server" (`:2828-2871`) too. For a write tool, also update the `--write` text in `cmd/tuios/mcp_command.go:39-40,75` and the `initialize` instructions in `internal/mcp/server.go:323-325`.

4. **Add tests.**

   `internal/mcp/server_test.go` drives the server with a fake `Conn` through `startServer(t, Options{...})`. Model new cases on `TestDefaultToolsAreReadMostly` (`:290`), `TestEveryCallRestrictsItsConnectionFirst` (`:355`), `TestAnUnknownArgumentIsRefusedBeforeTheDaemon` (`:415`) and `TestPaneTextIsMarkedUntrusted` (`:427`). The end-to-end stdio test is `TestMCPServerOverStdioIsHeldToItsPane` (`cmd/tuios/mcp_command_test.go:127`).

   ```sh
   go test ./internal/mcp/ -count=1
   go test ./cmd/tuios/ -run 'MCP|Skill' -count=1
   go test ./internal/session/ -run VerbScopes -count=1
   ```
:::

### Verify it

`tools/list` does not contact the daemon; it is built from the compiled verb table. So this works anywhere, with a freshly built binary:

```sh
go build -o /tmp/tuios ./cmd/tuios
printf '%s\n' \
 '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}' \
 '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
 | /tmp/tuios mcp | jq -r 'select(.id==2) | .result.tools[].name'
```

Expect `tuios_get_window` in the list. Inside a tuios pane, call it:

```sh
printf '%s\n' \
 '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}' \
 '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"tuios_get_window","arguments":{}}}' \
 | /tmp/tuios mcp
```

An argument the schema lacks is refused before the daemon is contacted. This is real 0.8.5 output for `tuios_list_windows` with `"arguments":{"foo":1}`:

```json
{"jsonrpc":"2.0","id":2,"result":{"content":[{"text":"{\"detail\":{\"accepted\":[\"session\"]},\"error\":\"tool tuios_list_windows has no argument foo\"}","type":"text"}],"isError":true}}
```

### How a call runs

1. The arguments must be a JSON object, and every key must be in the schema (`server.go:431-435`).
2. The server dials a **fresh connection per call** and sends `restrict-connection` with `{scope, read_only: !write, pane_id?, pane_token?}`. A daemon that answers `unknown_verb` fails the call; the server never runs a call unrestricted.
3. `self` params are filled with the pane the daemon placed the caller in.
4. The verb runs with the computed deadline. A daemon error becomes `isError: true` with its `code` and `hint` kept.

The daemon, not the MCP process, enforces the limits. The caller's pane is found from the kernel's peer pid, and only when that fails is `pane_id` checked against `pane_token`. A server running in no pane under scope own reaches nothing (`TestMCPServerWithoutAPaneReachesNothing`).

### Gotchas

- The tool list comes from **this binary's** verb table, not the daemon's. A newer `tuios mcp` talking to an older daemon can list a tool whose verb the daemon lacks; the call then returns `unknown_verb`. Restart the daemon (`tuios kill-server`, which closes every pane).
- `readOnlyHint: true` is set on every non-`write` tool, including `tuios_set_agent_state` and `tuios_send_agent_message`, which change state. "Read-only" here means "cannot type into a pane".
- `tools/call` with an extra or misspelled argument fails before the daemon. Agents must use the exact verb param names.
- `Accepted` values appear in the description as text, not as a JSON Schema `enum`, because some params take comma-separated lists.

## How to add a protocol verb and its CLI subcommand

The daemon speaks a line-delimited JSON verb protocol on its unix socket. Every CLI command that talks to the daemon is a client of it, and so are the herdr socket, the MCP server, the tmux shim and the `pkg/tuios` library. *Using* the protocol needs only a socket client in any language. *Adding* a verb needs Go in `internal/session`, and usually a matching subcommand in `cmd/tuios`. There is no config route. Adding a verb is backward compatible and does not bump `VerbProtocolVersion = 1` (`internal/session/verb_protocol.go:37-41`). The live v0.8.5 daemon has 106 verbs; [CLI](cli.md) lists the commands that front them.

### The wire, briefly

```js
// request: one JSON line
{ id: 1 /* or "str"; optional; echoed */, verb: "list-windows", params: { session: "work" } }
// success
{ id: 1, result: { type: "window_list", /* every result has a type discriminator */ } }
// failure
{ id: 1, error: { code: "session_not_found", message: "...",
                  hint: { verb, command, param, accepted, did_you_mean, available, detail } } }
```

Real 0.8.5 exchanges with `nc -U`:

```text
$ printf '{"id":1,"verb":"hello"}\n' | nc -U -w 2 "$TUIOS_SOCKET"
{"id":1,"result":{"daemon_version":"0.8.5","instance":"7d02...","link_policy":true,"min_protocol":1,"pane_grants":true,"pid":24728,"protocol":1,"sessions":3,"type":"hello"}}

$ printf '{"id":3,"verb":"list-glyphs","params":{"bogus":1}}\n' | nc -U -w 2 "$TUIOS_SOCKET"
{"id":3,"error":{"code":"invalid_params","message":"verb list-glyphs has no parameter bogus","hint":{"verb":"list-verbs","command":"tuios list-verbs list-glyphs","param":"bogus","accepted":["session","glyphs"],"detail":"An unknown parameter is refused rather than silently ignored. Fix the name and retry."}}}
```

::: warning
The shell example in `docs/protocol.md:4789` uses `${XDG_RUNTIME_DIR:-/tmp/tuios-$(id -u)}/tuios/tuios.sock`. The code's fallback is `/tmp/tuios-<uid>/tuios.sock`, with **no** extra `tuios/` segment (`internal/session/manager_unix.go:39-44`). On macOS, where `XDG_RUNTIME_DIR` is normally unset, the documented one-liner points at a path that does not exist. Inside a pane, use `$TUIOS_SOCKET`. The doc's `hello` example also omits the `instance` field.
:::

### How a line is admitted

`dispatchVerbLine` (`verb_protocol.go:2163`) rejects bad JSON and a missing `verb` with `invalid_request`. Then `admitVerb` (`:2221`) runs every gate in this order:

1. the verb exists, else `unknown_verb` with `did_you_mean`;
2. `checkParamNames` (`:2299`): **any param not declared in the entry is refused** with `invalid_params`;
3. `checkLinkVerb`: the link policy for a call over a host link;
4. `followRenamedSession`;
5. `checkGrants`: pane grants for a caller inside a pane;
6. `checkScope`: the `restrict-connection` scope.

`callVerb` (`:2269`) runs the same admission for in-daemon reuse, and the herdr adapters use it. So a verb you add is held to grants, scope and link policy wherever it is called from.

### Steps

The example is a read-only verb, `count-windows`, that reports how many windows a session has. It does not exist in v0.8.5.

::: howto
1. **Write the handler.**

   New file `internal/session/verb_count_windows.go`. Use `decodeParams` (`verb_handlers.go:27`; empty params are allowed) and `resolveVerbSession` (`verb_handlers.go:43`; returns `session_not_found` with `available` and `did_you_mean`). Always return a value whose `"type"` key names the result shape.

   ```go
   package session

   import "encoding/json"

   // verbCountWindows reports how many windows a session holds.
   func (d *Daemon) verbCountWindows(_ *connState, params json.RawMessage) (any, *verbError) {
       var p struct {
           Session string `json:"session"`
       }
       if verr := decodeParams(params, &p); verr != nil {
           return nil, verr
       }
       sess, verr := d.resolveVerbSession(p.Session)
       if verr != nil {
           return nil, verr
       }
       return map[string]any{
           "type":    "window_count",
           "session": sess.Name(),
           "total":   len(sess.GetState().Windows),
       }, nil
   }
   ```

   A verb that needs a live renderer routes with `routeToTUISync` (`daemon_command.go:240`) or fails with `needs_client`.

2. **Register it.**

   Add the entry to the `init()` map literal in `verb_protocol.go:254-2063`, or to a helper map merged with `maps.Copy`, as `agentWorkVerbs()` is (`verb_protocol_agents.go:34`, merged at `verb_protocol.go:2066`). The `params` list is both the schema and the unknown-param allowlist.

   ```go
   "count-windows": {
       description: "Count the windows in a session.",
       params:      []verbParam{sessionParam},
       returns: []verbParam{
           {Name: "session", Type: "string", Description: "The session counted."},
           {Name: "total", Type: "int", Description: "How many windows it holds."},
       },
       examples: []string{`{"id":1,"verb":"count-windows","params":{"session":"work"}}`},
       handler:  (*Daemon).verbCountWindows,
   },
   ```

   Shared params are `sessionParam` (`:223`), `windowParam` (`:230`) and `selectWriteParams()` (`:241`).

3. **Classify its scope.**

   `internal/session/conn_scope.go:97`, in `verbScopes`. This also drives pane grants.

   ```go
   "count-windows": scopeRead,
   ```

   | Class | Under `own` | Under `read_only` |
   |---|---|---|
   | `scopeOpen` | allowed | allowed |
   | `scopeGlobal` | forbidden | allowed |
   | `scopeRead` | session must be in reach | allowed |
   | `scopeSelf` | own pane only | allowed |
   | `scopeMail` | session in reach, sent as own pane | allowed |
   | `scopeWrite` | session in reach | forbidden |
   | `scopeLaunch` | needs a pane | forbidden |
   | `scopeDeny` or missing | forbidden | forbidden |

4. **Give it a link capability.**

   `internal/session/link_policy.go:59`, in `verbCapabilities`. `nil` needs nothing; otherwise a list from `config.LinkAllowList/Mail/Open/Write/Respond`, or `{capRelay}` for everything.

   ```go
   "count-windows": {config.LinkAllowList},
   ```

5. **Mark it as typing, only if it writes keystrokes.**

   Add it to `typingVerbs` (`pane_grants.go:757`) and use `scopeWrite`.

6. **Add a new error code, only if you need one.**

   Add the `ErrVerbX = "x"` constant, an `errorCodeCatalog` row (`verb_hints.go:73`) and a row in the `docs/protocol.md` "Error codes" table. Codes are stable and only ever added.

7. **Publish events, only if subscribers care.**

   `d.events.publish(streamEvent{Type: ..., Session: ..., Window: ...})`. A new event type needs an `Event*` constant in `daemon_events.go`, an entry in `EventTypeNames` (`verb_hints.go:57`, which feeds `subscribe`'s accepted `types` and CLI completion) and a row in the `docs/protocol.md` "Event stream" table. Window lifecycle events come from state diffs; do not emit them by hand.

8. **Add the CLI subcommand.**

   In `cmd/tuios`, following `list-glyphs` (`cmd/tuios/main.go:1863-1908` and `glyph_commands.go:32-50`). The helpers `dialVerb` (`diagnostics.go:234`), `explainVerbError` (`diagnostics.go:269`), `printVerbResult` (`remote_commands.go:120`) and `reportVerbError` (`remote_commands.go:145`) are the house idiom.

   ```go
   var countSession string
   var countJSON bool
   countWindowsCmd := &cobra.Command{
       Use:   "count-windows",
       Short: "Count the windows in a session",
       Long:  `Count the windows in a session, the most recently active one by default.`,
       Example: `  tuios count-windows
     tuios count-windows -s work --json`,
       Args: cobra.NoArgs,
       RunE: func(_ *cobra.Command, _ []string) error {
           client, err := dialVerb()
           if err != nil {
               return err
           }
           defer func() { _ = client.Close() }()
           raw, err := client.Call("count-windows", map[string]any{"session": countSession})
           if err != nil {
               return reportVerbError(explainVerbError("count-windows", err), countJSON)
           }
           return printVerbResult(raw, countJSON)
       },
   }
   countWindowsCmd.Flags().StringVarP(&countSession, "session", "s", "", "Target session (default: most recently active)")
   countWindowsCmd.Flags().BoolVar(&countJSON, "json", false, "Output as JSON")
   _ = countWindowsCmd.RegisterFlagCompletionFunc("session", completeSessionNames)
   ```

   Then add it to one of the `rootCmd.AddCommand(...)` lines (`main.go:2934-2953`). The conventions are in the next how-to.

9. **Self-description: nothing to do.**

   `list-verbs`, `tuios list-verbs count-windows` and `session.VerbDocs()` all read the registry entry. "The `accepted` lists are the same lists the handlers enforce" (`docs/protocol.md:1324-1327`), and `TestListVerbsAcceptedValuesMatchTheImplementation` checks it.

10. **MCP: add it by hand if agents should see it.**

    See the previous how-to. Add `{name: "tuios_count_windows", verb: "count-windows"}` to `internal/mcp/tools.go` and name it in `skills/tuios/mcp.md` and `docs/CLI_REFERENCE.md`.

11. **Docs and skill.**

    Add an entry to `docs/CLI_REFERENCE.md`, and optionally a `### count-windows` section to `docs/protocol.md` (whose catalog "is deliberately partial"). If you show the command in a `skills/tuios/*.md` `sh` fence, `TestSkillCommandsResolve` (`cmd/tuios/skill_test.go:19`) resolves it against `newRootCommand()`, flags and argument counts included. `TestAgentGuideCommandsResolve` (`cmd/tuios/docs_links_test.go:13`) does the same for the setup part of `docs/AGENT_STATE.md`.

12. **Write the test.**

    Use the in-package helpers in `internal/session/verb_protocol_test.go`: `startTestDaemon` (`:22`, isolated `XDG_RUNTIME_DIR`), `makeSessionWithWindow` (`:123`) and the raw line client `dialVerb` (`:63`).

    ```go
    func TestCountWindows(t *testing.T) {
        d, sp := startTestDaemon(t)
        makeSessionWithWindow(t, d, "work")
        c := dialVerb(t, sp)
        res := result(t, c.call(t, `{"id":1,"verb":"count-windows","params":{"session":"work"}}`))
        if res["type"] != "window_count" || res["total"] != float64(1) {
            t.Fatalf("got %v", res)
        }
        if code := errCode(t, c.call(t, `{"verb":"count-windows","params":{"session":"nope"}}`)); code != ErrVerbSessionNotFound {
            t.Fatalf("code %s", code)
        }
    }
    ```

    ```sh
    go test ./internal/session/ -run 'Verb|CountWindows|EveryVerb|VerbScopes|LinkPolicy' -count=1
    go test ./cmd/tuios/ -count=1
    ```
:::

### The side tables and the tests that hold them

`verb_protocol_agents.go:1-12` states the convention: register a verb "together with its scope (conn_scope.go), its link capability (link_policy.go) and, for the two that type into a pane, their place in typingVerbs (pane_grants.go), so the tests that hold those tables to the registry pass from the start".

| Table | File:line | Enforcing test |
|---|---|---|
| `verbScopes` | `conn_scope.go:97` | `TestVerbScopesNameEveryVerb` (`conn_scope_test.go:15`) |
| `verbCapabilities` | `link_policy.go:59` | `TestEveryVerbHasALinkPolicy` (`link_policy_test.go:26`) |
| `typingVerbs` (typing verbs only) | `pane_grants.go:757` | the grants tests |
| `exampleOutcomes` (an example expected to error or block on a bare fixture) | top of `verb_reachability_test.go` | `TestEveryVerbExampleReachesItsHandler` (`:232`) |
| `verbsWithNoDocumentedResult` (legacy; do not add to it) | `verb_reachability_test.go` | `TestVerbResultSchemasAreDeclaredOrListed` (`:367`) |
| `errorCodeCatalog` (new codes only) | `verb_hints.go:73` | `TestErrorCodeCatalogHasEveryErrVerbConstant` (`verb_introspect_test.go:18`) |
| `fuzzReadVerbs` (optional) | `fuzz_verb_test.go:46` | the `FuzzVerb...` targets |

`TestEveryVerbIsDocumentedWellEnoughToCall` (`verb_strict_params_test.go:63`) requires a non-empty description, at least one example, a `name`/`type`/`description` on every param and return, and a non-empty `returns`.

::: note
The reachability test runs every example against a fixture daemon. If the fixture has no session `work`, the example above fails with `session_not_found`. Either write an example that works on the fixture (`"params":{}` uses the most recent session), or add `"count-windows#0": {errCode: ErrVerbSessionNotFound, why: "..."}` to `exampleOutcomes`.
:::

### Verify it

```sh
go run ./cmd/tuios list-verbs count-windows
go run ./cmd/tuios list-verbs --json | jq '.verbs[] | select(.verb=="count-windows")'
printf '{"id":1,"verb":"count-windows"}\n' | nc -U -w 2 "$TUIOS_SOCKET"
tuios logs -f      # every refusal logs: Verb <name> refused for client <id>: <code>
```

The new verb answers only from a daemon built from your tree. Restart with `tuios kill-server` after installing the new binary, and confirm with `hello`'s `daemon_version`.

### Gotchas

- **Unknown params are fatal**, never ignored. A client newer than the daemon gets `invalid_params` naming the field. Feature-detect with `list-verbs <verb>`, as `cmd/tuios/agent_hook.go:595` does.
- An omitted `session` means "the most recently active session", with exceptions: `subscribe` (all sessions), `wait-for session-exists`, `kill-session` and `remove-worktree` (required).
- `VerbClient.Call` has a 30 s read deadline (`verb_client.go:180`). A verb that blocks longer needs `CallWithTimeout` on the client side.
- `socat` is not on stock macOS. `nc -U -w 2 "$SOCK"` works for a one-shot call.

## How to add a CLI subcommand

A `tuios` subcommand is a plain `github.com/spf13/cobra` command in package `main` under `cmd/tuios`, rendered by a vendored copy of `charmbracelet/fang` (`internal/fang`, v1.0.0 with the hidden `man` command and `golang.org/x/text/cases` removed to save 375 KB). It always needs Go: there is no alias or plugin mechanism. The closest config-only alternative is a `[[keybindings.command]]` entry or a dock component that runs a script. If your command fronts a **new** daemon verb, do the previous how-to first; its step 8 is this how-to applied.

### Steps

The example `tuios hello` calls the existing `list-windows` verb and prints the window count. It is modelled on `cmd/tuios/close_workspace_command.go:13-92`.

::: howto
1. **Write a constructor in its own file.**

   Newer commands use `func newXxxCommand() *cobra.Command` in `xxx_command.go`. Use `RunE`, never `Run`: `interceptErrors` wraps only `RunE` (`diagnostics.go:202-205`), so a `Run` command's failures bypass the exit-status logic.

   ```go
   // cmd/tuios/hello_command.go
   package main

   import (
       "encoding/json"
       "fmt"
       "os"

       "github.com/spf13/cobra"
   )

   // newHelloCommand builds `tuios hello`: print the session name and its window count.
   func newHelloCommand() *cobra.Command {
       var sessionName string
       var jsonOutput bool
       cmd := &cobra.Command{
           Use:   "hello",
           Short: "Say hello to a session",
           Long: `Print the session's name and how many windows it has.

   Inside a tuios pane, the session is the session of the pane. Outside, it is the
   most recently active session. -s names a different one.`,
           Example: `  # Greet this pane's session
     tuios hello

     # Greet the session work, as JSON
     tuios hello -s work --json`,
           Args: cobra.NoArgs,
           RunE: func(_ *cobra.Command, _ []string) error {
               if sessionName == "" {
                   sessionName = os.Getenv("TUIOS_SESSION")
               }
               t, err := dialSessionTarget(sessionName)
               if err != nil {
                   return err
               }
               defer t.Close()
               raw, err := t.client.Call("list-windows", t.params(nil))
               if err != nil {
                   return reportVerbError(t.explain("list-windows", err), jsonOutput)
               }
               if jsonOutput {
                   return printVerbResultOn(t, raw, true)
               }
               var res struct {
                   Windows []json.RawMessage `json:"windows"`
               }
               if err := json.Unmarshal(raw, &res); err != nil {
                   return fmt.Errorf("failed to parse response: %w", err)
               }
               fmt.Printf("Hello, %s: %d windows.\n", t.session, len(res.Windows))
               return nil
           },
       }
       cmd.Flags().StringVarP(&sessionName, "session", "s", "", "Target session (default: this pane's session, else the most recently active)")
       cmd.Flags().BoolVar(&jsonOutput, "json", false, "Output result as JSON")
       _ = cmd.RegisterFlagCompletionFunc("session", completeSessionNames)
       return cmd
   }
   ```

   The `windows` field of `list-windows` above is illustrative; check `tuios list-verbs list-windows` for the real result fields.

2. **Register it.**

   Add `newHelloCommand()` to one of the `rootCmd.AddCommand(...)` lines in `cmd/tuios/main.go:2934-2953`.

3. **Follow the house conventions.**

   | Convention | Detail |
   |---|---|
   | fields | `Use` (`name [arg]`), `Short` (a sentence, usually no period), `Long` (plain prose wrapped near 80), `Example` (two-space indent, a `# comment` line before each command), `Args` |
   | common flags | `-s/--session`, `-w/--window`, `--json` (about 70 commands have it); `--json` errors print `{"success":false,"error":...}` and exit 1 |
   | completion | `cmd.RegisterFlagCompletionFunc("session", completeSessionNames)` |
   | user-fixable failure | return `*diagnosticError{What, Cause, Fix, Extra, Status, Err}`; it prints as What/Cause/Fix on a terminal |
   | exit codes | 0 ok, 1 error, 2 `ask-human` returned before an answer, 3 no daemon running |
   | internal commands | `Hidden: true` |

   The interface flags (`--theme`, `--ascii-only`, `--border-style` and the rest, `internal/cliflags/cliflags.go:44-65`) are bound only on the bare root, `attach`, `new`, `ssh` and `tape play`, so daemon-talking commands do not inherit flags that mean nothing to them. To add one, add a field on `Interface`, a line in `Register`, and a field in `config.Overrides` and in `Overrides()`; `tuios-web` picks it up automatically.

4. **Document it.**

   `docs/CLI_REFERENCE.md` is hand-written (4335 lines, no generator). If an agent in a pane should use the command, show it in an `sh` fence of the relevant `skills/tuios/*.md` topic; that line then becomes a test case.

5. **Run the tests.**

   ```sh
   go test ./cmd/tuios/ -count=1
   go test ./cmd/tuios/ -run 'TestEveryHelpRenders/hello' -v
   go run ./cmd/tuios hello --help
   ```
:::

### Verify it

| Test | File:line | What it does |
|---|---|---|
| `TestEveryHelpRenders` | `help_render_test.go:19` | runs `<path> --help` for the whole tree through `fang.Execute`; fails on a panic or a missing `USAGE`; requires at least 50 commands |
| `TestSkillCommandsResolve` | `skill_test.go:19` | every `tuios ...` in the skill's `sh` fences resolves (see the skill how-to) |
| `TestAgentGuideCommandsResolve` | `docs_links_test.go:13` | the same for `docs/AGENT_STATE.md` before `## Reference` |
| `TestDockExampleCommandsResolve` | `new_window_docs_test.go:18` | `"tuios ..."` strings in `docs/CONFIGURATION.md` and `examples/dock/dock.toml` |
| `TestSetConfigHelpExamplesAreAccepted` | `set_config_help_test.go:14` | every `tuios set-config <path>` example in help is accepted |
| isolation | `main_test.go:17` | `testutil.RunIsolated` redirects XDG dirs to a temp tree, disables sound, and fails the run if anything escaped to your files |
| fuzzer not linked | `imports_test.go:26` | the shipped binary must not link `internal/fuzz` |

A new Go package should copy `main_test.go` with `RunIsolated`; 49 packages already have one.

### Gotchas

- A subcommand whose name matches a skill topic (`mcp`, `hosts`, `tmux`, `herdr`, `config`) works only because `skillArgs` rewrites `--skill X` to `--skill=X` before cobra sees it (`cmd/tuios/skill_args.go:9-19`).
- A bare `=` word in `Example` used to panic fang; `TestEveryHelpRenders` exists to catch that class of bug.
- `tuios` also dispatches on `argv[0]`: run as `tmux` or `herdr` (through a link), it parses that program's command line instead (`main.go:55-62`).

## How to add a skill topic

The agent skill that `tuios --skill` prints is Markdown compiled into the binary, so the copy a binary prints always describes that build. A topic is one file, `skills/tuios/<name>.md`. Adding one is **Markdown only**, but tests hold every command in it to the real command tree, so you need a Go build and `go test ./cmd/tuios/` to validate it. There is no runtime or user-supplied skill directory: a user cannot add topics without rebuilding.

v0.8.5 ships the core (`skills/tuios/SKILL.md`, with YAML front matter `name: tuios`) and 14 topics: `config errors events fleet grants herdr hosts inbox mail mcp panes recipes state tmux`.

### How it is embedded

```js
// skills/skills.go
//go:embed tuios/SKILL.md   -> var TUIOS string          (:24-25)
//go:embed tuios/*.md       -> var files embed.FS         (:27-28)
skills.Topics()  // every tuios/*.md except SKILL.md, sorted by name (:40)
skills.Lookup(x) // "" | "core" -> TUIOS; "all" -> All(); "fleet" -> that topic;
                 // "nope" -> error: no skill topic "nope"; the topics are core, all, config, errors, ...
```

### Steps

::: howto
1. **Create the file.**

   `skills/tuios/<name>.md`. The file name minus `.md` is the topic name. No front matter (only `SKILL.md` has it). Start with a `# Title` heading.

   ````markdown
   # Pane notes

   Leave yourself a note in a window title.

   ```sh
   tuios set-window -w "$TUIOS_PANE_ID" --name "note: rerun tests"
   tuios list-windows --json
   ```
   ````

2. **Put every runnable command in an `sh` fence.**

   `shellBlocks` matches `strings.HasPrefix(line, "```sh")` (`cmd/tuios/skill_test.go:77`). Every `tuios ...` call inside becomes a test case. Commands in `bash`, `console` or untagged fences are **not** checked.

3. **Add a row to the Topics table.**

   The `## Topics` table at the end of `skills/tuios/SKILL.md`:

   ```markdown
   | `notes` | Leaving notes in window titles |
   ```

4. **Validate.**

   ```sh
   go test ./cmd/tuios/ -run 'TestSkill' -count=1 -v
   go run ./cmd/tuios --skill notes
   go run ./cmd/tuios --skill all | wc -l
   ```
:::

### Verify it

`TestSkillCommandsResolve` (`skill_test.go:19-43`) extracts every `tuios` call from every `sh` fence of `skills.All()` and requires at least 150 of them. For each one, `newRootCommand().Find(args)` must find a command, a leftover non-flag word on the root fails ("is not a tuios command"), `cmd.ParseFlags(rest)` must accept every flag and `cmd.ValidateArgs` must accept the positional count. The example above passes because `set-window` takes `-w` and `--name` and no positional arguments.

Other tests check facts a topic restates:

| Test | File:line | Checks |
|---|---|---|
| `TestSkillInlineCommandsResolve` | `skill_test.go:47` | prose mentions of `start-server`, `attach`, `run-command` still exist; extend the list when prose names a new command |
| `TestSkillKeyTableListsEveryKeyName` | `skill_keys_test.go:14` | the `### Key names` table in `panes` lists every `session.KeyNames()` entry |
| `TestSkillListsEveryErrorCode` | `skill_agents_test.go:22` | `errors` names every verb error code |
| `TestSkillIsHonestAboutRestoringConfig` | `skill_agents_test.go:39` | `config` names each option whose default `""` is not in its accepted set, with the count |
| `TestSkillNamesEveryMCPTool` | `mcp_command_test.go:302` | `mcp` and `docs/CLI_REFERENCE.md` name every MCP tool |

The test's shell parser (`shellCalls`, `skill_test.go:91-149`) is "enough of" a shell. Quotes group words and may span lines; an unquoted newline, `;`, `|` or `&` ends a call; `#` starts a comment only at a word start. So:

- `$(tuios ...)` inside another command is not split out; keep substitutions simple or on their own line.
- Placeholders such as `<id>` count as positional words: `tuios get-window <id> extra` fails `MaximumNArgs(1)`.
- A trailing `\` continuation is not special. Prefer one call per line.

### Gotchas

::: warning
**No test checks the `## Topics` table.** Nothing verifies that `SKILL.md` lists every file or that every listed topic exists. A missing row only makes the topic undiscoverable from `tuios --skill`; the error from an unknown topic does list them all.
:::

- `TestSkillCommandsResolve` resolves against the *command tree*, not the daemon. A call whose verb is refused at runtime still passes.
- A topic name may collide with a subcommand (`mcp`, `hosts`, `config`); the `skillArgs` rewrite makes `tuios --skill mcp` print the topic. The rewrite stops at the first subcommand word, so `tuios attach --skill x` is passed through.
- `tuios integration install` does not copy skill files into a harness's skill directory. Harnesses are told to run `tuios --skill`.
- `AGENTS.md` is for agents working **on** the code; the skill is for agents running **inside** a pane.

## How to add a tape command

A `.tape` file is a line-oriented script of keystrokes and window-manager commands. Writing tapes needs no Go and is covered in [Automation](automation.md). A new command keyword needs Go in `internal/tape` and `internal/app`. tuios has three tape dialects with different grammars, and a new command can land in any of them:

| Dialect | Parsed by | Entry points |
|---|---|---|
| recorder / automation tape (`*.tape`) | `internal/tape` lexer and parser | `tuios tape play`, `tape validate`, `tape exec`, in-app recording |
| single tape command | `tape.ResolveCommandName` | `tuios run-command <Cmd> [args]`, verb `run-command` |
| project tape (`.tuios.tape`) | `tape.ParseProjectHeader` + `compileProjectBody` (`internal/app/tape_body.go:44`) | `cd` into a directory inside tuios |

`docs/TAPE_SCRIPTING.md` and `docs/TAPE_RECORDING.md` are 5-line stubs that point at https://tuios.dev/docs/tape-scripting.

### Steps

The example adds `Repaint`, which forces a full repaint, wired the same way as the existing `ToggleZoom` (`CommandTypeToggleZoom`, `TokenToggleZoom`, `ToggleZoomExec`).

::: howto
1. **Add the command type.**

   `internal/tape/command.go`: a constant, appended to the `commandTypes` slice. That slice feeds `IsCommand` and `ResolveCommandName`, so `tuios run-command Repaint` works from this step on.

   ```go
   // CommandTypeRepaint represents the Repaint command.
   CommandTypeRepaint CommandType = "Repaint"
   ```

2. **Add the keyword, if `.tape` files should accept it.**

   `internal/tape/token.go`: a token, an entry in `KeywordTokenMap` (`token.go:203`) and the token in the `IsCommand()` switch (`token.go:161-180`).

   ```go
   TokenRepaint TokenType = "Repaint"
   // in KeywordTokenMap:
   "Repaint": TokenRepaint,
   ```

   Without this step, a `.tape` file that says `Repaint` fails with `unexpected token: IDENTIFIER`, like `SetTheme` does today.

3. **Parse it.**

   `internal/tape/parser.go`, in `parseCommand` (`:72-180`):

   ```go
   case TokenRepaint:
       return p.parseBasicCommand(CommandTypeRepaint)
   ```

   If the command takes arguments, write a dedicated `parseXCommand`, because `parseBasicCommand` keeps only a trailing NUMBER and silently drops everything else.

4. **Extend the executor contract.**

   `internal/tape/executor.go`: a method on the `Executor` interface (`:13-85`) and a case in `Execute`. Return `errMissingArg(...)` for a missing argument rather than nil (`:421`).

   ```go
   // in Executor
   RepaintExec() error

   // in Execute's switch
   case CommandTypeRepaint:
       return ce.executor.RepaintExec()
   ```

5. **Implement it on the app model.**

   `internal/app/os_tape_executor.go`. `*OS` is the only real `Executor`; the test `nopExecutor` embeds the interface, so it keeps compiling.

   ```go
   // RepaintExec redraws every pane (tape executor interface).
   func (m *OS) RepaintExec() error {
       m.MarkAllDirty()
       return nil
   }
   ```

6. **Run it headless, optionally.**

   With no client attached, the daemon runs only a small subset itself (`internal/session/daemon_native.go:56-170`) and answers `needs_client` for the rest. Add a `case "Repaint":` to `executeDaemonCommandAt` only if the command makes sense without a renderer, and to `daemonOwnedCommands` (`daemon_command.go:22`) if the daemon must always own it. A repaint needs a client, so skip this.

7. **Decide whether a linked machine may send it.**

   Commands from another host are filtered by `hostTapeCommandAllowed` (`internal/session/tuiclient_host.go:127-165`), which today refuses `SetConfig`, `SetTheme`, `Screenshot`, `SaveLayout`, `LoadLayout`, `Source` and others. Add the command there if it is safe.

8. **List it for `run-command --list`.**

   `cmd/tuios/remote_commands.go:2162`, in `runCommandCatalog()`; add argument completions to `getRunCommandArgCompletions` (`:2383`) when the arguments come from a closed set.

   ```go
   {"Repaint", "Redraw every pane", "tuios run-command Repaint"},
   ```

9. **Have the recorder emit it, optionally.**

   `internal/tape/recorder.go`, when the matching action happens during recording.

10. **Test it.**

    Add a keyword round trip to `internal/tape/parser_test.go`, a lexer case to `lexer_test.go`, an executor case in the style of `TestExecuteRejectsUnusableCommands` in `executor_test.go`, and seeds to `fuzz_test.go` / `fuzz_roundtrip_test.go`, which the ordinary suite runs.

    ```sh
    go test ./internal/tape/ ./internal/app/ ./internal/session/ ./cmd/tuios/ -count=1
    ```
:::

### Verify it

```sh
printf 'NewWindow\nSleep 500ms\nRepaint\n' > /tmp/x.tape
go run ./cmd/tuios tape validate /tmp/x.tape
go run ./cmd/tuios run-command --list | grep Repaint
```

`tape validate` is a deterministic parse that needs no daemon. It prints `✓ Tape file is valid` and a numbered command summary, or `line N: ...` errors. `tuios tape play file.tape` lets you watch it; script errors appear as notifications and playback continues.

`TestRunCommandListOffersOnlyAcceptedValues` and `TestRunCommandCompletionsMatchAccepted` (`cmd/tuios/run_command_list_test.go:13,39`) hold the listed values to the `config.*` lists.

### Gotchas in the existing grammar

These are facts about v0.8.5 that a new command must not copy:

::: warning
**`Split` cannot work from a recorder tape.** It needs `horizontal|vertical`, which `parseBasicCommand` drops, so `Split horizontal` validates as `[Split]` and always fails at run time. Use `SmartSplit`, `tuios run-command Split vertical`, or a project tape, whose own body language does accept `Split vertical`.
:::

| Line | What happens |
|---|---|
| `Sleep 500` | `line 1: Sleep command expects a duration, got NUMBER` |
| `FocusWindow "Server"` | `FocusWindow expects a window ID, got STRING` (only an unquoted identifier or number works) |
| `SetTheme dracula` | `unexpected token: IDENTIFIER` (run-command only) |
| `Focus x`, `Set k v`, `Output f`, `Source f` | parse, then do nothing (no executor case) |
| `Type@50ms "slow"` | types instantly: `@duration` is read only by `Sleep`/`Wait` |
| `Ctrl+B` | typed into the pane as `^B`; key combos go to the PTY, not the keymap (`Alt+1`..`Alt+9` excepted) |
| `Wait 1s`, `WaitUntilRegex` under `tape exec` | no-ops (`executor.go:315-321`); only `Sleep` delays there |

`tuios tape exec` and the TUI ignore parse errors and run the valid commands, so run `validate` first. Do not test a `.tuios.tape` body with `tape validate`: its `Split vertical` and `Focus "x"` lines belong to a different language.

## How to add a context-menu entry

The right-click menu depends on what is under the pointer: a pane, the desktop, the dock, a dock item, a workspace pill, a rail session row, a rail host header or a rail file row. A row carries only a keybind-registry action id, and choosing it runs the same `ActionDispatcher` handler a key would. The key hint on each row is read from the live registry, so a rebind moves the hint. Menus are hard-coded in Go; there is no config to add rows. If the row needs an action that does not exist yet, write the action first with the keybinding how-to above.

### The menus in v0.8.5

```js
paneMenu      = ["copy_selection"(dim: no selection), "paste_clipboard"(dim: not terminal mode, or browser),
                 SEP, "split_vertical"(dim: !AutoTiling), "split_horizontal"(dim: !AutoTiling),
                 SEP, "rename_window", "set_accent"(dim: no rail), "toggle_zoom",
                 "screenshot_window", "minimize_window"(dim: scratch), "close_window"(Warn)]
dockItemMenu  = ["restore_minimized_N"(N = 1..9, dim beyond 9), "restore_all"]
workspacePill = ["workspace_pill_switch"(dim: current), "workspace_prefix_rename"]
dockMenu      = ["new_window", "toggle_tiling", "restore_all"(dim: none minimized)]
desktopMenu   = ["new_window", "toggle_tiling", SEP, "prefix_command_palette",
                 "prefix_settings", "toggle_help"]
sessionMenu   = ["rename_session", "set_session_accent", "prefix_detach"(dim: not attached),
                 "prefix_session_switcher", "prefix_workspace_switcher"(dim: not attached), SEP,
                 attached ? ["kill_session_next", "kill_session_quit"] : ["kill_session"]]   // Warn
selectionMenu = ["copy_selection", "paste_clipboard", "clear_selection"]
machineMenu   = ["reorder_up"(dim: first), "reorder_down"(dim: last)]
fileRowMenu   = ["file_open", ("file_edit" for files), SEP, "file_copy", "file_cut", "file_paste", SEP,
                 "file_create", "file_rename", "file_delete"(Warn), "file_delete_forever"(Warn)]
railSettings  = ["settings_sidebar"]
```

The builders are in `internal/app/contextmenu_build.go`: `paneMenu` (`:249`), `dockItemMenu` (`:298`), `workspacePillMenu` (`:321`), `dockMenu` (`:329`), `desktopMenu` (`:339`), `sessionMenu` (`:365`), `OpenSelectionMenu` (`:410`), `machineMenu` (`:453`), `fileRowMenu` (`:494`), and the rail dispatch `openSidebarContextMenu` (`internal/app/sidebar_mouse.go:676`).

### The contract for a row

- `Action` must be registered with the input dispatcher. If it is not, `runContextMenuAction` returns **silently** (`internal/input/contextmenu.go:29-31`).
- The handler receives a zero `tea.KeyPressMsg`, so it must not read the key.
- Data about the clicked target (which pill, which session row, which file) is carried by the menu and read with `o.TakeMenuWorkspace()` or `o.TakeMenuSession()` (or `m.menuFile` inside `app`), valid for that one dispatch. A pane menu instead focuses the pane before building.
- Prefer `Dim: true` over leaving an unavailable row out: dimmed rows are skipped by arrows and hit-testing but keep the menu's shape stable.
- Set `Warn: true` on a destructive row.
- Never write `Hint` by hand; `m.item()` fills it from the registry.
- Icons are Nerd Font codepoints (`glyphCopy`, `glyphZoom`, `glyphTiling` and the rest, `contextmenu_build.go:14-37`), dropped automatically when Nerd Fonts are off.

### Steps: add a row for an existing action

::: howto
1. **Insert the row in the right builder.**

   `internal/app/contextmenu_build.go`. The call is `m.item(icon, label, action, dim)` (`:229`); add `separator()` (`:240`) to start a group. Example: "Toggle tiling" on the pane menu, right after "Zoom":

   ```go
   m.item(glyphZoom, "Zoom", "toggle_zoom", false),
   m.item(glyphTiling, "Toggle tiling", "toggle_tiling", false), // new row
   ```

2. **Read the clicked target in the handler, if the action needs it.**

   ```go
   ws := o.TakeMenuWorkspace()
   ```

3. **Run the tests.**

   ```sh
   go test ./internal/app/ -run ContextMenu -count=1
   go test ./internal/input/ -count=1
   ```
:::

### Steps: add a row that needs a new action

::: howto
1. **Define the action.**

   A description in `config.ActionDescriptions` (`internal/config/registry.go:418`) and a handler registered with `d.Register("my_action", handleMyAction)` in `internal/input`. Model it on `workspace_pill_switch`: description at `registry.go:543`, registration at `internal/input/prefix_actions.go:105`, handler at `:269-274` reading `o.TakeMenuWorkspace()`.

2. **List it if it has no default key.**

   `internal/input/reachability_test.go:390-401`, in `actionsWithNoDefaultBinding`:

   ```go
   "my_action": "context menu row",
   ```

   Otherwise `TestEveryRegisteredActionIsBoundOrListed` fails. `TestEveryDescribedActionIsHandled` fails if the description exists with no handler.

3. **Block it in Learn mode, if it cannot work in the browser.**

   `learnUnavailable` in `internal/app/learn_mode.go:37`, with a note.

4. **Add the row** as in the previous steps.
:::

### Steps: add a new target

::: howto
1. **Add a `CtxTarget*` constant.** `internal/app/contextmenu.go:26-47`.

2. **Classify it.** In `contextMenuTargetAt` (`contextmenu_build.go:96`: dock band first, then the topmost window, then the desktop) or, for the rail, in `openSidebarContextMenu` (`sidebar_mouse.go:676`).

3. **Build it.** Add a `case` to `OpenContextMenu`'s switch (`contextmenu_build.go:69-80`) and a builder returning `(title string, items []ContextMenuItem)`.

4. **Cover it.** Add an anchor to `ctxAnchors` in `internal/app/contextmenu_test.go:38`, so `TestContextMenuFitsNarrowScreens` and `TestContextMenuHintsMatchRegistry` check it.
:::

### Verify it

`internal/app/contextmenu_test.go` holds the menu tests: `TestContextMenuFitsNarrowScreens` (`:63`, never drawn off-screen for every target, anchor and size), `TestContextMenuHintsMatchRegistry` (`:210`, every runnable row names an action and its hint matches the bound key), `TestContextMenuHintFollowsRebind` (`:249`), `TestContextMenuDimsUnavailableActions` (`:292`), `TestPaneMenuReadsItsOwnTargetsSelection` (`:336`) and others.

By hand: right-click the target (or <kbd>Ctrl</kbd>/<kbd>Shift</kbd>+right-click over a mouse-tracking app), check the row and its hint, and press <kbd>Enter</kbd> to run it. Arrows, <kbd>j</kbd>/<kbd>k</kbd> and <kbd>Tab</kbd> move; <kbd>Esc</kbd> closes.

### Gotchas

- An unregistered action name is a silent no-op at runtime. Only the hint test and the reachability tests catch it.
- `TestContextMenuHintsMatchRegistry` checks only the first four anchors (pane top row, pane inside, desktop, dock). Rail menus are not covered there.
- A plain right-click on a pane in terminal mode opens the menu only with `appearance.right_click_opens_menu = true` or on a touch client; otherwise the click belongs to the pane's program.
- A row acting on the clicked session or workspace must read `TakeMenu*`, not the attached or current one, or it acts on the wrong target.

## How to add a config option end to end

Almost every row on the settings page (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>,</kbd>, action `prefix_settings`) is derived from one hand-written option registry, the same registry behind `tuios list-options`, `get-config`, `set-config`, the tape `SetConfig` command and settings search. A new option is Go work; there is no plugin route. The user-facing side is in [Configuration](configuration.md).

### How one entry reaches everything

```js
optionSpecs[i] = { Path: "appearance.wrap_lists", Type: "bool", Section: "appearance",
                   Description: "...", Default: "true" }               // internal/config/options.go:249
  -> config.SetOptionValue / GetOptionValue (reflection on toml tags)   options.go:1292, :1351
  -> daemon verbs list-options / set-option / get-option                session/verb_options.go:31, :163, :322
  -> CLI list-options / get-config / set-config
  -> settings row: opt("appearance.wrap_lists")                          app/settings.go:503
       -> registryItem(path) picks the control from Type/Accepted/Color/Percent   app/settings_registry.go:304
  -> palette "Settings" rows, one per settings row                       app/command_palette_nav.go:126
```

The `Option` struct (`internal/config/options.go:22-75`):

| Field | Meaning | Settings row |
|---|---|---|
| `Path` | dotted TOML path | row identity |
| `Type` | `bool`, `int` or `string` | toggle, stepper or field |
| `Section` | one of `appearance, sidebar, dock, scrollbar, selection, startup, daemon, notifications, tape, debug, screenshot, screensaver, spotlight, hints, scratch, pip` | used by `list-options --section`, not the tab |
| `Description` | one line, required | row description |
| `Accepted` | closed set | cycler |
| `Default` | string form of what `DefaultConfig` holds | reset target, "changed" dot |
| `Min`/`Max` | int range, enforced only when `Max > 0` | stepper bounds (ceiling 1,000,000 otherwise) |
| `Deprecated` | reason | returned by set-option |
| `Color` | the string is a colour literal | colour picker |
| `Theme`, `GlyphSet` | must name a registered theme or glyph set | custom rows |
| `Percent` | an int that is a proportion | gauge with `%` |
| `Follows` | the option this follows while unset | "(follows X)" |
| `BoxSize` | cells (`60`) or percent (`80%`) | validated by `ParseBoxSize` |

The control is chosen in `registryItem` (`settings_registry.go:319-398`): `Color` first, then bool, then int, then a non-empty `Accepted`, else free text.

### Steps

The example adds a bool `appearance.flash_on_bell`, default `true`. It does not exist in v0.8.5.

::: howto
1. **Add the struct field with its TOML key.**

   `internal/config/userconfig.go`, inside `AppearanceConfig` (`:239+`). Use a pointer for a bool or int whose default is non-zero, so an explicit `false` or `0` survives; nil reads back as `Default`.

   ```go
   FlashOnBell *bool `toml:"flash_on_bell"` // Flash the pane border on BEL (default: true)
   ```

2. **Decide the default.**

   Leave it nil in `DefaultConfig()` (`:754`) and rely on the registry `Default`, or set it there. `TestOptionDefaultsMatchDefaultConfig` (`options_test.go:158`) compares the two. A whole new table also needs a `fillMissing*` call in `ParseUserConfig` (`userconfig.go:1613-1630`) and its name in the section list in `options_test.go:175`.

3. **Register the option.**

   `internal/config/options.go:124`, in `optionSpecs`, at its sorted position (the coverage test rejects unsorted or duplicate paths):

   ```go
   {
       Path: "appearance.flash_on_bell", Type: OptionBool, Section: "appearance",
       Description: "Flash the pane border when a program rings the bell",
       Default:     "true",
   },
   ```

   A field that must not be settable over the protocol (lists, maps, paths, grants) goes in `optionWalkSkips` with a reason instead (`options_test.go:14-30`).

4. **Map it into the runtime settings.**

   Add `FlashOnBell bool` to `Settings` (`internal/config/settings.go:26`), default it in `DefaultSettings()` (`:663`), and map it in `ApplyAppearanceConfig` (`userconfig.go:1795`), following the `WrapLists` pattern at `:2103-2106`:

   ```go
   // FlashOnBell defaults to true (nil means use default)
   if cfg.Appearance.FlashOnBell != nil {
       s.FlashOnBell = *cfg.Appearance.FlashOnBell
   }
   ```

   This one mapping is what makes startup, `set-config`, the settings row, the file-watcher reload, `tuios tape` and the `pkg/tuios` embed agree. Options outside `[appearance]` may instead be read live from `m.UserConfig`.

5. **Use it.**

   Read `m.Settings.FlashOnBell` in `internal/app`. If a change needs more than a repaint or retile (starting or stopping something), add a `case` to `SetConfig` (`internal/app/os_tape_executor.go:868-915`) or a special case in `setConfigFromRegistry` (`:947-955`). `applyAppearanceLive(true)` already marks dirty, retiles and syncs session state.

6. **Validate it, optionally.**

   `ValidateConfig` (`internal/config/validation.go:41`). Use `warnEnum` (`:223`) for a typo that falls back; return an error to make a reload refuse the file.

7. **Put it on the settings page.**

   One line in the right tab of `settingsCategories()` (`internal/app/settings.go:343`; tabs Appearance, Backgrounds, Sidebar, Selection, Dock, Behavior, Alerts, Startup, Screenshot, Saver, Spotlight, Advanced, Daemon, Hosts, Tape):

   ```go
   opt("appearance.flash_on_bell"),
   ```

   The label "Flash on bell" is derived from the last path segment. Override it in `settingLabels` (`settings_registry.go:45`); `settingInverted`, `settingPlaceholders`, `settingUnset` and `settingSteps` are the other cosmetics. A row that behaves differently (a picker, session state) is hand-written and declared `custom("appearance.flash_on_bell", m.myItem())` so coverage sees the path. To keep an option off the page, add it to `settingsUIExcluded` with a reason (`internal/app/settings_coverage_test.go:81`). The row becomes a palette "Settings" row and is found by settings search automatically.

8. **`get-config`, `set-config`, `list-options`: nothing to do.**

   They read the registry. `set-config` validates against a throwaway `DefaultConfig()`, records the value on the session, routes it to the attached TUI, which applies it and writes `config.toml`.

9. **Hot reload: nothing to do.**

   The watcher (`internal/config/watcher.go`, 200 ms debounce) reparses, validates and calls `ApplyReloadedConfig` (`internal/app/command_palette.go:47-76`), which reaches your mapping from step 4.

10. **Document it.**

    Add the key to `docs/CONFIGURATION.md` and the topic doc, and optionally a comment line in the generated config header (`internal/config/save.go:26+`). No test enforces the docs.

11. **Run the tests.**

    ```sh
    go test ./internal/config/ -run 'Option' -count=1
    go test ./internal/app/ -run 'Settings|Palette' -count=1
    go test ./internal/session/ -run Option -count=1
    ```
:::

### Verify it

```sh
go build -o /tmp/tuios ./cmd/tuios
/tmp/tuios list-options --section appearance | grep flash_on_bell
/tmp/tuios set-config appearance.flash_on_bell off
/tmp/tuios get-config appearance.flash_on_bell
```

Bool values accept `true/on/1/yes/enabled` and `false/off/0/no/disabled` (`options.go:1443`).

| Test | File:line | Fails when |
|---|---|---|
| `TestOptionRegistryCoversEveryScalarField` | `internal/config/options_test.go:36` | a scalar field has no entry, an entry names no field, or paths are unsorted or duplicated |
| `TestOptionDefaultsMatchDefaultConfig` | `:158` | `Default` differs from `DefaultConfig()` |
| `TestOptionSpecsAreWellFormed` | `:174` | empty description, unknown section, bad type, range on a non-int, default outside `Accepted` |
| `TestSettingsPanelReachesEveryOption` | `internal/app/settings_coverage_test.go:21` | an option has no row and no exclusion, two rows share a path, or an exclusion is stale |
| `TestPaletteReachesASettingByName` | `internal/app/command_palette_settings_test.go:18` | the palette cannot find the row |

::: warning
There is **no `tuios config validate`** command in v0.8.5. The `config` subcommands are `path`, `edit`, `reset` and `apply` (`cmd/tuios/main.go:322`). Validation happens when the file is loaded: errors make a reload refuse the file and warnings are shown at client start. To check a value without editing the file, use `tuios set-config`, which validates against the registry and refuses a bad value.
:::

### Gotchas

- `get-config` does not read `config.toml`. It returns the value set on this session through `set-config`, else the registry default, with `source` `session` or `default`. Only `daemon.window_size` falls back to the daemon's config.
- `set-config` with no client attached records the value on the session but does not save it; only an attached client writes the file.
- `daemon.log_level` applies to the daemon at once and is never saved.
- Bare `[appearance]` names work: `border_style` means `appearance.border_style`.
- A served (`tuios ssh`, web) or Learn session is `ConfigReadOnly`: changes apply to that session only.
- An enum whose built-in value is not `Accepted[0]` must set `Default`, or the cycler shows the wrong value.
- Shell commands and server-side paths are deliberately kept off the settings page for security (`settings_coverage_test.go:104-123`). Follow that for new options of that kind.
- `[keybindings]`, `[hooks]`, `[dock]` lists, `[hosts]`, `[tailscale]` and `[agents]` are file-plane config outside the registry.
- `ApplyAppearanceConfig` must run on the Bubble Tea goroutine, never from the watcher goroutine.

## How to add a sound cue and quiet hours

When an agent changes state, or mail or an Inbox item arrives, tuios alerts through four sinks: a desktop notification (OSC 9), a sound (an audio cue, a BEL, or both), a clickable dock message, and the `after-agent-state` hook. Replacing the two cue files, choosing which states alert and setting quiet hours is **config-only**. There is no plugin API for a third cue; adding one would need Go, and the source argues against it: "a pair has to be told apart by ear" (`internal/config/agent_alerts.go:96-102`). See [Agents](agents.md) for the states themselves.

### The keys

`[notifications.agent]` (`agent_alerts.go:18-76`, defaults in `ResolveAgentAlerts`, `:187-239`):

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | true | master switch for every sink, including `command` |
| `notify` | bool | true | OSC 9 desktop notification; never sent to a browser client |
| `sound` | bool | **false** | make the alert audible |
| `sound_mode` | `"audio"`, `"bell"`, `"both"` | `"audio"` | cue through a system player, a BEL (0x07), or both; unknown falls back to `audio` with a warning |
| `sound_cooldown_seconds` | int | 3 | shortest gap between two audio cues across all panes; not applied to the bell |
| `dock` | bool | true | clickable dock message that jumps to the pane |
| `command` | string | `""` | shorthand for one `after-agent-state` hook |
| `settle_seconds` | int | 2 | hold the alert, and drop it if the pane leaves the state; 0 alerts at once |
| `suppress_focused` | bool | true | skip the focused pane while the host terminal is focused |
| `quiet_hours` | `"HH:MM-HH:MM"` | `""` | local-time window that silences every sink |

`[notifications.agent.states]`: `needs_input` (true), `errored` (true), `done` (true), `idle` (false), `working` (false). A state not in the map never alerts.

`[notifications.agent.sounds]`: `needs_input` (the "attention" cue, used for `needs_input` and `errored`) and `done` (used for `done`, `idle` and anything else).

`[notifications.mail]` has `enabled`, `notify`, `sound`, `dock` and `between_agents`. Each key except `between_agents` follows the matching `[notifications.agent]` key while unset. Sound mode, cooldown, cue files and quiet hours **always** come from `[notifications.agent]`.

### Steps

::: howto
1. **Prepare the cue files as WAV.**

   The built-in cues are 16-bit mono PCM at 22050 Hz (`internal/sound/assets.go:5-9`). Use WAV: on Linux the probe list includes `aplay`, which does not decode compressed formats and, handed an MP3, "plays the file's bytes as raw samples, at full volume" (`players_unix.go:17-20`).

   ```sh
   mkdir -p ~/.config/tuios/sounds
   cp ping.wav soft.wav ~/.config/tuios/sounds/
   afplay ~/.config/tuios/sounds/ping.wav      # macOS; Linux: paplay ~/.config/tuios/sounds/ping.wav
   ```

2. **Turn sound on and point at the files.**

   Use **absolute paths**: there is no `~` expansion; the path goes straight to `os.Open` (`sound.go:203-210`).

   ```toml
   [notifications.agent]
   sound = true
   sound_mode = "both"              # chime plus terminal bell
   sound_cooldown_seconds = 5
   settle_seconds = 3
   suppress_focused = true

   [notifications.agent.sounds]
   needs_input = "/Users/me/.config/tuios/sounds/ping.wav"
   done        = "/Users/me/.config/tuios/sounds/soft.wav"
   ```

3. **Set quiet hours.**

   `HH:MM-HH:MM`, hours 0-23, minutes 0-59, start inclusive and end exclusive. A window that wraps midnight works. Equal start and end means an empty window.

   ```toml
   [notifications.agent]
   quiet_hours = "22:30-07:30"
   ```

   Or live:

   ```sh
   tuios set-config notifications.agent.sound true
   tuios set-config notifications.agent.quiet_hours "22:00-08:00"
   tuios get-config notifications.agent
   ```

4. **Choose which states alert, and quiet the mail.**

   ```toml
   [notifications.agent.states]
   needs_input = true
   errored = true
   done = true
   idle = false

   [notifications.mail]
   sound = false            # mail alerts silently; the other keys follow [notifications.agent]
   between_agents = false
   ```

5. **Trigger a real transition.**

   Run this in a pane that is not focused, or set `suppress_focused = false`, and expect a delay of `settle_seconds`:

   ```sh
   tuios set-agent-state needs_input -m test
   ```
:::

### Verify it

- Config warnings at client start report a bad `quiet_hours` (`...; ignored, so alerts are never silenced by the clock`), an unknown `sound_mode`, a negative cooldown or settle, and `between_agents` set while mail is off (`internal/config/validation.go:274-315`).
- tuios **never reports a playback failure**. Test the file with the player directly.
- Player probe order, resolved once per process: macOS `afplay`, `ffplay`, `mpv`; Linux/BSD `paplay`, `pw-play`, `aplay -q`, `ffplay`, `mpv`; Windows `powershell`/`pwsh` (path passed in `TUIOS_SOUND_PATH`, not argv), `ffplay`, `mpv`.
- Go tests: `internal/sound/sound_test.go`, `internal/config/agent_alerts*_test.go`, `internal/app/agent_alert_test.go`.

### Gotchas

- `sound` is off by default. `sound_mode = "bell"` in a terminal with the bell muted is silence.
- A cue file that cannot be opened silently falls back to the built-in cue. Before the first transition there is no feedback that sound works.
- After 3 consecutive failed plays, sound is off for the rest of the process. A machine with no player found is silenced at once. Nothing is printed.
- One cue plays at a time; a request that arrives while one is playing is **dropped**, not queued. Six simultaneous alerts make one sound.
- `TUIOS_NO_SOUND` set to anything non-empty silences the package regardless of config. Use it for CI and recordings.
- The sinks run **in the client**. Under `tuios ssh` and `tuios-web` the cue plays on the server, and the client warns at start that `sound_mode = "bell"` rings the client terminal instead. Under `tuios attach --host` the client is local, so the cue plays locally.
- Quiet hours use the local time zone of the process: the client's for the sinks, the daemon's for the hook. Quiet hours also suppress the daemon-side hook.
- The client re-resolves the policy on every transition, so cue and state edits apply without a restart. The daemon resolves its `after-agent-state` gating only at start.

### Changing the built-in cues (Go)

Edit the note table in `internal/sound/gencues.go` (build tag `ignore`), then regenerate from that directory. It rewrites `assets/done.wav` and `assets/needs-input.wav`, which are embedded with `//go:embed` (`assets.go:11-15`).

```sh
cd internal/sound && go run gencues.go
```

## How to add a lesson to the learn tour

The tour at https://tuios.dev/learn runs the **real** tuios compiled to WebAssembly (`cmd/tuios-wasm`) in Learn mode. Every pane runs a fake shell (`internal/webshell`). `internal/learn` wraps the app model and streams events to the web page, and **the page defines the lessons**: each step is a JavaScript object with a predicate over those events. Writing a step needs no Go. Extending the event or command contract needs Go.

::: warning
**The public lessons do not live in this repository.** The comment at `cmd/tuios-wasm/web/index.html:64-68` says "the docs site loads its tracks from data". The only track in the v0.8.5 tree is a five-step demo in `cmd/tuios-wasm/web/index.html:69-83`, used to try changes. Publishing a lesson on tuios.dev is a change to the docs-site repository, which this tree does not contain and which these findings could not inspect. Everything below is what the tuios repository itself supports.
:::

### The step shape

```js
// cmd/tuios-wasm/web/index.html:69-83
const steps = [
  { html: 'Press <kbd>n</kbd> to open a terminal window',
    done: (e) => e.type === 'window.open' },
  { html: 'Press <kbd>i</kbd> to type in it, then run <kbd>ls</kbd>',
    done: (e) => e.type === 'shell.command' && e.data.command === 'ls' && e.data.exitCode === 0 },
  { html: 'Tile them: <kbd>Ctrl+B</kbd> then <kbd>Space</kbd>',
    start: () => setTimeout(() => tuios.command('cascade'), 900),  // set the scene
    done: (e) => e.type === 'tiling' && e.data.to === true },
  { html: 'Run <kbd>claude</kbd>, and say <kbd>y</kbd> when it asks',
    done: (e) => e.type === 'agent' && e.data.to === 'done' },
  { html: 'Workspace 2: <kbd>Ctrl+B</kbd> <kbd>w</kbd> <kbd>2</kbd>',
    done: (e) => e.type === 'workspace' && e.data.to === 2 },
];
// runner: on every event, if steps[current].done(e) then current++, celebrate, startStep()
```

The contract (`cmd/tuios-wasm/README.md`, the authoritative reference):

- An event is `{type, data, windowId?, state?}`. For one key press, events arrive as `key`, then `action`, then the state changes.
- Event types: `ready`, `key`, `action`, `mode`, `prefix`, `window.open`, `window.close`, `window.focus`, `window.rename`, `window.minimize`, `window.zoom`, `window.move`, `window.float`, `workspace`, `tiling`, `layout`, `theme`, `setting`, `overlay.open`, `overlay.close`, `notification`, `agent`, `tape.start`, `tape.finish`, `shell.start`, `shell.command`, `shell.cwd`, `exit`.
- Commands, called as `tuios.command(name, ...stringArgs)`: `action`, `agent`, `cascade`, `celebrate`, `closeWindow`, `layout`, `mode`, `newWindow`, `notify`, `reset`, `tape`, `theme`, `tiling`, `type`, `workspace` (`internal/learn/commands.go:22`). An unknown command or a bad argument does nothing.
- State snapshot fields: `mode`, `workspace`, `workspacesUsed`, `tiling`, `layout`, `prefix`, `overlays`, `theme`, `focused`, `focusedTitle`, `zoomed`, `windows`, `minimized`, `totalWindows`, `windowList[]`, `tape`, `glyphs`, `borderStyle`, `cols`, `rows`.
- Design rule: "Every step has to change the screen visibly". If a step's key would change nothing, set the scene in `start`, as the `cascade` step does.
- Lesson props in the fake shell: `~/projects/hello` (a git repo with a pending change), `less` and `vim` viewers, a scripted `claude` agent (`working`, then `needs_input`/approval, then `done`), `tuios tape play demo.tape`, and toys such as `top`, `rain` and `neofetch`.

### Steps: write a track (no Go)

::: howto
1. **Build the wasm bundle and serve it.**

   ```sh
   cmd/tuios-wasm/build.sh out/
   node cmd/tuios-wasm/serve.mjs out/ 8765     # open http://127.0.0.1:8765
   ```

2. **Edit the `steps` array in `out/index.html`.**

   It is copied from `cmd/tuios-wasm/web/index.html`. Add one object per step, in the shape of the demo array above. Each `done(e)` must test an event in the contract, and each `start()` may call `tuios.command(...)` to set the scene, as the tiling step does with `cascade`. Take the key you name in `html` from the help overlay or `tuios keybinds explain`, not from memory.

3. **See which events your keystrokes produce.**

   `window.tuiosEvents` holds every event (`index.html:96-100`), and the page has a log. Match on what you see.

4. **Check what Learn mode disables.**

   Run `tuios.unavailable()` in the browser console. Sessions, screenshots, tape recording and the tape manager, agent mail and host clipboard paste are off; a step that relies on one can never complete.

5. **Run the headless check.**

   ```sh
   node cmd/tuios-wasm/smoke.mjs out/
   ```
:::

### Steps: extend the contract (Go)

::: howto
1. **Add a command.**

   Append the name to `Commands` (`internal/learn/commands.go:22`, alphabetised) and add a `case` to `RunCommand` (`commands.go:31+`). It runs on the program goroutine and must not return an error. Document it in the Commands table of `cmd/tuios-wasm/README.md`; `TestCommandsListMatchesRunCommand` (`internal/learn/learn_test.go:289`) checks both the `case` and a backticked mention in the README.

2. **Add an event.**

   Add `const EventX = "..."` in `internal/learn/learn.go:22-50`. For a state-derived event, add the field to `Snapshot`/`take` (`snapshot.go:69-170`), emit it in `diff` (`snapshot.go:248`) and add it to `Snapshot.ToMap` if lessons should see it. Document it in the README's Events table, add it to the list in `learn_test.go:307-313` (hand-maintained, so a missing event is not caught) and extend `TestEventContract` (`learn_test.go:185`).

3. **Restrict an action in Learn mode.**

   Add `action_name: "note"` to `learnUnavailable` (`internal/app/learn_mode.go:37`). `tuios.unavailable()` reports it.

4. **Test.**

   ```sh
   go test ./internal/webshell/ ./internal/learn/ -count=1
   cmd/tuios-wasm/build.sh out/ && node cmd/tuios-wasm/smoke.mjs out/
   ```
:::

### Gotchas

- A change to `internal/app` or `internal/input` can break the js build without breaking any native one. The `learn-web` workflow builds it on every pull request.
- `internal/learn` has no build tags, so the contract is testable natively. Only `cmd/tuios-wasm`, `internal/webshell` and `_js.go` files are browser-only.
- `window.move` fires once per window after the animation finishes, and never for a window that opened or closed in the same change.
- `shell.command` reports `exitCode: 127` for an unknown command.

## How to embed tuios in a Go program

`github.com/Gaurav-Gosain/tuios/pkg/tuios` embeds the whole window manager as a Bubble Tea v2 model. It is a thin facade (372 lines, `pkg/tuios/tuios.go`) over `internal/app.OS` and is Go-only. The embedded model is a **standalone, in-process** tuios: its PTYs are children of your process, and it has no daemon, sessions or detach. There is no public option to attach to a daemon, mark a browser client or make the settings page read-only. The other public packages are `pkg/applist` (launcher app discovery and frecency) and `pkg/fuzzy` (the fuzzy matcher). Upstream reference: [docs/LIBRARY.md](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/docs/LIBRARY.md).

### The API

| Symbol | Line | Notes |
|---|---|---|
| `type Model = app.OS` | 57 | a type alias, so every exported method of `*app.OS` is callable |
| `type Mode`, `WindowManagementMode`, `TerminalMode` | 60-68 | |
| `type Options struct{...}` | 71-123 | Theme, ShowKeys, Animations, ASCIIOnly, Workspaces, BorderStyle, DockbarPosition, HideWindowButtons, WindowButtonPosition, WindowButtonStyle, ScrollbackLines, Width, Height, SSHMode, UserConfig |
| `With*` options | 126-238 | `WithTheme`, `WithShowKeys`, `WithAnimations`, `WithASCIIOnly`, `WithWorkspaces`, `WithBorderStyle`, `WithDockbarPosition`, `WithHideWindowButtons`, `WithWindowButtonStyle`, `WithWindowButtonPosition`, `WithScrollbackLines`, `WithSize`, `WithSSHMode`, `WithUserConfig` |
| `DefaultOptions()` | 240 | `{Animations: true, Workspaces: 9, ScrollbackLines: 10000}` |
| `New(opts ...Option) *Model` | 250 | |
| `type PTY interface{ Width() int; Height() int }`, `NewForPTY` | 263-279 | takes methods; a struct with `Width`/`Height` *fields* (such as `sip.Pty`) does not satisfy it, so use `WithSize` |
| `ProgramOptions() []tea.ProgramOption` | 348 | FPS cap, no signal handler, mouse-motion filter |
| `FilterMouseMotion(model, msg)` | 355 | the `tea.WithFilter` that `ProgramOptions` installs |
| `var Config = struct{LoadUserConfig, DefaultConfig, GetConfigPath}` | 361-372 | re-exports from `internal/config` |

Methods on `*Model` (signatures verified in `internal/app`):

```js
AddWindow(name string, command ...string) *OS        // os_window.go:584
DeleteWindow(i int) *OS                              // os_window.go:830
FocusWindow(i int) *OS                               // os_window.go:317
GetFocusedWindow() *terminal.Window                  // os_window.go:1006 (internal type: usable, not nameable)
SwitchWorkspace(workspace int) error                 // os_tape_executor.go:489
MoveWindowToWorkspace(windowIndex, workspace int)    // workspace.go:225
ToggleTiling() error                                 // os_tape_executor.go:502
TileAllWindows()                                     // tiling.go:54
Cleanup()                                            // os.go:1811
Init() tea.Cmd; Update(tea.Msg) (tea.Model, tea.Cmd); View() tea.View
```

Because `Model` aliases `app.OS`, the whole tape `Executor` method set (`SplitVertical()`, `SetTheme(name)` and so on) is reachable too. None of it is documented as stable API.

New layers its configuration like the CLI: `config.LoadUserConfig()` (falling back to `DefaultConfig()` on error, unless `WithUserConfig` was given), then `ApplyAppearanceConfig`, then `ApplyOverrides` with your options as the outer layer (a zero value leaves the config's value), then `NewKeybindRegistry` and `app.NewOS`.

### Steps

::: howto
1. **Require the module.**

   The module requires Go 1.26.6 (`go.mod:3`) and Bubble Tea v2 (`charm.land/bubbletea/v2`).

   ```sh
   go mod init example.com/mywm
   go get github.com/Gaurav-Gosain/tuios@v0.8.5
   ```

2. **Wrap the model.**

   This program was built with `go build` against the v0.8.5 tree and compiles cleanly. It adds one key of its own (<kbd>Ctrl</kbd>+<kbd>q</kbd>) and delegates everything else.

   ```go
   package main

   import (
       "log"

       tea "charm.land/bubbletea/v2"
       "github.com/Gaurav-Gosain/tuios/pkg/tuios"
   )

   type wrapper struct{ t *tuios.Model }

   func (w *wrapper) Init() tea.Cmd { return w.t.Init() }

   func (w *wrapper) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
       if k, ok := msg.(tea.KeyPressMsg); ok && k.String() == "ctrl+q" {
           w.t.Cleanup()
           return w, tea.Quit
       }
       m, cmd := w.t.Update(msg)
       w.t = m.(*tuios.Model)
       return w, cmd
   }

   func (w *wrapper) View() tea.View { return w.t.View() } // tea.View, not string

   func main() {
       cfg := tuios.Config.DefaultConfig() // do not read ~/.config/tuios/config.toml
       cfg.Keybindings.LeaderKey = "ctrl+a"
       model := tuios.New(
           tuios.WithTheme("dracula"),
           tuios.WithAnimations(false),
           tuios.WithUserConfig(cfg),
       )
       p := tea.NewProgram(&wrapper{t: model}, tuios.ProgramOptions()...)
       if _, err := p.Run(); err != nil {
           log.Fatal(err)
       }
   }
   ```

3. **Serve it over the web or SSH, if you need to.**

   Build the `tea.Program` yourself and put **tuios's options last**, because both option lists carry a `tea.WithFilter` and the last one wins:

   ```go
   opts := append(bubbletea.MakeOptions(sess), tuios.ProgramOptions()...)
   ```

   `sip.Serve` and `bubbletea.Middleware` append their own options after yours, which silently drops the tuios mouse filter; use `ServeWithProgram` or `MiddlewareWithProgramHandler`. `WithSSHMode(true)` makes the model a `ClientSSH`: the settings page then does not write the operator's config file, and desktop actions do not run on the server.

4. **Call `Cleanup()` when you stop**, so the in-process PTYs are released.
:::

::: warning
**The custom-wrapper example in `docs/LIBRARY.md:336-367` does not compile.** It declares `func (m *MyApp) View() string` and returns `m.tuios.View()`, which is a `tea.View` in Bubble Tea v2. The compiler says: `*wrapper does not implement tea.Model (wrong type for method View) have View() string want View() tea.View`. Declare `View() tea.View`, as above. The doc's method list also omits that `SwitchWorkspace` and `ToggleTiling` return `error`.
:::

### Verify it

```sh
go build ./... && go vet ./...
./mywm
```

There are no tests in `pkg/tuios`, and nothing inside the repository imports it. A contributor who changes the facade should build an example like the one above.

### Gotchas

- By default `New()` reads the person's real `config.toml`, keybindings included. Pass `WithUserConfig(tuios.Config.DefaultConfig())` for deterministic behaviour.
- A model served over sip counts as a **local** client, so its settings page can write the operator's config file. The package comment admits "there is no option yet that marks it as a browser".
- `config.Global` is process-global. Several models in one process with different appearance options interfere.
- To control a *running* daemon from Go, `pkg/tuios` cannot help and `internal/session.VerbClient` is not importable. Speak the JSON verb protocol yourself: dial `$TUIOS_SOCKET` (or `$XDG_RUNTIME_DIR/tuios/tuios.sock`, or `/tmp/tuios-<uid>/tuios.sock`), write `{"id":1,"verb":"...","params":{...}}\n` and read one line.

## How to talk to tuios as a herdr client

herdr (github.com/herdrdev/herdr) is another terminal multiplexer for coding agents. tuios answers herdr's interfaces as a **compatibility server**, so agents and tools written for herdr work unchanged in a tuios pane. Using it is config-only (`[agents] herdr_protocol`), and a tool you write against herdr's API needs no tuios code. Changing which methods tuios answers is Go, in `internal/session/herdr_*.go` and `internal/herdrcli`. tuios targets herdr **0.9.3**, protocol **22** (`internal/session/herdr_api.go:56-59`) and reports its version as `0.9.3+tuios`.

There are three surfaces:

1. **Pane state protocol (input).** Agents such as Crush and Kiro CLI, and herdr's own hook scripts, report state to `$HERDR_SOCKET_PATH`. tuios turns each report into `set-agent-state` with source `report`.
2. **herdr socket API.** Tools built for herdr (bar widgets, editor bridges, Collie's herdr adapter) call methods such as `session.snapshot`, `pane.split` and `events.subscribe`.
3. **herdr CLI.** `$HERDR_BIN_PATH` is a link named `herdr` to the tuios binary. Run under that name, tuios parses herdr 0.9.3's command line.

### Socket path and environment

The socket is the daemon socket plus `.herdr` (`HerdrSocketPath`, `herdr_compat.go:96-98`). A pane gets (`internal/session/manager.go:200-209`):

```text
HERDR_ENV=1
HERDR_SOCKET_PATH=<daemon socket>.herdr        # e.g. $XDG_RUNTIME_DIR/tuios/tuios.sock.herdr
HERDR_PANE_ID=w<12 hex of session id>:p<12 hex of window id>
HERDR_TAB_ID=w<...>:t<workspace number>        # only when workspace > 0
HERDR_WORKSPACE_ID=w<...>
HERDR_BIN_PATH=$XDG_RUNTIME_DIR/tuios/herdr/bin/herdr   # or /tmp/tuios-<uid>/herdr/bin/herdr
```

tuios never listens on herdr's own socket path, and a pane never inherits an outer herdr's `HERDR_*` variables.

| herdr | tuios | Id form |
|---|---|---|
| workspace | session | `w` + first 12 hex of the session id |
| tab | workspace (numbered slot) | `<ws id>:t<number>` |
| pane | window | `<ws id>:p` + first 12 hex of the window id; the window id or an 8+ hex prefix is also accepted |

| tuios agent state | herdr `agent_status` |
|---|---|
| `working` | `working` |
| `needs_input` | `blocked` |
| `idle` | `idle` |
| `done`, `errored` | `done` |
| `unknown`, none | `unknown` |

### What is answered

Pane reports (`herdrReportMethods`, `herdr_compat.go:409-412`):

| Method | tuios effect |
|---|---|
| `pane.report_agent` `state: working` | `working` |
| `pane.report_agent` `state: blocked` | `needs_input` with the message; for Crush, a message starting `Permission` (or none) is kind `approval`, anything else `question` |
| `pane.report_agent` `state: idle` | `done` if the pane was `working` or `needs_input`, else `idle` |
| `pane.report_agent` `state: unknown` | nothing |
| `pane.report_agent_session` | `set-agent-session` |
| `pane.release_agent` | `none` |
| `pane.report_metadata` | agent metadata under source `herdr:<source>`; a `null` token clears the key |
| `notification.show` | a `notification` event from the caller's pane |

API methods (`herdrMethods`, `herdr_api.go:237-291`): `ping`, `session.snapshot`; `workspace.{list,get,create,rename,close,focus}`; `tab.{list,get,create,rename,focus,move,close}`; `pane.{list,get,current,layout,read,send_text,send_keys,send_input,rename,focus,split,close,wait_for_output,process_info,neighbor,edges,focus_direction,swap,zoom}`; `agent.{list,get,read,send_keys,focus,prompt,wait,start}`; `worktree.{list,create,open,remove}`; `events.wait`; and `events.subscribe`, which the transport handles. `docs/AGENT_STATE.md:559-620` maps each to the tuios verb it runs.

### What is refused

These return `unsupported` (`herdrUnsupported`, `herdr_api.go:297-316`): `server.stop`, `server.live_handoff`, `server.reload_config`, `server.ssh_agent.register`, `server.agent_manifests`, `server.reload_agent_manifests`, `product_announcement.dismiss`, `release_notes.dismiss`, `command.invoke`, `client.window_title.set`, `client.window_title.clear`, `client_shell.surface.set`, `workspace.move`, `workspace.move_block`, `workspace.report_metadata`, `agent.explain`, `agent.rename`, `agent.view.set`, `agent.view.clear`, `pane.move`, `layout.export`, `layout.apply`, `layout.set_split_ratio`, `pane.resize`, `pane.scroll`, `pane.clear`, `pane.edit_scrollback`, `pane.selection.read`, `pane.copy_motion`, `pane.copy_search`, `pane.input.set`, `pane.link.activate`, `pane.link.resolve`, `pane.clear_agent_authority`, `popup.close`, `integration.{list,install,uninstall}`, `plugin.{link,list,unlink,enable,disable}`, `plugin.action.{list,invoke}`, `plugin.log.list`, `plugin.pane.{open,focus,close}`.

Also refused: `env` in any create and `path` in `worktree.create`; the `pane.scroll_changed` and `pane.output_matched` subscriptions; on the CLI, `status`, `config`, `session`, `terminal`, `machine`, `channel`, `update`, `completion`, `plugin`, `integration`, `api schema`, `agent attach` and `server stop` (exit 1, `unsupported`). tuios **does not host herdr plugins**: it does not read `herdr-plugin.toml`, so `[[actions]]`, `[[panes]]`, `[[events]]` and `[[startup]]` do nothing. It does not serve herdr's terminal protocol (`terminal.attach`). A method herdr does not have returns `invalid_request`; retired `pane.graphics.*` methods return `unknown_method`.

### Steps

::: howto
1. **Choose who gets herdr's environment.**

   ```toml
   [agents]
   herdr_protocol = "always"   # "always" (default) | "agents" | "off"
   ```

   `always`: every pane, so a Crush started from a shell prompt reports its state. `agents`: only panes whose argv starts `crush` or `kiro-cli` directly; use it to run a real `herdr` nested in tuios. `off`: no pane. Empty or unknown values mean `always`.

2. **Call the socket: one JSON line per connection.**

   The request is at most 1 MiB, `{"id":"<string>","method":"...","params":{...}}`, with a **string** `id`. The reply is one line and the connection closes. From inside a tuios pane:

   ```sh
   printf '{"id":"1","method":"ping","params":{}}\n' | nc -U "$HERDR_SOCKET_PATH"
   # {"id":"1","result":{"type":"pong","version":"0.9.3+tuios","protocol":22,"server":"tuios"}}
   ```

3. **Report state the way Crush does.**

   ```sh
   printf '{"id":"2","method":"pane.report_agent","params":{"pane_id":"%s","source":"my-agent","agent":"my-agent","state":"blocked","message":"approve rm?","seq":%s}}\n' \
     "$HERDR_PANE_ID" "$(date +%s%N)" | nc -U "$HERDR_SOCKET_PATH"
   ```

   Each `source` keeps a seq high-water mark per pane, so a stale `seq` is dropped silently. (`%N` is a GNU `date` extension; on macOS use another monotonic counter.)

4. **Or use the herdr command line.**

   Call `"$HERDR_BIN_PATH"` explicitly; it is deliberately not on `PATH`, so a real herdr there still runs as herdr.

   ```sh
   "$HERDR_BIN_PATH" --version                     # herdr 0.9.3+tuios
   "$HERDR_BIN_PATH" pane split --pane "$HERDR_PANE_ID" --direction right --focus
   "$HERDR_BIN_PATH" pane report-agent "$HERDR_PANE_ID" --source my-agent --agent my-agent --state working --seq 1
   "$HERDR_BIN_PATH" notification show "Build done" --body "All tests pass"
   ```

   The CLI exits 0 with a JSON line on stdout, 1 with the error line on stderr, or 2 for a usage error.

5. **From outside tuios, point a herdr tool at the socket.**

   ```sh
   export HERDR_SOCKET_PATH="$XDG_RUNTIME_DIR/tuios/tuios.sock.herdr"
   ```

   A caller outside every pane has your own authority.
:::

### Verify it

```sh
tuios get-agent-state -w <pane>        # after a report
tuios subscribe                        # watch the agent-state events
"$HERDR_BIN_PATH" pane get --pane "$HERDR_PANE_ID"
```

### Authority and limits

- The daemon places the caller by kernel peer pid, its ancestors, its tty, and finally `TUIOS_PANE_ID`. Each method runs the equivalent tuios verb with that pane's grants: reads need `read`, typing needs `write` (plus `respond` to type into a prompt), structural changes need `admin`, `agent.start` needs `fan`. A refused call returns `forbidden`. Pane reports may speak only for the caller's own pane.
- Read and write each have a 2 s deadline. Waits (`pane.wait_for_output`, `agent.wait`, `events.wait`, `agent.prompt` with `wait`) clear it and accept `timeout_ms` up to 24 h.
- Per calling process: 64 connections and 8 event streams, then `rate_limited`. `notification.show` and `pane.report_metadata` allow a burst of 20, then 5 per second.

### Gotchas

- Under the default `always`, a real `herdr` refuses to start in a tuios pane because it reads `HERDR_ENV=1` as "inside herdr". Use `herdr_protocol = "agents"`, or herdr's `experimental.allow_nested`.
- `pane.send_text` and `pane.send_input` are sent as a **paste**: control characters are removed and bracketed paste is used when the pane has it on.
- `splits` in a layout is always empty (tuios has no split tree). With no attached client there is no layout and there are no neighbours, and `pane.split` creates a new window on the same workspace (as it does with `cwd`).
- On Windows, or wherever the link cannot be created, `HERDR_BIN_PATH` is the tuios binary itself, and only `pane` and `notification` work.
- A slow `events.subscribe` reader receives `events_lost` and the stream closes; read `session.snapshot` again and resubscribe.
- For your own scripts, prefer native verbs (`set-agent-state`, `wait-for`). The herdr surface exists for tools that already speak herdr.

### Answering one more herdr method (Go)

::: howto
1. **Write the handler** in `internal/session/herdr_api.go`, calling the tuios verb that does the work through `d.herdrVerb(cs, verb, args, failCode)` (`:398`) so the grant checks match.

   ```go
   // signature shape from herdr_api.go; pane.clear is one of the methods herdrUnsupported lists today
   func (d *Daemon) herdrPaneClear(cs *connState, in *herdrIn) (*herdrResult, *herdrError)
   ```

2. **List it** in `herdrMethods` (`:237-291`) with its `required` params, and remove it from `herdrUnsupported`.

3. **Add params fields** to `herdrIn`, and the CLI subcommand in `internal/herdrcli` (`parse.go`, `pane.go` or `groups.go`) flag for flag as herdr's `src/cli` does.

4. **Document and test.** Update the method tables in `docs/AGENT_STATE.md` and `skills/tuios/herdr.md`, and run the conformance replay.

   ```sh
   go test ./internal/session/ -run Herdr -count=1
   go test ./internal/herdrcli/ -count=1
   ```

   To track a new herdr release, diff herdr's `src/api/schema` against v0.9.3, update methods, fields and events, bump `herdrTargetVersion` and `herdrTargetProtocol`, and refresh `internal/session/testdata/herdr/collie_requests.json`.
:::

## How to add another machine (hosts)

`[hosts]` names other machines. The daemon keeps **one ssh link** to each and runs `tuios stdio-proxy` on the far side. Through those links, sessions, panes, agents, mail, the stash and the Inbox reach across machines (`-s HOST:SESSION`, `tuios attach --host`, `new-window --host`, `fan --host`, `ls --all-hosts`). The same table, read on the receiving machine, is the **link policy**: what a linking-in machine may do there. This is config-only. Machines are never discovered automatically; Tailscale and ssh_config aliases only offer candidate addresses. [Sessions](sessions.md) covers using remote sessions.

### The schema

`[hosts.NAME]` (`HostConfig`, `internal/config/hosts.go:31-72`):

| Key | Type | Meaning |
|---|---|---|
| `addr` | string | anything ssh accepts, including an ssh_config alias; **without it nothing is dialled**, and the entry only sets policy |
| `connect_timeout` | int seconds | one dial's timeout, also passed to ssh as ConnectTimeout; 0 means 10 s |
| `command` | string | the tuios binary on the host; empty searches `PATH`, the known install paths, then a login shell |
| `ssh_options` | []string | extra ssh arguments before the address, e.g. `["-J","bastion"]` |
| `repos_root` | string | where checkouts live, as the host reads it; used by `fan --host`, `worktree new --host`, `start-agent -s HOST:...` |
| `allow` | []string | **inbound policy**: `list`, `mail`, `open`, `write`, `respond`; nil inherits, `[]` allows nothing |
| `hold_mail` | bool | hold this machine's mail in the Inbox until the person passes it on |
| `hosted_grace` | Go duration | how long a pane run here for that machine outlives a dropped link; `"0"` ends it with the link; default 10m, max 24h |

Policy resolution: the built-in default (`list, mail, open, write`; `respond` is opt-in), then `[hosts."*"]`, then `[hosts.PEER]`; an unset field inherits from the level before. The capabilities: `list` (reads, captures, agent state, the Inbox, waits, events), `mail` (mail and the stash), `open` (start sessions, windows, hosted panes, worktrees, fans), `write` (typing, closing and moving windows, options, layouts, names, agent reports), `respond` (prompts, held approvals, dismissing Inbox items).

### Steps

::: howto
1. **Make plain ssh work non-interactively.**

   Links use BatchMode, so they never prompt for a password or a host key. Accept the host key once by hand.

   ```sh
   ssh gaurav@buildbox true
   ```

2. **Add the host from a terminal outside tuios.**

   ```sh
   tuios hosts add build gaurav@buildbox --repos-root '~/src'
   tuios hosts add lab lab-01 --ssh-option -J --ssh-option bastion   # behind a jump host
   tuios hosts add gpu --tailnet                                      # address from your tailnet
   ```

   `hosts add` also takes `--command` and `--connect-timeout`. It writes the TOML and sends `apply-config` with `{"host": NAME}`, so it takes effect at once **when run outside every pane**. The equivalent TOML:

   ```toml
   [hosts.build]
   addr = "gaurav@buildbox"
   connect_timeout = 5
   repos_root = "~/src"
   ```

3. **On the other machine, say what this one may do there.**

   In buildbox's own `config.toml`:

   ```toml
   [hosts.laptop]
   allow = ["list", "mail", "open", "write"]
   hold_mail = true
   hosted_grace = "10m"

   [hosts."*"]
   allow = ["list", "mail"]
   ```

   The peer name is the hostname the other machine reports, unless its ssh key is pinned with a forced command in `authorized_keys`. Only a pinned name is a security boundary:

   ```text
   command="tuios stdio-proxy --as laptop",restrict ssh-ed25519 AAAA...
   ```

4. **Test and use it.**

   ```sh
   tuios hosts test build      # runs ssh itself; prints the remote tuios path or ssh's error
   tuios hosts                 # up | no_daemon | no_tuios | unreachable | reconnecting | incompatible | connecting
   tuios ls --all-hosts
   tuios attach --host build api
   tuios capture-pane -w build:api:0
   tuios new-window deploy --host build
   ```
:::

::: warning
**A file edit applies only changes that narrow access.** The daemon watches `config.toml`, but a **new** host, a changed address or a widened link policy *waits*: the daemon logs `host X changed in config.toml. The change applies after tuios config apply from outside tuios, or a daemon restart` and opens an Inbox notice. A process in a pane runs as you and can write the file, so widening must come from the person. Inside a pane, `apply-config` is `scopeDeny`, and `tuios hosts add` prints that the change applies after `tuios config apply` from a terminal outside tuios. After a hand edit that adds a host, run `tuios config apply` outside tuios. A removed host is dropped at once.
:::

### Verify it

- `tuios hosts test NAME` reports what ssh said, or every place it looked for tuios.
- `tuios hosts --json` shows link state, the remote version and the protocol.
- Config warnings report an unknown capability in `allow` (`'<x>' is not a capability (allowed: ...); it is ignored`) and an unreadable or out-of-range `hosted_grace`.
- A host name must match `^[A-Za-z0-9][A-Za-z0-9._-]*$`; a colon would make `host:target` ambiguous.

### Gotchas

- `incompatible` means the far side speaks a control protocol this build does not serve. Upgrade one side, or use `tuios attach --host X --ssh`, which nests the remote client.
- The word before the first colon in `-s`/`-w` is read as a host name. A local session whose name contains a colon must be written `local:NAME`. An unknown host returns `unknown_host` and is never guessed.
- Everything that comes back from a host (captures, mail, `--json` with `"untrusted": true`) is untrusted data.
- Under `tuios attach --host` the client runs locally, so sounds play locally and your theme and keys apply.
- Mail to a host whose link is down is queued and delivered in order when the link returns. Do not resend it.
- `[tailscale]` changes only *suggestions* for `hosts add --tailnet` and `hosts tailnet`; it never adds hosts.

## Contributor conventions

This section collects how the tuios repository expects changes to be built, tested and submitted. The in-tree orientation document is `AGENTS.md` at the repo root (package map, build and test commands, test infrastructure); `docs/CONTRIBUTING.md` points at the full guide on https://tuios.dev/docs/contributing. `AGENTS.md` is for agents working **on** the code; `tuios --skill` is for agents running **inside** a pane.

### Build

Go 1.26+ is the only requirement for the pure-Go backend. There is **no Makefile, justfile or Taskfile**; build with plain `go`:

```sh
go build -o tuios ./cmd/tuios
go build -o tuios-web ./cmd/tuios-web       # the web server is a separate binary
go run ./cmd/tuios --debug
./scripts/install.sh                        # build and install, pure Go emulator
./scripts/install.sh ghostty                # libghostty-vt backend; needs zig (docs/ghostty-vt.md)
```

`scripts/` holds `binary-size.sh`, `deploy-dev.sh`, `ghostty-lib.sh`, `install.sh`, `star-history.sh` and `zigcc`. Nix (`nix develop`, `nix build`, `nix run`) and Docker (`docker build -t tuios .`) also work. The browser build is `cmd/tuios-wasm/build.sh out/`.

### Test

`AGENTS.md:42-47`, verbatim:

```sh
# Leave the machine usable. The maintainer works on this box while the suite
# runs, and an uncapped build or test run takes every core. taskset confines the
# whole process tree to half the cores, and the affinity is inherited, so it
# also holds for the daemons and shells the e2e suite spawns. GOMAXPROCS and
# `go test -p` do not, because they only bind the Go runtime.
nice -n 10 taskset -c 0-7 go test ./... -timeout 20m
```

::: note
`taskset` is Linux-only (util-linux). macOS has no equivalent, and the repository offers no macOS variant; `nice -n 10 go test ./... -timeout 20m` is the closest you can get there.
:::

| Purpose | Command |
|---|---|
| whole suite | `go test ./...` |
| one package | `go test ./internal/config/...` |
| race | `go test -race ./...` |
| CI's exact form | `go test ./... -count=1 -timeout 20m` |
| CI race job | `go test ./... -race -count=1 -timeout 80m` |
| ghostty backend | `PKG_CONFIG_PATH="$PWD/.ghostty-vt/native/pkgconfig" go test -tags ghostty -count=1 -short ./internal/vt/ ./internal/session/ ./internal/terminal/ ./internal/app/ ./internal/input/ ./cmd/tuios/` |
| E2E | `go build -o /tmp/tuios ./cmd/tuios && cd e2e/tui && TUIOS_E2E=1 TUIOS_E2E_BIN=/tmp/tuios go test -count=1 -timeout 40m .` |
| perf budgets | `go test -bench=. ./internal/app/...` |
| VT conformance (fast) | `go test -short ./internal/vt/` |
| fuzz campaign | `go test ./internal/vt/ -run XXX -fuzz FuzzEmulatorScript -fuzztime 10m` |
| list fuzz targets | `go test -list 'Fuzz' ./...` |
| differential vs tmux | `go test -tags differential ./internal/vt/ -run TestDifferential -v` |
| Learn Go side | `go test ./internal/webshell/ ./internal/learn/` |
| tape check | `go run ./cmd/tuios tape validate examples/demo.tape` |

- `-count=1` is deliberate: "the test cache replays a pass across a change the cache key does not see".
- `e2e/tui` is its **own Go module**. It skips unless `TUIOS_E2E` is set and builds the binary itself if `TUIOS_E2E_BIN` is unset.
- `go build -tags ghostty ./...` compiles the ghostty backend but runs none of its tests.

### Testing philosophy

`AGENTS.md:284-293` says: "Never write unit tests after you write code." It "highly prefer[s] E2E tests as the sole testing mechanism", ending in "a verifiable and repeatable artifact". A unit test is kept only if it catches a real bug that E2E misses, and only of these kinds: VT conformance, fuzz, wire compatibility, security boundaries, deterministic race regressions, perf budgets. Fuzz findings become regressions under `internal/vt/testdata/vtgen-repros/` or `internal/app/testdata/fuzz-repros/`.

The repository nonetheless ships many structural coverage tests (`internal/input/reachability_test.go`, `internal/app/settings_coverage_test.go`, `cmd/tuios/skill_test.go` and the verb side tables), and every how-to in this chapter trips some of them. Treat them as wiring guards that a new extension must satisfy, not as an invitation to add more unit tests.

### Lint

- **golangci-lint v2**, configured in `.golangci.yml` and pinned in CI to v2.14.0 with `--timeout 20m`. Locally: `golangci-lint run ./...`. It runs the `standard` set (errcheck, govet, ineffassign, staticcheck, unused) plus `gosec` limited to the file-permission rules; the formatter is `gofmt`. Policy: "A finding that is wrong for one line gets a //nolint with its reason on that line, not a new rule here."
- CI also runs `govulncheck` and `go vet ./...` cross-compiled for darwin, windows, freebsd and openbsd, because "a test file that uses a unix-only syscall without a build tag breaks these and nothing else".
- The test workflow enforces an empty `gofmt -l .`, `go mod tidy -diff` in **both** `.` and `e2e/tui`, `go vet ./...` and `go build ./...`.
- Source lint runs as tests in `internal/lint`: `colors_test.go` rejects hard-coded colours in `internal/app` and `internal/overlay` unless the line carries `//tuios:allow-color <reason>`.

::: note
`.markdownlint.json` exists and only allows the inline HTML elements `p`, `img` and `kbd` (rule MD033). **No workflow, script or nix file runs markdownlint**, so it is an editor convention, not a CI gate.
:::

### Code conventions

- `go fmt` before committing; a package doc comment on every package; godoc on exported identifiers.
- Wrap errors with `fmt.Errorf("failed to X: %w", err)`; log non-fatal problems with `log.Printf("Warning: ...")`; return early.
- Colours come from `theme.UI()`, `theme.GroundUI()` or a named token; blend with `overlay.MixColors` and measure with `overlay.Readable`.
- Bubble Tea v2: `tea.KeyPressMsg`, not `tea.KeyMsg`. Charm modules are `charm.land/*`, not `github.com/charmbracelet/*`.

### Pull requests

- Conventional commit prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`. Keep commits focused.
- The PR template (`.github/PULL_REQUEST_TEMPLATE/pull_request_template.md`) requires, for each added test, a **negative control**: a pasted failure from a deliberately broken build. "The control deletes the call site, not the function": cut the `case`, the `Register`, the route or the gate line. "Every negative test has its positive half." Fill in `Wiring cut: <file:line, what you removed>` and `Test that failed: <name, message>`. `e2e/tui/NEGATIVE_CONTROLS.md` records such runs, motivated by a feature that "registered 18 actions that no key reached. Its eight controls all passed, because all eight cut the handler and the fault was the switch above it."
- The checklist also asks for docs updates, cross-platform testing and a title such as `[BUG]` or `[FEATURE]`.
- Manual UI checklist (`AGENTS.md:413-420`): create and close windows, switch workspaces (<kbd>Alt</kbd>+<kbd>1</kbd>-<kbd>9</kbd>), tiling (<kbd>t</kbd>), copy mode (<kbd>Ctrl</kbd>+<kbd>b</kbd> <kbd>[</kbd>), keybindings, rendering, mouse drag and resize.
- Report security issues through `SECURITY.md`, not the issue tracker.
- Releases are cut by GoReleaser on `v*.*.*` tags for Linux, macOS, Windows and FreeBSD, plus AUR, Homebrew and Docker.
