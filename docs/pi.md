# Pi coding agent

Managed on `dev` machines: `~/.pi/agent/settings.json` (only the keys set in `modify_settings.json`), `keybindings.json`, local extensions, skills and subagent definitions. Credentials, sessions, caches, installed packages and browser profiles are excluded by `.chezmoiignore` and `.gitignore`.

| Extension | What it does |
|-----------|--------------|
| `ask-user-question` | Lets the agent ask you a question: free text, single or multi-select, with an "other" option |
| `bash-guard` | Prompts before destructive `bash` calls; hard-blocks catastrophic ones in subagents |
| `browser` | Playwright Chromium tools for debugging live web apps (off by default, `/browser on`) |
| `custom-header` | Startup header with a colour ASCII portrait of my dog, generated with ascii_magic |
| [`notify-done`](../dot_pi/agent/extensions/notify-done/README.md) | **Mine.** macOS notification + tmux bell when an agent finishes or needs input, with a queue that jumps you to the right tmux pane |
| `web-fetch` | URL → readable markdown (HTML, PDF, text); public URLs fall back to Jina Reader |
| `web-search` | **Mine.** Web search via Tavily, with bounded output and offline tests |

| Skill | What it does |
|-------|--------------|
| `analyze-sessions` | Cost, prompt-pattern and transcript search over past Pi sessions |
| `pdf-reader` | Text extraction, search and page rendering for PDFs (PyMuPDF) |
| `web-debug` | Playbook for verifying frontend behaviour by driving the live page |
| `youtube-transcript` | Video title and captions as JSON (yt-dlp) |

Packages: [pi-interactive-subagents](https://github.com/amosblomqvist/pi-interactive-subagents) (async subagents in tmux panes) with `scout`, `researcher` and `worker` definitions in `dot_pi/agent/agents`, and [pi-obsidian](https://www.npmjs.com/package/pi-obsidian). See [`dot_pi/agent/extensions/README.md`](../dot_pi/agent/extensions/README.md) for details.

Pi itself is installed separately. After the first apply on a new machine, install the extensions' dependencies (review the manifests first):

```sh
cd ~/.pi/agent/extensions
npm ci --ignore-scripts
for d in bash-guard browser web-fetch; do npm --prefix "$d" ci --ignore-scripts; done
npm run typecheck && npm test
```

Then log in to your provider inside Pi (`/login`). For web search, set `TAVILY_API_KEY` or create `~/.pi/agent/extensions/web-search/auth.json` locally (`chmod 600`); never commit keys.
