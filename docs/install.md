# Install

> [!WARNING]
> The macOS scripts apply **my** preferences: dark mode, fast key repeat, auto-hiding Dock, a **replaced Dock app list**, menu bar layout and Neovide as the default text editor. Read `.chezmoiscripts/` before applying on your own Mac, or delete what you don't want. To preview everything first: `chezmoi init GeorgopoulosGiannis/dotfiles && chezmoi diff`.

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

`chezmoi init` asks a few questions once and stores the answers in `~/.config/chezmoi/chezmoi.toml` (never committed). Pre-answer them with flags to skip the prompts:

| Prompt | Flag | Effect |
|--------|------|--------|
| `email` | `--promptString email=you@example.com` | Your git email. |
| `work` | `--promptBool work=false` | Work machine. **Answer `false`** unless you've set up your own private work repo (see below). |
| `profile` (Linux only) | `--promptChoice profile=dev` | `dev`: everything incl. Neovim, Node, Go, compilers, Pi. `server`: zsh, tmux, git, vim and CLI tools only. macOS is always `dev`. |

Change an answer later with `chezmoi edit-config`, then `chezmoi diff` and apply.

## Servers

`profile=server` gives a remote Debian box my shell, tmux, git and vim without the dev toolchain (no Neovim, mise or Pi). Install it as your normal user with the Debian commands above.

Provisioning the machine itself (users, SSH hardening, firewall) is deliberately **not** here; see [why](design.md#why-these-choices). If you push from a server, authenticate with `GIT_CONFIG_GLOBAL=~/.config/git/config gh auth setup-git`, so the credential helper goes to `~/.config/git/config` instead of the chezmoi-managed `~/.gitconfig` (git reads both).

## Separate work settings

If you need separate work settings, keep them in a private repo. On machines where you answer `work = true`, chezmoi also clones a private repo to `~/.local/share/dotfiles-work` (set in `.chezmoiexternal.toml.tmpl`, refreshed daily, needs `gh auth login` first). The public config only points at it if it exists:

- `~/.gitconfig` includes its `gitconfig` (per-org work email via `includeIf`)
- `~/.zshrc` sources its `zshrc` (work aliases and PATH additions)
- An after-script runs its optional, idempotent `install.sh` (work-only packages)
- Pi's `settings.json` merges its `pi/settings.json` (work-only packages and skills)

The same flag also picks Pi's default provider and model. To use this, point the external at your own private repo, or delete the block and answer `work=false`.

## chezmoi naming, briefly

Source names map to target files: `dot_zshrc` → `~/.zshrc`, `private_` sets mode 600/700, `executable_` sets +x, `create_` writes a file only if it doesn't exist yet, and `.tmpl` files are [Go templates](https://www.chezmoi.io/user-guide/templating/) rendered per machine. `.chezmoiscripts/run_onchange_*` scripts run on first apply and again whenever their content changes.
