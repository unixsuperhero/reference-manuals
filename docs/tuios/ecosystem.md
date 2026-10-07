---
title: "TUIOS: Ecosystem and Plugin Directory"
template: tuios-manual
manual: tuios
chapter: 10
summary: A source-checked directory of everything found on the public internet that plugs into, extends, integrates with or packages tuios, with links, as of 7 October 2026.
tags:
  - tuios
  - ecosystem
  - plugins
  - links
---

tuios has no plugin registry and no plugin host of its own. What it has instead are several open edges: dock components are shell commands, themes are JSON files, coding-agent harnesses report through hooks tuios writes for them, the daemon speaks a JSON protocol that other programs can drive, it emulates the herdr socket so herdr tools work unchanged, and it ships a tmux shim. The ecosystem therefore lives in other people's repositories, dotfiles and package feeds rather than in one place. This chapter is that place, as of **7 October 2026** against tuios **v0.8.5**.

Every entry was checked by fetching the page, by a GitHub, npm or package-registry API call, or by GitHub code search; the few that were only seen in search results are marked with a dagger (†). "n/l" means no licence was visible. "Updated" is the repository's last push unless noted. Nothing here is endorsed by the tuios project unless the entry says it is first-party or linked from the project's own docs. Treat third-party scripts as untrusted until you have read them.

::: note
How this list was built: every `.md`, `.nix`, `.toml` and `.sh` file in the tuios repository at tag `v0.8.5` and the hosted docs' `llms-full.txt` were scanned for outbound links; GitHub repository, code, issue and pull-request searches were run for `tuios` and for strings only a tuios integration would contain (`[dock.custom`, `tuios set-agent-state`, `tuios-agent-state`, `TUIOS_PANE_ID`, `tuios.sock.herdr`); the AUR, Homebrew, Repology, GHCR, Chocolatey, conda and npm registries were queried; and web search was run in both standard and extended modes. The last section lists what came up empty so you know the search was done.
:::

## Quick map

| If you want to | Look at |
| --- | --- |
| Put something of your own in the dock | [Dock components](#dock-components), then [How To: add a dock component](howto-extending.md#how-to-add-a-dock-component) |
| Match tuios to your terminal colours | [Themes](#themes) and `tuios import-theme` in [Configuration](configuration.md#themes) |
| Make a coding agent show its state in the rail | [Harness integrations](#coding-agent-harness-integrations) and [Agents](agents.md#harness-integrations) |
| Let an agent drive tuios with tools | [MCP](#mcp) |
| Use a herdr tool, phone app or Neovim plugin | [herdr compatibility](#herdr-compatibility-and-the-herdr-ecosystem) and [Editor plugins](#editor-plugins) |
| Run a tmux-only tool inside tuios | [tmux shim](#tmux-shim) |
| Install on a new machine | [Packaging](#packaging) |
| See what others built on the protocol | [Companion tools](#companion-tools-and-related-projects) |

## Dock components

A dock component is a `[dock.custom.<name>]` table in `config.toml` with a `command`, a `refresh` policy (`once`, `push`, an interval such as `"5s"`, or `event:<name>`), an optional `on-click`, and a `max-width`; it is placed in a region with `custom/<name>`. The complete contract and a worked recipe are in [How To: add a dock component](howto-extending.md#how-to-add-a-dock-component).

| Name | What it does | How it relates to tuios | Author · licence · updated |
| --- | --- | --- | --- |
| [Official dock examples](https://github.com/Gaurav-Gosain/tuios/tree/v0.8.5/examples/dock) | `agents.sh`, `battery.sh`, `git-branch.sh`, `inbox.sh`, `kube-context.sh`, a sample `dock.toml` and the README that is the contract | First-party reference components | Gaurav Gosain · MIT · v0.8.5 |
| [jack06215 powerline dock](https://github.com/jack06215/dotfiles/blob/main/dot_config/tuios/dock/executable_powerline.sh) | Runs tmux-powerline segments and rewrites tmux `#[fg=...]` markup into SGR escapes for a dock cell | Wired as `[dock.custom.left]` and `[dock.custom.right]` with `refresh = "5s"` and `max-width = 80` in the same repo's `config.toml`, so the dock shows the same bar as tmux | jack06215 · n/l · 2026-10-06 |
| [utena dock cell](https://github.com/eleonorayaya/utena) | Workspace manager for tuios whose tuios side adds a `custom/utena` cell that runs `utena status-line` | Dock component plus popups and an `after-attach` hook (see [Companion tools](#companion-tools-and-related-projects)) | eleonorayaya · n/l · 2026-10-04 |
| [Whimski toggle-chrome](https://github.com/Whimski/dotfiles/blob/main/.config/tuios/toggle-chrome.sh) | Toggles the dock between hidden and top, and toggles shared borders, through `tuios get-config` and `tuios set-config` | A dock helper rather than a component; the repo's `config.toml` carries commented `[dock.custom.branch]` examples | Whimski · n/l · 2026-10-05 |

Other public dotfiles with a tuios `config.toml` that sets `dock` options (ordinary configuration, not reusable components): hugotown, jemag, JustBarnt, link1183, LizardLiang, MateusDallIgna, RedEye-Developers, samyankc and explesy, each at `tuios/config.toml` inside the user's `dotfiles` repository on GitHub.

## Themes

tuios bundles 342 themes from the bubbletint palette library. A custom theme is a JSON file in `~/.config/tuios/themes/` with `id`, `display_name`, `fg`, `bg`, `cursor`, the eight ANSI colours and their `bright_*` variants, and `tuios import-theme` converts kitty, Ghostty, Alacritty and WezTerm schemes. The schema is in [Configuration](configuration.md#themes); writing one is in [How To](howto-extending.md#how-to-write-a-theme).

| Name | What it does | How it relates to tuios | Author · licence · updated |
| --- | --- | --- | --- |
| [bubbletint](https://github.com/lrstanley/bubbletint) | Go library of terminal colour palettes | The upstream source of the built-in themes, credited on tuios.dev | lrstanley · MIT · 2026-10-01 |
| [Stylix target for tuios](https://github.com/arunoruto/flake/blob/main/modules/home-manager/theming/stylix/targets/tuios/hm.nix) | A Stylix `mkTarget` that generates a tuios theme from base16 colours | Third-party; upstream Stylix has no tuios target. Needs that flake's own `programs.tuios` Home Manager module | arunoruto · MIT · 2026-10-06 |
| [swamp-extensions themes](https://github.com/SvenDowideit/swamp-extensions/tree/main/extensions/models/tuios/themes) | `borland_modern_blue.json`, `swamp_club.json` and a `tuios-theme.yaml` model | Part of the `@svendowideit/tuios` swamp extension (see [Packaging](#packaging)) | Sven Dowideit · n/l · 2026-10-07 |
| [JustBarnt everforest](https://github.com/JustBarnt/dotfiles/blob/main/tuios/themes/everforest.json) | Everforest in tuios JSON | A custom theme file | JustBarnt · n/l · 2026-10-06 |
| [adamcstephens moonfly](https://github.com/adamcstephens/dotfiles/blob/main/apps/tuios/themes/moonfly.json) | Moonfly in tuios JSON, with a Nix wrapper in `apps/tuios/default.nix` | A custom theme file | adamcstephens · Unlicense · 2026-10-06 |
| [ColeJJ obsidian](https://github.com/ColeJJ/nvim/blob/main/colors/tuios-custom-obsidian.json) | A custom "obsidian" theme in tuios JSON | A custom theme file | ColeJJ · n/l · 2026-10-05 |

No standalone theme-pack repository for tuios exists yet.

## Coding-agent harness integrations

`tuios integration install [harness...]` writes managed hooks or plugins into each harness's own configuration. Twelve harnesses report full state (claude-code, codex, copilot, cursor-agent, gemini-cli, opencode, kilo, amp, kimi, pi, omp, qwen); seven report the session only (antigravity, crush, devin, droid, grok, hermes, qoder). The plugin sources live in the tuios tree under `internal/integration/assets/` and `integrations/claude-code/`. The mechanics are in [Agents](agents.md#harness-integrations); adding a harness is in [How To](howto-extending.md#how-to-add-a-harness-integration).

### Upstream hook and plugin mechanisms tuios targets

These are the pages the tuios docs cite for each harness, and what `integration install` writes.

| Harness | Upstream mechanism | What tuios installs |
| --- | --- | --- |
| Claude Code | [hooks](https://code.claude.com/docs/en/hooks) | `hooks` entries in `~/.claude/settings.json` |
| Codex | [hooks](https://developers.openai.com/codex/hooks) | `~/.codex/hooks.json` |
| Gemini CLI | [hooks reference](https://geminicli.com/docs/hooks/reference/) | `hooks` in `~/.gemini/settings.json` |
| opencode | [plugins](https://opencode.ai/docs/plugins/) | `plugins/tuios-agent-state.js` in `~/.config/opencode` |
| Kilo | opencode's plugin API, which Kilo forks | `plugin/tuios-agent-state.js` in `~/.config/kilo` |
| Amp | [plugin API](https://ampcode.com/manual/plugin-api) | `plugins/tuios-agent-state.ts` in `~/.config/amp` |
| Pi | Pi's extension events | `extensions/tuios-agent-state.ts` in `~/.pi/agent` |
| oh-my-pi (omp) | [extension loading](https://github.com/can1357/oh-my-pi/blob/main/docs/extension-loading.md), [extension types](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/src/extensibility/extensions/types.ts) | `extensions/tuios-omp-agent-state.ts` in `~/.omp/agent`; needs omp 18.3.2 or newer |
| Kimi Code CLI | [hooks](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/hooks.html) | `[[hooks]]` in `~/.kimi-code/config.toml`; needs 0.14.0 or newer |
| Qwen Code | [hooks](https://github.com/QwenLM/qwen-code/blob/main/docs/users/features/hooks.md) | `hooks` in `~/.qwen/settings.json` |
| GitHub Copilot CLI | [hooks reference](https://docs.github.com/en/copilot/reference/hooks-reference) | `hooks/tuios.json` in `~/.copilot` |
| Cursor Agent | [hooks](https://cursor.com/docs/hooks) | `~/.cursor/hooks.json` |
| Crush | [hooks](https://github.com/charmbracelet/crush/blob/main/docs/hooks/README.md) | A `PreToolUse` session hook; Crush also reports over herdr's protocol by itself |
| Qoder CLI | [hooks](https://docs.qoder.com/zh/cli/hooks) | `hooks` in `~/.qoder/settings.json` |
| Antigravity, Devin, Droid, Grok, Hermes | herdr's installers for each | Session hooks, or for Hermes a `plugins/tuios-agent-state/` plugin |
| Agent Client Protocol | [agentclientprotocol.com](https://agentclientprotocol.com) | The `acp` integration kind used by `tuios agent-proto` |

Upstream repositories: [oh-my-pi](https://github.com/can1357/oh-my-pi) (MIT) and [Crush](https://github.com/charmbracelet/crush).

### Third-party hooks and integrations

| Name | What it does | How it relates to tuios | Author · licence · updated |
| --- | --- | --- | --- |
| [meteor614 CodeBuddy and Reasonix hooks](https://github.com/meteor614/.dotfiles/blob/master/.codebuddy/hooks/herdr-agent-state.sh) | Reports CodeBuddy and Reasonix agent state over herdr's protocol | Written to coexist with tuios: it exits when `TUIOS_ENV=1`, because tuios's herdr socket and `tuios agent-hook claude-code` already cover those panes | meteor614 · n/l · 2026-10-06 |
| [demon-slayer-agents](https://github.com/diegosouza/demon-slayer-agents) | Multi-agent "Master and seats" orchestration; its `extensions/slayer.ts` Pi extension dispatches work with `tuios list-agents`, `tuios_ask_agent` and pane creation | Built on the tuios agent bus and CLI | diegosouza · n/l · 2026-10-05 |
| [ktappdev/.pi](https://github.com/ktappdev/.pi/blob/main/agent/extensions/tuios-agent-state.ts) | A Pi configuration repo that commits the tuios-managed extension | An example of what `tuios integration install pi` writes; not original work | ktappdev · n/l · 2026-10-05 |
| [chenxin-yan nix module](https://github.com/chenxin-yan/nix-dotfiles/blob/main/modules/features/cli/tuios.nix) † | A Home Manager feature module for tuios that references `tuios-agent-state` | Nix-managed tuios with agent-state wiring | chenxin-yan · n/l · 2026-10-06 |

## MCP

`tuios mcp` is a stdio MCP server whose tools mirror daemon verbs. `tuios integration install <harness> --mcp` registers it read-only (or `--mcp-write` with writes) for Claude Code, Codex, Gemini CLI and opencode; other clients register it by hand, for example `claude mcp add tuios -- tuios mcp`. The tool list is in [Agents](agents.md#the-mcp-server).

| Name | Notes |
| --- | --- |
| [The `mcp` skill topic](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/skills/tuios/mcp.md) | First-party: setup, `--scope all`, and the tool list; also printed by `tuios --skill mcp` |
| [clauth](https://github.com/uwuclxdy/clauth) | A Claude Code multi-account manager with cross-account delegation over MCP (MIT). The tuios docs list it as a herdr-plugin tool run from a command key; it is not a tuios MCP client |
| [agent-fleet issue #54](https://github.com/hyb175/agent-fleet/issues/54) | Cites tuios's session-scoped MCP tools as prior art; a mention, not an integration |

No MCP registry lists tuios: Glama, PulseMCP, Smithery and mcp.so return only unrelated TUIO, TUUI and cmux servers.

## herdr compatibility and the herdr ecosystem

tuios emulates herdr's socket API (tracking herdr v0.9.3's schema), exports `HERDR_*` variables into panes, and listens at `$XDG_RUNTIME_DIR/tuios/tuios.sock.herdr`. The hosted page is [tuios.dev/docs/herdr-compatibility](https://tuios.dev/docs/herdr-compatibility) and the design note is [the blog post on Crush and herdr](https://tuios.dev/blog/crush-reports-to-herdr-so-tuios-answers-as-herdr). Which herdr methods tuios answers and refuses is in [Agents](agents.md#herdr-compatibility).

| Name | What it does | How it works with tuios | Author · licence · updated |
| --- | --- | --- | --- |
| [herdr](https://github.com/herdrdev/herdr) ([site](https://herdr.dev), [plugins](https://herdr.dev/docs/plugins/)) | Terminal agent multiplexer | The protocol tuios emulates | herdrdev · Apache-2.0 · 2026-10-07 |
| [Collie](https://github.com/AltanS/collie) | Self-hosted phone PWA that drives agents in herdr, tmux, zellij, tuios or Tern | Has a native tuios adapter (`bridge/mux/tuios/`, merged 2026-09-30) that talks to the daemon's JSON verb socket; tuios replays a Collie request fixture in its conformance tests; it can also drive tuios through the tmux shim | AltanS · MIT · 2026-10-07 |
| [terminal-browser](https://github.com/zenbu-labs/terminal-browser) | A web browser inside the terminal | `terminal-browser open URL --split right`; uses herdr `pane split/swap/run/neighbor/process-info`; needs kitty graphics in the outer terminal | zenbu-labs · MIT · 2026-10-07 |
| [terminal-code (`tode`)](https://github.com/zenbu-labs/terminal-code) | VS Code in the terminal | `tode --split right`, the same herdr calls as terminal-browser | zenbu-labs · MIT · 2026-10-01 |
| [vim-herdr-navigation](https://github.com/paulbkim-dev/vim-herdr-navigation) | <kbd>Ctrl</kbd>+<kbd>h</kbd>/<kbd>j</kbd>/<kbd>k</kbd>/<kbd>l</kbd> across herdr panes and Vim splits | Works through `pane focus --direction`; its herdr-side key binding is a plugin action tuios does not run | paulbkim-dev · MIT · 2026-08-23 |
| [herdr-splits.nvim](https://github.com/lmilojevicc/herdr-splits.nvim) | Smart-splits navigation and resize for herdr and Neovim | Navigation works; resize fails because tuios does not answer `pane.resize` | lmilojevicc · MIT · 2026-08-17 |
| [herdr-watch](https://github.com/Unayung/herdr-watch) | herdr agent status on an Apple Watch | `HERDR_SOCKET_PATH="$XDG_RUNTIME_DIR/tuios/tuios.sock.herdr" node bridge.js` | Unayung · MIT · 2026-08-14 |
| [herdr-telegram-agents](https://github.com/permgps/herdr-telegram-agents) | Drive coding agents from Telegram topics | Same socket setup; uses `agent.*`, `events.subscribe` and `tab.*` | permgps · MIT · 2026-10-07 |
| [zoetrope (`zoe`)](https://github.com/furkankly/zoetrope) | Live flow graph of a Claude Code or Codex session | A herdr-plugin tool; run it from a tuios command key | furkankly · MIT · 2026-10-06 |
| [memex](https://github.com/nicosuave/memex) | Search and resume agent transcripts | Run from a command key | nicosuave · MIT · 2026-10-06 |
| [crabbox](https://github.com/openclaw/crabbox) | Warm a box, sync the diff, run the suite | Run from a command key | openclaw · MIT · 2026-10-07 |
| [agentbox](https://github.com/madarco/agentbox) | Parallel sandboxed agent VMs | Run from a command key | madarco · MIT · 2026-09-24 |
| [clauth](https://github.com/uwuclxdy/clauth) | Claude Code multi-account manager | Run from a command key | uwuclxdy · MIT · 2026-10-07 |
| [tsk](https://github.com/smarzban/tsk) | Terminal task board for people and agents | Run from a command key | smarzban · MIT · 2026-10-06 |

Agents that herdr supports through its own hook scripts, such as Letta Code and MastraCode, report to tuios once you install herdr's integration for them. "Run from a command key" means the tool needs no herdr calls of its own; see [command keys](keybindings.md#command-keys).

## tmux shim

`tuios tmux-shim -- <command>` sets `TMUX`, answers the tmux commands a tool issues, and opens the panes it asks for as tuios panes. The shim is documented in [Sessions](sessions.md#the-tmux-shim).

| Name | How it works with tuios |
| --- | --- |
| [Claude Code agent teams](https://code.claude.com/docs/en/hooks) | `tuios tmux-shim -- env CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude`; each teammate opens as a named tuios pane with agent state |
| [Collie, tmux mode](https://github.com/AltanS/collie) | Link `tmux` to the tuios binary and pass the shim socket (`tmux/socket` beside the daemon socket) with `-S`; set `COLLIE_TMUX_BIN` and `COLLIE_MUX_ENDPOINT_TMUX` |
| [tmux-xpanes](https://github.com/greymd/tmux-xpanes) | Not driven through the shim: tuios ships a native clone, `tuios xpanes`, modelled on it |
| [claude-squad](https://github.com/smtg-ai/claude-squad) † | Mentioned on tuios.dev's comparison page as a tmux-based agent manager; no documented shim compatibility |

## Editor plugins

| Name | What it does | How it relates to tuios | Author · licence · updated |
| --- | --- | --- | --- |
| [tuios-nvim-navigator](https://github.com/Tim4c/tuios-nvim-navigator) | Moves across Neovim splits and, at an edge, emits `OSC 7777 ; tuios-nvim-navigator ; focus ; <dir>` so tuios focuses the neighbouring pane | A native tuios plugin, linked from the tuios.dev keybindings docs; needs the Neovim pane-navigation feature (off by default) | Tim4c · MIT · 2026-10-01 |
| [vim-herdr-navigation](https://github.com/paulbkim-dev/vim-herdr-navigation) | Vim split and pane navigation | Through herdr compatibility | paulbkim-dev · MIT · 2026-08-23 |
| [herdr-splits.nvim](https://github.com/lmilojevicc/herdr-splits.nvim) | Navigation and resize | Through herdr compatibility; resize does not work | lmilojevicc · MIT · 2026-08-17 |

Usage examples: [stonevil/dotfiles](https://github.com/stonevil/dotfiles) (a lazy.nvim spec in `exact_plugins/tuios.lua`) and [chenxin-yan/nix-dotfiles](https://github.com/chenxin-yan/nix-dotfiles) (`tuios-navigation.lua`), which gates on `TUIOS_PANE_ID` so the tuios plugin wins over vim-herdr-navigation, since tuios panes also export `HERDR_*`.

There is no tuios plugin for Emacs, VS Code, Zed or JetBrains.

## Skills and agent skills

| Name | What it is | Author · licence · updated |
| --- | --- | --- |
| [Embedded skill, `tuios --skill [topic]`](https://github.com/Gaurav-Gosain/tuios/tree/v0.8.5/skills/tuios) | First-party, compiled into the binary; topics config, errors, events, fleet, grants, herdr, hosts, inbox, mail, mcp, panes, recipes, state, tmux | Gaurav Gosain · MIT · v0.8.5 |
| [agentskillexchange: persistent multi-agent terminal workspaces with TUIOS](https://github.com/agentskillexchange/skills/tree/main/skills/run-persistent-multi-agent-terminal-workspaces-with-tuios) | A third-party catalogue `SKILL.md` teaching agents to use sessions, state and the Inbox | agentskillexchange · MIT · 2026-10-07 |
| [skillhot entry](https://github.com/savanna0425/skillhot/blob/main/public/data/details/gaurav__gosain__tuios.json) † | A Chinese agent-skills discovery site with a tuios record | savanna0425 · n/l · 2026-10-07 |
| [scrnetto ai-tools-catalog](https://github.com/scrnetto/ai-tools-catalog) | A catalogue skill (Italian) listing TUIOS among 340+ tools | scrnetto · MIT · 2026-09-28 |

skills.sh, SkillsMP, ClawHub, tessl and agentskill.sh have no tuios skill. Your own `tuios-inbox` skill is local and not on the public internet.

## Packaging

| Channel | Where | Version and notes | Maintainer |
| --- | --- | --- | --- |
| Homebrew core | [formulae.brew.sh/formula/tuios](https://formulae.brew.sh/formula/tuios), [formula source](https://github.com/Homebrew/homebrew-core/blob/main/Formula/t/tuios.rb) | 0.8.5 | Homebrew |
| Homebrew tap | [Gaurav-Gosain/homebrew-tap](https://github.com/Gaurav-Gosain/homebrew-tap) | `tuios.rb` and `tuios-web.rb` | upstream |
| AUR | [tuios-bin](https://aur.archlinux.org/packages/tuios-bin), [tuios-web-bin](https://aur.archlinux.org/packages/tuios-web-bin) | 0.8.5-1, 2026-10-02 | Gaurav-Gosain |
| nixpkgs | [pkgs/by-name/tu/tuios](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/tu/tuios/package.nix) | 0.8.5 in unstable, 0.7.0 in 26.05, 0.3.4 in 25.11 | kpbaks |
| Nix flake | [flake.nix at v0.8.5](https://github.com/Gaurav-Gosain/tuios/blob/v0.8.5/flake.nix) | `nix run github:Gaurav-Gosain/tuios/v0.8.5#tuios` | upstream |
| NUR | [lonerOrz/loneros-nur](https://github.com/lonerOrz/loneros-nur/tree/main/pkgs/tuios) † | Third-party NUR package | lonerOrz · MIT |
| Docker | `ghcr.io/gaurav-gosain/tuios` | Tags include v0.8.3, v0.8.4, v0.8.5 | upstream |
| Chocolatey | [community.chocolatey.org/packages/tuios](https://community.chocolatey.org/packages/tuios) | 0.8.5 | mkabumattar |
| conda-forge | [tuios-feedstock](https://github.com/conda-forge/tuios-feedstock) | Latest built 0.7.0; 0.8.x PRs open | conda-forge |
| Alpine | [edge/testing/tuios](https://pkgs.alpinelinux.org/package/edge/testing/x86_64/tuios) | 0.6.0, outdated | Alpine |
| Gentoo | [app-misc/tuios-bin](https://gpo.zugaina.org/app-misc/tuios-bin) | arrans-overlay | arran4 |
| Void | [community repo issue #230](https://github.com/oSoWoSo/vOid_Community_repOsitory/issues/230) | An open "update to 0.8.5" request, which implies an existing template | oSoWoSo |
| pixi / aqua | [prefix-dev/octoconda](https://github.com/prefix-dev/octoconda) † | `tuios` in its `aqua.toml` and `config.toml` | prefix-dev |
| swamp | [@svendowideit/tuios](https://github.com/SvenDowideit/swamp-extensions/tree/main/extensions/models/tuios) | Installs and upgrades from verified releases and runs the daemon as a systemd user service | Sven Dowideit |
| Repology | [repology.org/project/tuios](https://repology.org/project/tuios/versions) | Aggregates the channels above | |
| Go | [pkg.go.dev](https://pkg.go.dev/github.com/Gaurav-Gosain/tuios) | `go install github.com/Gaurav-Gosain/tuios/cmd/tuios@latest` | upstream |

Not packaged: Scoop (no manifest in Main or Extras) and Winget.

## Companion tools and related projects

### First-party

| Name | Notes |
| --- | --- |
| [tuios.dev](https://tuios.dev) | Hosted docs, blog and release notes; source at [Gaurav-Gosain/tuios-docs](https://github.com/Gaurav-Gosain/tuios-docs) (Next.js and Fumadocs); exposes `/llms.txt`, `/llms-full.txt` and `.md` exports of every page |
| [tuios.dev/learn](https://tuios.dev/learn) | The interactive tour: the real app compiled to WebAssembly, with tracks for agents, automation, from-tmux, from-zellij, make-it-yours and workspaces |
| [tuios-web](https://tuios.dev/docs/web) | The browser terminal, a separate binary in `cmd/tuios-web`, served through sip |
| [tuios-wasm](https://github.com/Gaurav-Gosain/tuios/tree/v0.8.5/cmd/tuios-wasm) | The WebAssembly build behind the tour |
| [sip](https://github.com/Gaurav-Gosain/sip) | Serves Bubble Tea apps in the browser; used by tuios-web (MIT) |
| [tuitest](https://github.com/Gaurav-Gosain/tuitest) | Headless PTY test harness that vendors tuios's VT interpreter (MIT) |
| [wlterm](https://github.com/Gaurav-Gosain/wlterm) | A Wayland compositor that runs inside a terminal pane; its demo nests kitty and tuios |
| [youterm](https://github.com/Gaurav-Gosain/youterm) | Kitty-graphics video player that the tuios README says works inside tuios |
| [tuios-courier](https://github.com/Gsirawan/tuios-courier) | Community relay for agent mail between machines over HTTPS (MIT), linked from tuios.dev |
| [Tape scripting](https://tuios.dev/docs/tape-scripting), [tape recording](https://tuios.dev/docs/tape-recording) | The built-in automation DSL; see [Automation](automation.md) |
| [DeepWiki](https://deepwiki.com/Gaurav-Gosain/tuios) † | A generated wiki over the source, linked from the README |

### Third-party tools built for or on tuios

| Name | What it does | How it relates to tuios | Author · licence · updated |
| --- | --- | --- | --- |
| [tuios-inbox](https://github.com/unixsuperhero/tuios-inbox) | Local task management and an email-style inbox backed by tuios (Bun, SQLite, browser UI) | Reads tuios agent turns, commands and mail | unixsuperhero · none · 2026-10-07 |
| [utena](https://github.com/eleonorayaya/utena) | Workspace-management daemon and TUI: control socket, event stream, `utena attach`, popups, a dock cell | Replaced tmux with tuios as its multiplexer | eleonorayaya · n/l · 2026-10-04 |
| [xmux](https://github.com/zer0ken/xmux) | Cross-machine, cross-multiplexer session switcher | Supports tuios as a mux | zer0ken · MIT · 2026-10-07 |
| [Squad](https://github.com/runecraftai/squad) | Agent squad runner | An experimental tuios runtime backend (`docs/tuios-backend.md`) | runecraftai · MIT · 2026-10-06 |
| [stackops](https://github.com/thisismygitrepo/stackops) | Stack, dotfile and session manager | A tuios session backend (`_tuios_backend*.py`, `sessions_tuios.py`, `tuios_export.py`) | thisismygitrepo · Apache-2.0 · 2026-10-07 |
| [nestlo](https://github.com/anubhavg-icpl/nestlo) | NixOS-based OS for coding agents | `tuios_bridge.py` follows `tuios subscribe`, writes audit events and serves Prometheus metrics; also a NixOS tuios module | anubhavg-icpl · MIT · 2026-10-06 |
| [phlow-tuios](https://github.com/qompassai/phlow/tree/main/crates/phlow-tuios) | Rust crate, "session multiplexing for phlow" | A client of the line-delimited JSON control protocol | qompassai · MIT or Apache-2.0 · 2026-10-04 |
| [atdd-flow](https://github.com/afokapu/atdd-flow) | Filesystem-first registry for tasks and handoffs (npm `@afokapu/atdd-flow`) | tuios is its primary live host (`--application tuios`) | afokapu · MIT · 2026-10-06 |
| [WebTUIOS](https://github.com/Riyoway/WebTUIOS) | A PWA that runs tuios on Alpine in the browser through CheerpX and xterm.js | Pinned to tuios v0.7.0 | Riyoway · MIT · 2026-08-20 |
| [mesh-workstation](https://github.com/henryavila/mesh-workstation) | Reproducible dev-machine setup | Protected tuios browser access through a Cloudflare Access tunnel | henryavila · n/l · 2026-10-02 |
| [cyber-mux issue #145](https://github.com/cyberuni/cyber-mux/issues/145) | A multiplexer abstraction | An open proposal for a tuios adapter; not implemented | cyberuni · n/l · 2026-10-06 |
| [Fish completions in mogfish](https://github.com/AFDudley/mogfish/blob/main/training/scraped_completions/tuios.fish) † | Scraped fish completions; also in synmux/dotfiles-fish and ichsansting/mysh | `tuios completion fish` generates the real thing | AFDudley · n/l · 2026-04-04 |

### Listings, articles and media

| Name | Notes |
| --- | --- |
| [Terminal Trove](https://terminaltrove.com/tuios/) † | Tool of the Week; the badge is in the README |
| [LinuxLinks](https://www.linuxlinks.com/tuios-terminal-ui-operating-system/) | Review and feature page |
| [It's FOSS: 8 terminal multiplexers worth trying](https://itsfoss.com/terminal-multiplexers/) | Includes TUIOS |
| [ruanyf weekly, issue 8148](https://github.com/ruanyf/weekly/issues/8148) | Chinese weekly newsletter recommendation, 2025-11-11 |
| [とことんDevOps blog](https://devops-blog.virtualtech.jp/entry/20251208/1765153476) | Japanese article on TUIOS as a tiling window manager in the terminal, 2025-12-08 |
| [Minerva note](https://minerva.mamansoft.net/Notes/TUIOS) | Japanese personal knowledge-base note |
| [mortaf3: TUIOS, terminal window manager for agents](https://mortaf3.com/posts/tuios-pp7bm) † | Blog post |
| [kawarimidoll terminalnight talk](https://github.com/kawarimidoll/slides/blob/main/terminalnight-2025-11-28/talk.sh) | A live terminal talk script that launches tuios as a demo, 2025-11-28 |
| Awesome lists | [awesome-tuis](https://github.com/rothgar/awesome-tuis), [awesome-terminal-multiplexers](https://github.com/arran4/awesome-terminal-multiplexers), [awesome-cli-agents](https://github.com/phamquiluan/awesome-cli-agents), [awesome-ai-tools](https://github.com/QAInsights/awesome-ai-tools) |
| [justtuit](https://github.com/handyutils/justtuit) | A TUI catalogue of 672 terminal apps with a TUIOS entry |
| [terminal-apps.dev submission](https://github.com/scmmishra/terminal-apps.dev/issues/46) | An open submission; not on the site yet |
| [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | A widely-copied NixOS config that replaced zellij with tuios and later removed standalone herdr as superseded by tuios |
| Release feeds | [releases atom](https://tuios.dev/releases/atom.xml), [blog atom](https://tuios.dev/blog/atom.xml) |

## Searched but found nothing

So that you do not repeat the search, these came up empty on 7 October 2026:

- **MCP registries.** Glama, PulseMCP, Smithery and mcp.so have no tuios entry.
- **Skill marketplaces.** skills.sh, SkillsMP, ClawHub, tessl and agentskill.sh have no tuios skill.
- **Editor plugins.** Nothing for Emacs, VS Code, Zed or JetBrains.
- **Theme packs.** No dedicated theme repository; the GitHub topic `tuios` has no repositories.
- **Windows packaging.** No Scoop or Winget manifest.
- **Plugin registries.** No third-party tuios plugin on npm or in opencode's registry apart from atdd-flow, which names tuios as a host.
- **Video and audio.** No YouTube video or podcast surfaced; the demo MP4s live on tuios.dev's release pages.
- **Discussion threads.** No indexed Hacker News or Reddit thread.
- **herdr's side.** herdr's plugin page does not mention tuios; compatibility is documented only by tuios.
- **Code search** for `tuios set-agent-state`, `tuios integration install`, `tuios import-theme` and `tuios --skill` outside the upstream repository found no third-party hits.
- **Excluded as noise.** TUIO touch-protocol projects; `benmulligan4/tuiOS`, `meavxxxx/TuiOS` and `Erickrus/runtui` (unrelated projects with the same name); plain forks and mirrors; GitHub-trending archive dumps.

## Submitting something

If you build a dock component, a theme or an integration worth listing, the places the tuios project itself links from are the README, `docs/AGENT_STATE.md` for anything agent-related, and `examples/dock/` for components. Open a pull request against [Gaurav-Gosain/tuios](https://github.com/Gaurav-Gosain/tuios) following `docs/CONTRIBUTING.md`, or a documentation change against [tuios-docs](https://github.com/Gaurav-Gosain/tuios-docs). Add it to this chapter too.
