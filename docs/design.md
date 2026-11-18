# Design

## Why these choices

- **chezmoi**, not stow or a bare git repo: one source for macOS and Debian, templates per machine (work/personal, dev/server), a private overlay repo, secret checks on `add`, and scripts that re-run only when they change.
- **Homebrew and shell scripts, not Nix.** Many dotfiles repos use nix-darwin or home-manager for fully declarative, reproducible machines, and that is the more robust approach. I prefer how easy brew and a few idempotent scripts are to read, debug and change, and they haven't caused me problems. If drift starts to bother me, Nix is the next step.
- **zsh with powerlevel10k.** Instant prompt, transient prompt and async git status keep it the fastest, most capable zsh prompt. Its author has put it on [life support](https://github.com/romkatv/powerlevel10k/issues/2690): feature-complete and still working, but no fixes. [Starship](https://starship.rs) is the exit if it ever breaks.
- **mise for Node and Go**, instead of nvm plus Homebrew/apt runtimes: one fast tool, the same versions on macOS and Debian, and it reads `.nvmrc`/`.node-version`. Python tools use uv.
- **Neovim, plus a small `.vimrc` for servers.** Laptops get the full Neovim; servers get plain Vim (preinstalled, no compiler or Node toolchain) with the same core options and keys.
- **Neovim's built-in `vim.pack`, starting from kickstart.nvim.** No plugin-manager dependency and a committed lockfile; kickstart is a readable single-file base to grow from.
- **Ghostty**: fast, native on macOS, good defaults (two lines of config), and it supports the modern keyboard protocols tmux and Neovim use.
- **tmux**: sessions survive closed windows, SSH drops and, with resurrect, restarts; it works the same locally and on servers, and Pi's subagents run in tmux panes.
- **Colima**: the Docker engine without Docker Desktop; free, open source and CLI-only.
- **Handy for dictation**: offline, so audio never leaves the Mac, and free and open source, unlike cloud dictation apps; it works in any app, including the terminal.
- **passage and sops, both on age.** Personal secrets live in a git repo encrypted with age and unlock with Touch ID (Secure Enclave). sops uses an age key to encrypt secrets inside infra repos.
- **Pi**: a small, hackable coding agent; extensions are plain TypeScript, so it works the way I want.
- **No server provisioning here.** Dotfiles configure `$HOME`. Creating users, hardening SSH and setting up a firewall is infrastructure, and belongs in provisioning code (cloud-init, Ansible) that runs when the server is created.
- **A private repo for work.** Keeps work-only settings out of this public repo (see [Install](install.md#separate-work-settings)).

## Limitations

Things that are easy to trip over, by design or because of how macOS and the apps work:

- **One-way, one-time macOS settings.** The `run_onchange_` scripts apply macOS defaults, the Dock, the menu bar and file associations when the script changes, not on every apply. Later changes you make in System Settings are neither reverted nor written back here. Key repeat needs a logout; the Dock script **replaces** the Dock's app list.
- **App-owned settings are seeds.** Handy's settings are a `create_` file: written only if Handy has none yet. Changing it here does nothing on a Mac that already has Handy set up; change those Macs in Handy's UI. Apps must be quit for an edited settings file to stick.
- **Pi settings are partially managed.** Only the keys in `modify_settings.json` are enforced; Pi's own keys are kept. A key removed from the template is not removed from existing machines.
- **Permissions can't be scripted.** macOS asks once per app for Microphone and Accessibility (Handy), notifications (terminal-notifier) and similar; approve them by hand on a new Mac.
- **Nothing is uninstalled.** Removing a package from the scripts doesn't remove it from machines, and files that stop being managed only disappear if listed in `.chezmoiremove`.
- **Work machines need a second apply.** chezmoi renders templates before it clones the private work repo, so the first apply on a work machine misses the work Pi fragment; run it again.
- **Per-machine credentials.** Pi logins, the Tavily key, `gh` auth, browser profiles and passage identities are set up by hand on every machine and never synced.
- **Debian.** Tested on Debian 13 (a CI-style container run of both profiles). Older releases skip `eza`/`sops`, and tmux older than 3.5 skips the `csi-u` extended-keys format. GUI apps, macOS scripts and Handy are macOS-only.
- **Fonts.** The prompt and Neovim icons assume a [Nerd Font](https://www.nerdfonts.com/) in your terminal; none is installed by these scripts.
