# Day to day

| Task | Command |
|------|---------|
| Edit a managed file | `chezmoi edit ~/.zshrc`, then `chezmoi apply` |
| Edited the live file instead | `chezmoi add ~/.zshrc` (for templates, edit the source) |
| Pull and apply on another machine | `chezmoi update` |
| Commit | `chezmoi cd`, then git as usual |
| Update brew, apt, npm, uv, Pi, Neovim plugins, Mason | `upall` (`-n` dry run, `-y` no prompts, `upall brew npm` for some steps) |

After a Neovim plugin update, `chezmoi add ~/.config/nvim/nvim-pack-lock.json` and commit it. For AI agents working in this repo, [`AGENTS.md`](../AGENTS.md) describes the workflow.

Commits are scanned for secrets by a [betterleaks](https://github.com/betterleaks/betterleaks) pre-commit hook (`.githooks/`, enabled once per machine by a chezmoi script), and again in [CI](../.github/workflows/ci.yml) together with the Pi extension checks and shellcheck.

## Ghostty theme

The shared `~/.config/ghostty/config.ghostty` uses the built-in **TokyoNight Storm**
theme on both personal and work machines. After editing it, reload Ghostty's config
with `Cmd+Shift+,` on macOS. Check for errors with `ghostty +validate-config` and
inspect resolved colors with `ghostty +show-config`.

The background remains translucent (`background-opacity = 0.85`), so the desktop
behind it affects its appearance. Full-screen apps can draw their own colors;
Ghostty's theme does not change Neovim or Pi themes.

## tmux reboot recovery

tmux-resurrect and tmux-continuum save sessions, windows, pane layouts and working directories about every 5 minutes; starting `tmux` after a reboot restores the last snapshot. Commands and pane contents are not restored. `prefix` + `Ctrl-s` saves now, `prefix` + `Ctrl-r` restores. Snapshots stay in `~/.local/share/tmux/resurrect` and are never committed.

## Secrets

Nothing secret is committed; `chezmoi add --secrets=error` guards additions. Personal machines use [passage](https://github.com/FiloSottile/passage) (age-encrypted, Secure Enclave + a passphrase-protected backup key) from a separate private repo cloned to `~/.passage`; the `pp` shell function is a fuzzy picker over it.

## Notes

- `run_onchange_` scripts re-run only when their rendered text changes. If a download failed, retry with `chezmoi state delete-bucket --bucket=scriptState && chezmoi apply`.
- Third-party code is pinned: zsh plugins and tmux plugins by tag/commit in `.chezmoiexternal.toml.tmpl`, Neovim plugins by `nvim-pack-lock.json`, Debian binaries by version and sha256.
- `README.md`, `AGENTS.md`, `LICENSE` and `docs/` are repo-only and never deployed to `$HOME`.
