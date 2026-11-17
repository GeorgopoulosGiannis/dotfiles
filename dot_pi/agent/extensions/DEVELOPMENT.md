# Local Pi extension development

The package.json and tsconfig.json in this directory provide a shared editor/type-checking setup for every extension folder here (tsconfig includes `*/**/*.ts` automatically). Node/TypeScript resolve these development dependencies from this parent directory.

## Structure convention

- Each extension is a folder with an `index.ts` entry point (auto-discovered by Pi), plus an optional README.md. See [README.md](README.md) for the index.
- Extensions without third-party runtime dependencies (ask-user-question, custom-header, web-search) need nothing else; they use the shared dev dependencies here.
- An extension with its own runtime dependencies gets its own `package.json` (with a `pi.extensions` entry) and `node_modules`: bash-guard (`shell-quote`) and browser (`playwright-core`).
- web-fetch is fully independent: it has its own package.json, tsconfig.json and `typecheck` script (and is excluded from the shared tsconfig). The root `npm run typecheck` runs both.

Pi provides its SDK and TypeBox at runtime; the development copies here are pinned to match the installed Pi version (currently 1.5.2). They are not runtime dependencies of the extensions. Third-party runtime dependencies remain in each extension's own package.json/node_modules.

## Install and check

From ~/.pi/agent/extensions:

```sh
npm ci --ignore-scripts
npm run typecheck
npm test
```

On a fresh machine, also run npm ci in bash-guard, browser, and web-fetch to install their dependencies. Browser automation additionally needs a compatible installed browser.

npm run typecheck checks all extensions, including web-fetch. npm test runs the web-search tests with mocked HTTP requests (no API key or paid requests).

After editing extensions, use /reload in Pi. Restart Neovim if existing language-server sessions retain stale diagnostics.

## After upgrading Pi

Update @earendil-works/pi-coding-agent and @earendil-works/pi-tui in this directory and in web-fetch to the installed Pi version, and match TypeBox to the version used by that Pi release. Re-run the checks. Development dependency updates are not automatic.
