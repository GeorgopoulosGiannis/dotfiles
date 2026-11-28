# Pi extensions

Local extensions, auto-discovered from `~/.pi/agent/extensions/*/index.ts` (use `/reload` after
editing). Each lives in its own folder. For type-checking and tests, see [DEVELOPMENT.md](DEVELOPMENT.md).

`ask-user-question`, `bash-guard`, `browser` and `web-fetch` (and all skills in `../skills/`) come from
[amosblomqvist/pi-config](https://github.com/amosblomqvist/pi-config) with small changes, and
`custom-header` started from it. `notify-done` and `web-search` are my own.

| Extension | Description |
|---|---|
| [`ask-user-question`](ask-user-question/index.ts) | `ask_user_question` tool: the agent asks you a single question (free text, single- or multi-select, with an "other" option). |
| [`bash-guard`](bash-guard/README.md) | Prompts before destructive/questionable `bash` calls in the main session; hard-blocks catastrophic ones in subagents. `/bash-guard` toggles it. |
| [`browser`](browser/README.md) | Playwright-driven headless Chromium tools (`browser_*`) for debugging live web apps; off by default, enabled per session with `/browser on`. |
| [`custom-header`](custom-header/index.ts) | Startup header with a "binary π" logo; `/builtin-header` restores the default. |
| [`diagrams`](diagrams/README.md) | `diagram` tool: interactive Archify diagrams with an inline terminal preview and a live browser viewer; `/diagram auto\|always\|off`, `/diagrams`. |
| [`notify-done`](notify-done/README.md) | macOS notification + tmux bell when an agent finishes or needs you, plus a jumpable attention queue (`/queue`, tmux `prefix N`/`Q`). |
| [`web-fetch`](web-fetch/README.md) | `web_fetch` tool: URL → readable markdown (HTML, PDF, text), with a guarded Jina Reader fallback. |
| [`web-search`](web-search/README.md) | `web_search` tool backed by Tavily basic search (needs `TAVILY_API_KEY`). |

## Packages

Third-party Pi packages installed through the `packages` array of `settings.json` (managed by
[`modify_settings.json`](../modify_settings.json) in the dotfiles source):

- [`git:github.com/amosblomqvist/pi-interactive-subagents`](https://github.com/amosblomqvist/pi-interactive-subagents) —
  async, interactive subagents in tmux panes, steered and resumed by name. A fork of
  [HazAT/pi-interactive-subagents](https://github.com/HazAT/pi-interactive-subagents) with a smaller tool
  surface; the `scout`, `researcher` and `worker` agents in `../agents/` are based on its bundled agents.
- [`npm:pi-obsidian`](https://www.npmjs.com/package/pi-obsidian) — read, write, search and visualize
  Obsidian vaults.

Machine-specific packages (work machines) are appended by `modify_settings.json` from a private fragment.
