# dotfiles

**Run several coding agents side by side in tmux, and always know which one needs you.** My macOS and Debian setup, managed with [chezmoi](https://www.chezmoi.io), built around the [Pi coding agent](https://github.com/earendil-works/pi).

![Ghostty with tmux: Neovim with the file tree and LSP hover, Pi coding agent, and the Pi extensions](docs/screenshots/showcase.png)

- **Agent attention queue.** [`notify-done`](dot_pi/agent/extensions/notify-done/README.md) sends a macOS notification and a tmux bell when an agent finishes or is blocked on you. <kbd>prefix</kbd> <kbd>N</kbd> jumps to the next pane that needs you: blocked agents first, then finished ones, oldest first.
- **Guardrails.** `bash-guard` asks before destructive shell commands and hard-blocks catastrophic ones in subagents.
- **Dotfiles an agent can maintain.** [`AGENTS.md`](AGENTS.md) tells a coding agent how to edit, sync and commit this repo safely: the live → source workflow, secret checks, one change per commit, and no work data in public.
- **Careful by default.** Secret scanning in a pre-commit hook and on the full history in CI, tools that are pinned and checksum-verified, and a 7-day release-age cooldown for npm and uv.
- **The rest:** zsh in about 0.1s, Neovim 0.12 on `vim.pack` with a committed lockfile, tmux that survives reboots, and a minimal `server` profile for Debian boxes.

**Take what you want.** Most files stand alone, and the sections below explain the ones that don't. To see what would change on your machine without applying anything: `chezmoi init GeorgopoulosGiannis/dotfiles && chezmoi diff`.

Ideas, questions and "you should try X" are welcome in [issues](../../issues).

## What's inside

| Area | Files | Highlights |
|------|-------|------------|
| Shell | `dot_zshrc.tmpl`, `dot_zprofile`, `dot_zshenv`, `dot_p10k.zsh` | zsh + powerlevel10k, vi mode synced with the system clipboard, shared history, ~0.1s startup, syntax highlighting and history-substring search |
| Terminal | `dot_tmux.conf.tmpl`, `dot_config/ghostty` | tmux with vim-style panes, extended keys, and reboot recovery via tmux-resurrect/continuum |
| Editor | [`dot_config/nvim`](dot_config/nvim/README.md), `dot_vimrc` | Neovim 0.12 on the built-in `vim.pack` with a committed lockfile; LSP, completion, DAP, .NET/F#, Go, Python. Plain vim mirrors the core options for servers |
| Git | `dot_gitconfig.tmpl`, `dot_config/private_git/private_ignore` | Email from local chezmoi data, sensible defaults, global ignores |
| Pi agent | [`dot_pi/agent`](#pi-coding-agent) | Settings, extensions, skills and subagent definitions |
| macOS | `.chezmoiscripts/*-macos-*` | Packages via Homebrew, system defaults, Dock, menu bar, file associations |
| Dictation | `private_Library/.../com.pais.handy` | [Handy](#dictation-handy): offline speech-to-text into any app |
| Debian | `.chezmoiscripts/*-linux*` | apt packages, pinned + checksummed Neovim/tree-sitter, a minimal `server` profile |
| Runtimes | `dot_config/mise` | Node and Go versions via [mise](https://mise.jdx.dev) on both OSes |
| Tools | `dot_local/private_bin/executable_upall`, `dot_colima`, `dot_npmrc`, `dot_config/uv` | One-shot updater, Colima (Docker) defaults, 7-day release-age cooldown for npm and uv |

### chezmoi naming, briefly

Source names map to target files: `dot_zshrc` → `~/.zshrc`, `private_` sets mode 600/700,
`executable_` sets +x, `create_` writes a file only if it doesn't exist yet, and `.tmpl` files are
[Go templates](https://www.chezmoi.io/user-guide/templating/) rendered per machine.
`.chezmoiscripts/run_onchange_*` scripts run on first apply and again whenever their content changes.

## Install

> [!WARNING]
> The macOS scripts apply **my** preferences: dark mode, fast key repeat, auto-hiding Dock,
> a **replaced Dock app list**, menu bar layout and Neovide as the default text editor.
> Read `.chezmoiscripts/` before applying on your own Mac, or delete what you don't want.
> To preview everything first: `chezmoi init GeorgopoulosGiannis/dotfiles && chezmoi diff`.

**macOS** (Apple Silicon or Intel; Homebrew is installed if missing):

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
~/.local/bin/chezmoi init --apply GeorgopoulosGiannis/dotfiles
```

**Debian/Ubuntu** (developed against Debian 13; older releases skip a few optional packages):

```sh
sudo apt install -y git curl
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
~/.local/bin/chezmoi init --apply GeorgopoulosGiannis/dotfiles
chsh -s "$(command -v zsh)"   # then log out and back in
```

`chezmoi init` asks a few questions once and stores the answers in
`~/.config/chezmoi/chezmoi.toml` (never committed). Pre-answer them with flags to skip the prompts:

| Prompt | Flag | Effect |
|--------|------|--------|
| `email` | `--promptString email=you@example.com` | Your git email. |
| `work` | `--promptBool work=false` | Work machine. **Answer `false`** unless you've set up your own private work repo (see below). |
| `profile` (Linux only) | `--promptChoice profile=dev` | `dev`: everything incl. Neovim, Node, Go, compilers, Pi. `server`: zsh, tmux, git, vim and CLI tools only. macOS is always `dev`. |

Change an answer later with `chezmoi edit-config`, then `chezmoi diff` and apply.

## Personal vs work machines

The repo is public, so nothing employer-specific lives here. On machines with `work = true`,
chezmoi additionally clones a **private** repo to `~/.local/share/dotfiles-work`
(`.chezmoiexternal.toml.tmpl`, refreshed daily, needs `gh auth login` first), and the public
config only points at it if it exists:

- `~/.gitconfig` includes its `gitconfig` (per-org work email via `includeIf`)
- `~/.zshrc` sources its `zshrc` (work aliases)
- Pi's `settings.json` merges its `pi/settings.json` (work-only packages and skills)

The same flag also selects Pi's default provider/model. To reuse the pattern, point the
external at your own private repo, or delete the block and answer `work=false`.

## Dictation (Handy)

[Handy](https://github.com/cjpais/Handy) is a free, open-source speech-to-text app that runs
entirely on the Mac. Hold <kbd>Option</kbd>+<kbd>Space</kbd> and talk (or tap it to start and
stop) and the text is pasted into whatever app has focus: the terminal, Neovim, a Pi prompt.
I use it to talk to coding agents, which is much faster than typing long prompts.

The settings file is a `create_` file: chezmoi writes it only on a Mac where Handy has no
settings yet, then Handy owns it. Notable choices: launch at login, start hidden (only a
menu bar icon; Handy needs the tray icon to start hidden), a small, fast on-device model, filler words
("um", "uh") removed, the clipboard restored after pasting, and **AirPods mode**, which takes
the AirPods mic over from an iPhone that is playing audio (otherwise recordings come back silent;
it lives under Advanced → Experimental, so experimental settings are switched on to keep it visible).
Optional LLM post-processing (<kbd>Option</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd>) is off; its API
keys stay in Handy and never reach this repo.

## Pi coding agent

Managed on `dev` machines: `~/.pi/agent/settings.json` (only the keys set in `modify_settings.json`), `keybindings.json`,
local extensions, skills and subagent definitions. Credentials, sessions, caches,
installed packages and browser profiles are excluded by `.chezmoiignore` and `.gitignore`.

| Extension | What it does |
|-----------|--------------|
| `ask-user-question` | Lets the agent ask you a question: free text, single or multi-select, with an "other" option |
| `bash-guard` | Prompts before destructive `bash` calls; hard-blocks catastrophic ones in subagents |
| `browser` | Playwright Chromium tools for debugging live web apps (off by default, `/browser on`) |
| `custom-header` | Startup header with a binary-π logo |
| [`notify-done`](dot_pi/agent/extensions/notify-done/README.md) | **Mine.** macOS notification + tmux bell when an agent finishes or needs input, with a queue that jumps you to the right tmux pane |
| `web-fetch` | URL → readable markdown (HTML, PDF, text); public URLs fall back to Jina Reader |
| `web-search` | **Mine.** Web search via Tavily, with bounded output and offline tests |

| Skill | What it does |
|-------|--------------|
| `analyze-sessions` | Cost, prompt-pattern and transcript search over past Pi sessions |
| `pdf-reader` | Text extraction, search and page rendering for PDFs (PyMuPDF) |
| `web-debug` | Playbook for verifying frontend behaviour by driving the live page |
| `youtube-transcript` | Video title and captions as JSON (yt-dlp) |

Packages: [pi-interactive-subagents](https://github.com/amosblomqvist/pi-interactive-subagents)
(async subagents in tmux panes) with `scout`, `researcher` and `worker` definitions in
`dot_pi/agent/agents`, and [pi-obsidian](https://www.npmjs.com/package/pi-obsidian).
See [`dot_pi/agent/extensions/README.md`](dot_pi/agent/extensions/README.md) for details.

Pi itself is installed separately. After the first apply on a new machine, install the
extensions' dependencies (review the manifests first):

```sh
cd ~/.pi/agent/extensions
npm ci --ignore-scripts
for d in bash-guard browser web-fetch; do npm --prefix "$d" ci --ignore-scripts; done
npm run typecheck && npm test
```

Then log in to your provider inside Pi (`/login`). For web search, set `TAVILY_API_KEY` or
create `~/.pi/agent/extensions/web-search/auth.json` locally (`chmod 600`); never commit keys.

## Day to day

| Task | Command |
|------|---------|
| Edit a managed file | `chezmoi edit ~/.zshrc`, then `chezmoi apply` |
| Edited the live file instead | `chezmoi add ~/.zshrc` (for templates, edit the source) |
| Pull and apply on another machine | `chezmoi update` |
| Commit | `chezmoi cd`, then git as usual |
| Update brew, apt, npm, uv, Pi, Neovim plugins, Mason | `upall` (`-n` dry run, `-y` no prompts, `upall brew npm` for some steps) |

After a Neovim plugin update, `chezmoi add ~/.config/nvim/nvim-pack-lock.json` and commit it.
For AI agents working in this repo, [`AGENTS.md`](AGENTS.md) describes the workflow.

Commits are scanned for secrets by a [betterleaks](https://github.com/betterleaks/betterleaks)
pre-commit hook (`.githooks/`, enabled once per machine by a chezmoi script), and again in
[CI](.github/workflows/ci.yml) together with the Pi extension checks and shellcheck.

## Servers

`profile=server` gives a remote Debian box my shell, tmux, git and vim without the dev
toolchain (no Neovim, mise or Pi). Install it as your normal user with the Debian commands above.

Provisioning the machine itself (users, SSH hardening, firewall) is deliberately **not** here;
see [why](#why-these-choices). If you push from a server, authenticate with
`GIT_CONFIG_GLOBAL=~/.config/git/config gh auth setup-git`, so the credential helper goes to
`~/.config/git/config` instead of the chezmoi-managed `~/.gitconfig` (git reads both).

## tmux reboot recovery

tmux-resurrect and tmux-continuum save sessions, windows, pane layouts and working directories
about every 5 minutes; starting `tmux` after a reboot restores the last snapshot. Commands and
pane contents are not restored. `prefix` + `Ctrl-s` saves now, `prefix` + `Ctrl-r` restores.
Snapshots stay in `~/.local/share/tmux/resurrect` and are never committed.

## Secrets

Nothing secret is committed; `chezmoi add --secrets=error` guards additions. Personal machines
use [passage](https://github.com/FiloSottile/passage) (age-encrypted, Secure Enclave + a
passphrase-protected backup key) from a separate private repo cloned to `~/.passage`; the
`pp` shell function is a fuzzy picker over it.

## Limitations

Things that are easy to trip over, by design or because of how macOS and the apps work:

- **One-way, one-time macOS settings.** The `run_onchange_` scripts apply macOS defaults, the Dock,
  the menu bar and file associations when the script changes, not on every apply. Later changes you
  make in System Settings are neither reverted nor written back here. Key repeat needs a logout;
  the Dock script **replaces** the Dock's app list.
- **App-owned settings are seeds.** Handy's settings are a `create_` file: written only if Handy
  has none yet. Changing it here does nothing on a Mac that already has Handy set up; change
  those Macs in Handy's UI. Apps must be quit for an edited settings file to stick.
- **Pi settings are partially managed.** Only the keys in `modify_settings.json` are enforced;
  Pi's own keys are kept. A key removed from the template is not removed from existing machines.
- **Permissions can't be scripted.** macOS asks once per app for Microphone and Accessibility
  (Handy), notifications (terminal-notifier) and similar; approve them by hand on a new Mac.
- **Nothing is uninstalled.** Removing a package from the scripts doesn't remove it from machines,
  and files that stop being managed only disappear if listed in `.chezmoiremove`.
- **Work machines need a second apply.** chezmoi renders templates before it clones the private
  work repo, so the first apply on a work machine misses the work Pi fragment; run it again.
- **Per-machine credentials.** Pi logins, the Tavily key, `gh` auth, browser profiles and passage
  identities are set up by hand on every machine and never synced.
- **Debian.** Tested on Debian 13 (a CI-style container run of both profiles). Older releases skip
  `eza`/`sops`, and tmux older than 3.5 skips the `csi-u` extended-keys format. GUI apps, macOS
  scripts and Handy are macOS-only.
- **Fonts.** The prompt and Neovim icons assume a [Nerd Font](https://www.nerdfonts.com/) in your
  terminal; none is installed by these scripts.

## Notes

- `run_onchange_` scripts re-run only when their rendered text changes. If a download failed, retry with
  `chezmoi state delete-bucket --bucket=scriptState && chezmoi apply`.
- Third-party code is pinned: zsh plugins and tmux plugins by tag/commit in `.chezmoiexternal.toml.tmpl`,
  Neovim plugins by `nvim-pack-lock.json`, Debian binaries by version and sha256.
- `README.md`, `AGENTS.md`, `LICENSE` and `docs/` are repo-only and never deployed to `$HOME`.

## Why these choices

- **chezmoi**, not stow or a bare git repo: one source for macOS and Debian, templates per machine
  (work/personal, dev/server), a private overlay repo, secret checks on `add`, and scripts that
  re-run only when they change.
- **Homebrew and shell scripts, not Nix.** Many dotfiles repos use nix-darwin or home-manager for
  fully declarative, reproducible machines, and that is the more robust approach. I prefer how easy
  brew and a few idempotent scripts are to read, debug and change, and they haven't caused me
  problems. If drift starts to bother me, Nix is the next step.
- **zsh with powerlevel10k.** Instant prompt, transient prompt and async git status keep it the
  fastest, most capable zsh prompt. Its author has put it on
  [life support](https://github.com/romkatv/powerlevel10k/issues/2690): feature-complete and still
  working, but no fixes. [Starship](https://starship.rs) is the exit if it ever breaks.
- **mise for Node and Go**, instead of nvm plus Homebrew/apt runtimes: one fast tool, the same
  versions on macOS and Debian, and it reads `.nvmrc`/`.node-version`. Python tools use uv.
- **Neovim, plus a small `.vimrc` for servers.** Laptops get the full Neovim; servers get plain
  Vim (preinstalled, no compiler or Node toolchain) with the same core options and keys.
- **Neovim's built-in `vim.pack`, starting from kickstart.nvim.** No plugin-manager dependency and
  a committed lockfile; kickstart is a readable single-file base to grow from.
- **Ghostty**: fast, native on macOS, good defaults (two lines of config), and it supports the
  modern keyboard protocols tmux and Neovim use.
- **tmux**: sessions survive closed windows, SSH drops and, with resurrect, restarts; it works the
  same locally and on servers, and Pi's subagents run in tmux panes.
- **Colima**: the Docker engine without Docker Desktop; free, open source and CLI-only.
- **Handy for dictation**: offline, so audio never leaves the Mac, and free and open source,
  unlike cloud dictation apps; it works in any app, including the terminal.
- **passage and sops, both on age.** Personal secrets live in a git repo encrypted with age and
  unlock with Touch ID (Secure Enclave). sops uses an age key to encrypt secrets inside infra repos.
- **Pi**: a small, hackable coding agent; extensions are plain TypeScript, so it works the way I want.
- **No server provisioning here.** Dotfiles configure `$HOME`. Creating users, hardening SSH and
  setting up a firewall is infrastructure, and belongs in provisioning code (cloud-init, Ansible)
  that runs when the server is created.
- **A private repo for work.** Keeps this one public without employer details (see above).

## Acknowledgements

- [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim): the starting point of my Neovim config.
- [amosblomqvist/pi-config](https://github.com/amosblomqvist/pi-config): the starting point of my Pi
  config. `ask-user-question`, `bash-guard`, `browser`, `web-fetch` and all four skills come from it
  with small changes, and `custom-header` started from it (credited in each file). His
  [pi-interactive-subagents](https://github.com/amosblomqvist/pi-interactive-subagents), a fork of
  [HazAT's](https://github.com/HazAT/pi-interactive-subagents), provides the subagents.

## License

[MIT](LICENSE) for my own work. Files that come from other projects keep their original authors'
terms: the Neovim config is derived from kickstart.nvim (MIT, see
[`dot_config/nvim/LICENSE.md`](dot_config/nvim/LICENSE.md)), and the Pi files listed above come
from amosblomqvist's repositories.
