# Web search — Tavily

A global Pi extension exposing `web_search`. Reads `TAVILY_API_KEY` from Pi's process environment, or `auth.json` alongside `index.ts` containing `{"tavily_api_key":"YOUR_KEY"}`. Environment takes precedence. No credentials are loaded until a search is executed.

## Setup

1. Create a free account at https://app.tavily.com and get an API key from its dashboard. Keep the free plan; do not enable paid billing unless you intend to pay.
2. In your terminal, run `read -s 'TAVILY_API_KEY?Tavily API key: '; echo; export TAVILY_API_KEY` (zsh). This prompts without showing the key or putting it in the command history.
3. Launch `pi` from that terminal. Use `/reload` if Pi was already running with that environment. An existing process cannot inherit environment variables exported later in another terminal.
4. Ask: `Search the web for the official TypeScript documentation.`

Alternatively, for persistence without shell configuration, create `~/.pi/agent/extensions/web-search/auth.json` yourself in a trusted editor using the JSON shape above, then `chmod 600 ~/.pi/agent/extensions/web-search/auth.json`. This file contains a plaintext secret; exclude it from backups or repositories you share. It is read on each search, so no restart is needed after changing it. Never paste the key into chat or put it in a search query.

Live searches require a valid key; without one the tool returns a configuration error. Do not edit Pi's main `auth.json` for this extension.

## Usage and limits

- Natural language requests can invoke `web_search`.
- Tool arguments: required `query`, optional `count` (1–10, default 5), optional `site` (domain restriction).
- A URL supplied to `site` is reduced to its hostname; paths are not filters.
- Exactly one basic search request per tool invocation; no automatic retries, advanced search, generated answers, images, or full-page content.
- Search excerpts are capped at 1,200 characters each; titles at 300; queries at 2,000. Omitted excerpt/title text is marked. At most ten results are returned, keeping output below Pi's default 50 KB limit.
- Use the separate `web_fetch` tool to read full pages.
- Requests have a 20-second deadline and support cancellation.
- Credit usage is included when Tavily reports it. This is diagnostic information, not Pi model-token billing.
- Search terms go to Tavily. Do not submit confidential company data or secrets. Returned webpage excerpts are untrusted content.
- HTTP and network errors are sanitized; raw error bodies and API keys are not included in results. Authentication/quota errors are not retried automatically.

At the time of writing, Tavily offers 1,000 free credits/month without a credit card, with basic search using one credit. Provider pricing can change: https://docs.tavily.com/documentation/api-credits . The extension does not impose an account-wide spending cap; control paid billing in the Tavily dashboard.

## Structure

- `index.ts`: Pi registration, input schema, credential lookup, tool result adapter.
- `search.ts`: dependency-free HTTP client, input checks, fixed low-cost request settings, bounded output and sanitized errors.
- `search.test.ts`: offline Node tests with mocked HTTP responses; no key, API credits or model calls needed.
- `README.md`: setup and maintenance instructions.
- `auth.json`: optional user-created secret; not supplied with the extension.

Run tests: `npm test` from `~/.pi/agent/extensions` (or `node --experimental-strip-types --test web-search/search.test.ts`).

No runtime npm install is needed: Pi loads the TypeScript and supplies TypeBox and its extension API; `search.ts` uses only Node's built-in `fetch`. Running the tests directly requires Node 22.6+ (`--experimental-strip-types`; unflagged from 22.18), which strips types without type checking (use `npm run typecheck` for that). Pi auto-discovers `index.ts`; the helper and test files do not register extensions.

Disable through `pi config`, or add `-extensions/web-search/index.ts` to the `extensions` array in `~/.pi/agent/settings.json`, then `/reload`. Re-enable by removing that exclusion and reloading.
