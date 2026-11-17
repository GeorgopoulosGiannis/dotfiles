# web-fetch (pi extension)

Registers a `web_fetch` tool that fetches a URL and returns readable markdown.

- HTML → [Readability](https://github.com/mozilla/readability) + [Turndown](https://github.com/mixmark-io/turndown) markdown;
  Next.js RSC payloads are parsed when Readability finds nothing.
- PDFs (first 100 pages, max 20 MB) via `unpdf`; other text types are returned as-is.
- Responses over 5 MB, and binary/media types, are rejected. Requests time out after 30 s.

Requests are sent directly from your machine with a desktop-browser `User-Agent`
(a Chrome-on-macOS string) and browser-like `Accept*`/`Sec-Fetch-*` headers, because many sites
reject unidentified clients.

## Jina Reader fallback

If the direct fetch fails or yields little content (e.g. a JavaScript-rendered page), the tool
retries through the third-party [Jina Reader](https://jina.ai/reader/) service (`https://r.jina.ai/<url>`),
which renders the page remotely. **That sends the URL to Jina**, so the fallback is skipped for:

- non-`http(s)` URLs and URLs containing credentials,
- `localhost`, loopback, private (RFC 1918), link-local and CGNAT IP addresses (IPv4 and IPv6),
- intranet-style hostnames: single-label names and `.local`, `.internal`, `.intranet`, `.lan`,
  `.corp`, `.home`, `.home.arpa`, `.localhost`.

Those URLs are still fetched directly; only the fallback is disabled. Public URLs that are
sensitive in other ways (e.g. pre-signed links) are not detected, so avoid fetching them.

## Development

Independent of the shared dev setup in the parent directory: it has its own `package.json`, runtime
dependencies and `typecheck` script. Install with `npm ci` in this directory.
