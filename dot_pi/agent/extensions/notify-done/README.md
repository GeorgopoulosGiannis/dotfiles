# notify-done (pi extension)

Tells you when a pi agent needs you, so you can run several agents in tmux panes and look away.

- **Done**: fires on `agent_settled` (after retries, compaction and queued follow-ups). A macOS
  notification with the task, elapsed time and the last assistant message, plus a terminal bell so
  tmux flags the window in the status bar.
- **Waiting**: other extensions (e.g. bash-guard) can request a "waiting on you" notification via
  `pi.events.emit("notify:waiting", { title, message })`.
- **Focus-aware**: no popup if this pane is focused in the frontmost terminal app.
- **pi-interactive-subagents aware**: while subagents are still running, an orchestrator turn ending
  is not "done"; an unanswered subagent question becomes a "waiting" notification.
- **Attention queue**: panes that need you are tracked (waiting first, then done; oldest first) and
  can be jumped to with `queue.sh` or the `/queue` command.
- Clicking a notification focuses the terminal and switches tmux to the originating pane.

## Requirements

- macOS (notifications and focus detection use `osascript` / `lsappinfo`). On other platforms only
  the bell and tmux status message are used.
- tmux (pane tracking, status messages, the queue). Outside tmux you only get plain notifications.
- Optional but recommended: [`terminal-notifier`](https://github.com/julienXX/terminal-notifier)
  (`brew install terminal-notifier`) for click-to-focus and images. Without it, or if its
  notifications are disabled in System Settings, it falls back to `osascript`.

## Terminal app

The terminal hosting tmux is identified by its bundle id (used to focus it on click and to tell
whether you're looking at it). It is taken from `__CFBundleIdentifier`, which macOS sets for apps
launched from the GUI, and defaults to Ghostty (`com.mitchellh.ghostty`) otherwise. To use another
terminal, launch it normally (so the variable is set) or change the fallback `TERMINAL_BUNDLE` in
`index.ts` (find an id with `osascript -e 'id of app "iTerm"'`).

## Configuration (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PI_NOTIFY_SOUND` | `Funk` | Sound when an agent finishes (any macOS system sound, or an `.aiff` in `~/Library/Sounds`) |
| `PI_NOTIFY_WAITING_SOUND` | `Sosumi` | Sound when blocked on you (bash-guard prompt, subagent question) |
| `PI_NOTIFY_IMAGE` | _(none)_ | Image path or URL shown on the notification (terminal-notifier only) |

Run `/reload` in pi after changing them.

## tmux bindings

`queue.sh` reads the queue from tmux global options (`@pi_waiting`, `@pi_done`), so jumping needs
bindings in `~/.tmux.conf` (this repo's `dot_tmux.conf.tmpl` already has them):

```tmux
bind N run-shell -b "~/.pi/agent/extensions/notify-done/queue.sh jump '' '#{client_name}'"
bind Q run-shell -b "~/.pi/agent/extensions/notify-done/queue.sh menu '#{client_name}'"
```

`prefix N` jumps to the next pane that needs you; `prefix Q` shows the queue as a menu.
`/queue` in pi shows the same list.
