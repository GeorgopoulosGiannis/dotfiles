# diagrams

Interactive [Archify](https://github.com/tt-a1i/archify) diagrams shown as part of the conversation.

- **`diagram` tool**: the agent writes Archify JSON (architecture, workflow, sequence, dataflow,
  lifecycle, erd, class, tree, timeline, waterfall). The extension runs `archify finalize`,
  takes a headless-Chrome screenshot, and shows that preview inline in the terminal through the
  kitty or iTerm2 image protocol. On failure, the diagnostics go back to the agent so it can
  repair the spec.
- **Live viewer**: a loopback page (`http://127.0.0.1:<port>`) lists the session's diagrams and
  switches to each new one over SSE. It opens automatically for the first diagram, and again
  whenever no viewer tab is connected. Keep it next to pi.
- **`/diagram auto|always|off`**: in `auto`, the agent decides when a diagram helps. `always`
  asks for one with every substantive answer. `off` deactivates the tool. The mode is stored in
  the session.
- **`/diagrams`**: open the viewer, or pick one of this session's diagrams.

Artifacts go to `~/.cache/pi-diagrams/<session-id>/` (override with `PI_DIAGRAMS_DIR`), never into
the project. The server stays up across `/new` and `/resume`, so the browser tab survives, and
stops on quit or `/reload`.

Requirements: the archify skill at `~/.agents/skills/archify` (override with `ARCHIFY_DIR`) and
Chrome or Chromium (override with `ARCHIFY_CHROME`). Without Chrome, the inline preview is
skipped and archify's own browser check fails.
