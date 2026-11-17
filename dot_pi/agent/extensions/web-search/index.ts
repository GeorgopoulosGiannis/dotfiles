import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { Type } from 'typebox';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { search } from './search.ts';

const authPath = fileURLToPath(new URL('./auth.json', import.meta.url));

function loadApiKey(): string | undefined {
  const env = process.env.TAVILY_API_KEY?.trim();
  if (env) return env;
  try {
    const auth = JSON.parse(readFileSync(authPath, 'utf8'));
    return typeof auth.tavily_api_key === 'string' ? auth.tavily_api_key.trim() : undefined;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
    throw new Error('Cannot read web-search/auth.json. Check permissions and JSON syntax; do not paste its contents into chat.');
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: 'web_search',
    label: 'Web Search (Tavily)',
    description: 'Search the public web with Tavily basic search. Returns up to 10 titles, URLs and excerpts, not generated answers or full pages. Excerpts truncate at 1,200 characters and titles at 300. One request normally uses 1 Tavily credit. Optional site restricts results to a domain (a supplied URL is reduced to its hostname).',
    promptSnippet: 'Find public web sources by query; read selected URLs with web_fetch',
    promptGuidelines: [
      'Use web_search to discover sources; use web_fetch when the URL is already known.',
      'Do not send secrets, private code, or confidential company information in web_search queries.',
      'Do not repeatedly retry web_search after authentication, quota, or rate-limit errors.',
    ],
    parameters: Type.Object({
      query: Type.String({ minLength: 1, maxLength: 2000, description: 'Search terms or question. Quoted phrases can request exact matches.' }),
      count: Type.Optional(Type.Integer({ minimum: 1, maximum: 10, description: 'Results to return; defaults to 5.' })),
      site: Type.Optional(Type.String({ description: 'Optional domain restriction, e.g. docs.python.org.' })),
    }),
    async execute(_id, params, signal) {
      const result = await search(params, { apiKey: loadApiKey(), signal });
      return {
        content: [{ type: 'text', text: result.text }],
        details: { provider: 'tavily', searchDepth: 'basic', results: result.results, credits: result.credits },
      };
    },
  });
}
