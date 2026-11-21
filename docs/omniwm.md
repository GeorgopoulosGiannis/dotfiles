# Window manager (OmniWM)

[OmniWM](https://omniwm.app) tiles windows with Hyprland-style Dwindle: each new window splits the focused tile in half, so everything on a workspace stays visible. With apps pinned to workspaces and terminal splits left to tmux, a workspace rarely holds more than a few windows. Any workspace can switch to niri-style scrolling columns instead. The cask is installed only on Apple Silicon with macOS 26+. Grant Accessibility and Input Monitoring on first launch and quit Rectangle or any other window manager.

<kbd>Caps Lock</kbd> is Hyper (<kbd>Ctrl</kbd>+<kbd>Opt</kbd>+<kbd>Cmd</kbd>), so no binding steals <kbd>Option</kbd> from Neovim or typing; add <kbd>Shift</kbd> for the "move" variant.

| Keys (Caps +) | Action |
|---------------|--------|
| `h j k l` | focus (crosses monitors at the edge) |
| `Shift` + `h j k l` | swap the window with its neighbour |
| `Shift` + arrows | join the neighbouring tile as tabs / take a tab back out |
| `1`–`9` / `Shift` + | switch workspace / send window; `Tab` back-and-forth |
| `n` / `p` / `Shift` + | next / previous workspace / send the window there and follow it |
| `e` / `Shift e` | flip the split between side by side and stacked / swap the two sides |
| `-` `=` | shrink / grow the focused window |
| `r` / `Shift r` | cycle sizes; `b` balances all |
| `f` | fullscreen inside the layout |
| `v` / `Shift v` | toggle floating / focus floating windows |
| `Return` | drop-down Ghostty (Quake terminal) |
| `Space` / `o` | command palette / overview |
| `Shift Space` | switch this workspace between dwindle and niri |
| `s` / `Shift s` | scratchpad toggle / assign |
| `m` | focus next monitor |

Niri-only keys, for a workspace switched to niri: `c` center column, `t` tabbed column, `,` `.` pull a window into / push it out of a column, `Shift f` full-width column.

OmniWM's own top bar (OmniShell) is off: its default style replaces the macOS menu bar and, before macOS 27, cannot show third-party icons such as Stats or ClaudeBar. The OmniWM menu bar icon shows the active workspace name instead. If menu bar icons disappear after re-enabling the bar, it may have switched macOS to auto-hide the menu bar (`defaults read NSGlobalDomain _HIHideMenuBar` prints `1`); turn that off in System Settings > Menu Bar.

Workspaces: 1 Term (Ghostty, Neovide), 2 Web, 3 Notes (Obsidian, Things, Anki), 4 Chat (Slack, Discord), 5 Media, 6–9 free. 4 and 5 live on the secondary display when one is connected and fall back to the laptop otherwise.

OmniWM's Settings window rewrites `settings.toml` (dropping comments), so after changing something there run `chezmoi add ~/.config/omniwm/settings.toml`. The generated `shell/` folder and the runtime state in `~/.local/state/omniwm` are not tracked.
