# Window manager (OmniWM)

[OmniWM](https://omniwm.app) tiles windows in niri-style scrolling columns: one or two columns fill the screen and the rest scroll sideways, which suits a laptop better than squeezing everything into a grid. The cask is installed only on Apple Silicon with macOS 26+. Grant Accessibility and Input Monitoring on first launch and quit Rectangle or any other window manager.

<kbd>Caps Lock</kbd> is Hyper (<kbd>Ctrl</kbd>+<kbd>Opt</kbd>+<kbd>Cmd</kbd>), so no binding steals <kbd>Option</kbd> from Neovim or typing; add <kbd>Shift</kbd> for the "move" variant.

| Keys (Caps +) | Action |
|---------------|--------|
| `h j k l` / `Shift` + | focus / move window (crosses monitors at the edge) |
| `1`–`9` / `Shift` + | switch workspace / send window; `Tab` back-and-forth |
| `r` / `Shift r` | cycle column width ⅓ ½ ⅔ |
| `-` `=` / `Shift` + | narrower, wider / shorter, taller |
| `f` / `Shift f` | maximize column / fullscreen |
| `c` `t` `b` | center column, tabbed column, balance sizes |
| `,` `.` | pull window into column / push it out |
| `v` / `Shift v` | toggle floating / focus floating windows |
| `Return` | drop-down Ghostty (Quake terminal) |
| `Space` / `o` / `Shift Space` | command palette / overview / niri ↔ dwindle |
| `s` / `Shift s` | scratchpad toggle / assign |
| `m` | focus next monitor |

Workspaces: 1 Term (Ghostty, Neovide), 2 Web, 3 Notes (Obsidian, Things, Anki), 4 Chat (Slack, Discord), 5 Media, 6–9 free. 4 and 5 live on the secondary display when one is connected and fall back to the laptop otherwise.

OmniWM's Settings window rewrites `settings.toml` (dropping comments), so after changing something there run `chezmoi add ~/.config/omniwm/settings.toml`. The generated `shell/` folder and the runtime state in `~/.local/state/omniwm` are not tracked.
