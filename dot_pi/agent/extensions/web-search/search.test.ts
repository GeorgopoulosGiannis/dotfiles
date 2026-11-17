import test from 'node:test';
import assert from 'node:assert/strict';
import { buildRequest, search } from './search.ts';

const ok = (data: unknown) => new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });

test('request fixes basic search and disables expensive/unneeded features', () => {
  const body = buildRequest({ query: '  TypeScript docs  ', site: 'https://docs.example.com/page' });
  assert.equal(body.query, 'TypeScript docs');
  assert.equal(body.search_depth, 'basic');
  for (const key of ['auto_parameters', 'include_answer', 'include_raw_content', 'include_images'] as const) assert.equal(body[key], false);
  assert.equal(body.max_results, 5);
  assert.deepEqual(body.include_domains, ['docs.example.com']);
});

test('invalid inputs never issue a request', async () => {
  for (const input of [{ query: ' ' }, { query: 'x'.repeat(2001) }, { query: 'x', count: 11 }, { query: 'x', count: 1.5 }, { query: 'x', site: 'file:///etc/passwd' }]) {
    await assert.rejects(search(input, { apiKey: 'fake', fetchImpl: () => assert.fail('Unexpected request') }));
  }
});

test('missing key fails locally with setup instructions', async () => {
  await assert.rejects(search({ query: 'test' }, { fetchImpl: () => assert.fail('Unexpected request') }), /TAVILY_API_KEY/);
});

test('POST authenticates in header and returns bounded excerpts with credits', async () => {
  const result = await search({ query: 'docs', count: 1 }, {
    apiKey: 'fake-test-key',
    fetchImpl: async (url, options) => {
      assert.equal(url, 'https://api.tavily.com/search');
      assert.ok(options);
      assert.equal(options.method, 'POST');
      assert.equal(options.redirect, 'error');
      assert.equal(new Headers(options.headers).get('Authorization'), 'Bearer fake-test-key');
      assert.equal(typeof options.body, 'string');
      assert.ok(!String(options.body).includes('fake-test-key'));
      return ok({ usage: { credits: 1 }, results: [
        { title: 'T'.repeat(400), url: 'https://example.com', content: 'S'.repeat(2000), raw_content: 'NOT RETURNED' },
        { title: 'extra', url: 'https://other.example.com', content: 'not returned' },
      ] });
    },
  });
  assert.equal(result.results.length, 1);
  assert.ok(result.results[0].snippet.endsWith('[truncated]'));
  assert.ok(result.results[0].title.endsWith('[truncated]'));
  assert.equal(result.credits, 1);
  assert.ok(!JSON.stringify(result).includes('fake-test-key'));
  assert.ok(!result.text.includes('NOT RETURNED'));
});

test('empty results are not an error', async () => {
  const result = await search({ query: 'docs' }, { apiKey: 'fake', fetchImpl: async () => ok({ results: [] }) });
  assert.match(result.text, /No results found/);
});

test('malformed items and non-web URLs are discarded', async () => {
  const result = await search({ query: 'docs' }, { apiKey: 'fake', fetchImpl: async () => ok({ results: [null, {}, { url: 'javascript:alert(1)' }, { url: 'https://example.com' }] }) });
  assert.deepEqual(result.results, [{ title: '', url: 'https://example.com', snippet: '' }]);
});

test('HTTP failures do not leak bodies or retry', async () => {
  for (const status of [401, 403, 429, 432, 433, 500]) {
    let calls = 0;
    await assert.rejects(search({ query: 'test' }, {
      apiKey: 'fake', fetchImpl: async () => { calls++; return new Response('SECRET SERVER BODY', { status }); },
    }), (error) => error instanceof Error && error.message.includes(`HTTP ${status}`) && !error.message.includes('SECRET'));
    assert.equal(calls, 1);
  }
});

test('invalid JSON and response shapes are reported', async () => {
  for (const response of [new Response('not json'), ok({ error: 'bad' })]) {
    await assert.rejects(search({ query: 'test' }, { apiKey: 'fake', fetchImpl: async () => response }), /invalid JSON|unexpected response/);
  }
});

test('network errors are sanitized', async () => {
  await assert.rejects(search({ query: 'test' }, { apiKey: 'fake', fetchImpl: async () => { throw new Error('SECRET'); } }), /Could not reach Tavily/);
});

test('pre-cancelled work never issues a request', async () => {
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(search({ query: 'test' }, { apiKey: 'fake', signal: controller.signal, fetchImpl: () => assert.fail('Unexpected request') }));
});

test('in-flight cancellation and timeout are supported', async () => {
  const blockedFetch: typeof fetch = async (_url, options) => new Promise<Response>((_resolve, reject) => {
    const signal = options!.signal!;
    const timer = setTimeout(() => reject(new Error('test failed to abort')), 1000);
    signal.addEventListener('abort', () => { clearTimeout(timer); reject(signal.reason); }, { once: true });
  });
  await assert.rejects(search({ query: 'test' }, { apiKey: 'fake', timeoutMs: 10, fetchImpl: blockedFetch }), /timed out/);
  const controller = new AbortController();
  const pending = search({ query: 'test' }, { apiKey: 'fake', signal: controller.signal, fetchImpl: blockedFetch });
  controller.abort();
  await assert.rejects(pending, /cancelled/);
});
