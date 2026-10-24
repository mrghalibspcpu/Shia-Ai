import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';

import worker, {
  buildPrompt,
  normalizeModelText,
  validateInput,
  MAX_PASSAGES,
} from '../worker.js';

const samplePassage = (id) => ({
  citation_id: id,
  book_title: 'الکافی',
  chapter_title: 'باب',
  section_title: 'فصل',
  locator: 'حدیث نمبر ۵',
  arabic: 'المتن العربي',
  urdu: 'اردو ترجمہ',
});

const sampleBody = () => ({
  question: 'وضو کیسے کریں؟',
  language: 'ur',
  passages: [samplePassage('alkafi:12'), samplePassage('quran:5')],
});

let calls = [];
let originalFetch;

beforeEach(() => {
  calls = [];
  originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), init });
    return new Response(
      JSON.stringify({
        candidates: [
          { content: { parts: [{ text: JSON.stringify({
            sufficient: true,
            answer: 'وضو کا طریقہ یہ ہے…',
            used_citation_ids: ['alkafi:12'],
          }) }] } },
        ],
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  };
});

afterEach(() => {
  globalThis.fetch = originalFetch;
});

test('validateInput rejects empty bodies and missing passages', () => {
  assert.equal(validateInput({}).error, 'question is required');
  assert.equal(validateInput({ question: 'x' }).error, 'at least one passage is required');
  assert.equal(
    validateInput({ question: 'x', passages: [{ book_title: 'no id' }] }).error,
    'at least one passage is required',
  );
});

test('validateInput caps passage count and per-field length', () => {
  const passages = Array.from({ length: MAX_PASSAGES + 5 }, (_, index) =>
    samplePassage(`book:${index}`),
  );
  const result = validateInput({ question: 'سوال', passages });
  assert.equal(result.error, undefined);
  assert.equal(result.passages.length, MAX_PASSAGES);
  const long = validateInput({
    question: 'x',
    passages: [{ ...samplePassage('b:1'), urdu: 'م'.repeat(5000) }],
  });
  assert.equal(long.passages[0].urdu.length, 1501); // 1500 + ellipsis
});

test('buildPrompt embeds every citation id and the grounding rules', () => {
  const { systemInstruction, userContent } = buildPrompt('سوال', [
    samplePassage('alkafi:12'),
  ]);
  assert.match(systemInstruction, /ONLY from the numbered passages/);
  assert.match(systemInstruction, /Never invent/);
  assert.match(systemInstruction, /used_citation_ids/);
  assert.match(userContent, /alkafi:12/);
  assert.match(userContent, /اردو ترجمہ/);
});

test('normalizeModelText parses strict JSON and fenced JSON', () => {
  const strict = normalizeModelText(
    JSON.stringify({ sufficient: false, answer: 'کافی مواد نہیں', used_citation_ids: [] }),
    ['a:1'],
  );
  assert.equal(strict.sufficient, false);
  assert.equal(strict.answer, 'کافی مواد نہیں');
  const fenced = normalizeModelText('```json\n{"sufficient":true,"answer":"جواب","used_citation_ids":["a:1"]}\n```', ['a:1']);
  assert.equal(fenced.answer, 'جواب');
  assert.deepEqual(fenced.used_citation_ids, ['a:1']);
});

test('normalizeModelText falls back to prose but keeps only sent ids', () => {
  const result = normalizeModelText('plain prose answer', ['a:1', 'a:2']);
  assert.equal(result.sufficient, true);
  assert.equal(result.answer, 'plain prose answer');
  assert.deepEqual(result.used_citation_ids, ['a:1', 'a:2']);
  assert.equal(normalizeModelText('   ', ['a:1']), null);
});

test('worker answers CORS preflight and rejects non-POST verbs', async () => {
  const preflight = await worker.fetch(new Request('https://gw/', { method: 'OPTIONS' }), {});
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('Access-Control-Allow-Origin'), '*');
  const get = await worker.fetch(new Request('https://gw/'), { GEMINI_API_KEY: 'k' });
  assert.equal(get.status, 405);
});

test('worker refuses to run without a server-side key and never calls the model', async () => {
  const response = await worker.fetch(
    new Request('https://gw/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(sampleBody()),
    }),
    {},
  );
  assert.equal(response.status, 503);
  const payload = await response.json();
  assert.match(payload.error, /key is not configured/);
  assert.equal(calls.length, 0);
});

test('happy path: excerpts are posted and the reply is re-validated', async () => {
  const response = await worker.fetch(
    new Request('https://gw/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(sampleBody()),
    }),
    { GEMINI_API_KEY: 'secret-key', GEMINI_MODEL: 'gemini-test' },
  );
  assert.equal(response.status, 200);
  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /models\/gemini-test:generateContent/);
  assert.match(calls[0].url, /key=secret-key/);
  // The full database is never sent: only the two short excerpts, identified
  // by their real citation ids, plus the grounding instruction.
  const upstreamBody = JSON.parse(calls[0].init.body);
  const userText = upstreamBody.contents[0].parts[0].text;
  assert.match(userText, /alkafi:12/);
  assert.match(userText, /quran:5/);
  assert.match(userText, /وضو کیسے کریں/);
  assert.equal(upstreamBody.system_instruction.parts[0].text.includes('Never invent'), true);
  const payload = await response.json();
  assert.equal(payload.answer, 'وضو کا طریقہ یہ ہے…');
  assert.deepEqual(payload.used_citation_ids, ['alkafi:12']);
});

test('unknown citation ids returned by the model are filtered out', async () => {
  globalThis.fetch = async () => new Response(
    JSON.stringify({
      candidates: [{ content: { parts: [{ text: JSON.stringify({
        sufficient: true,
        answer: 'جواب',
        used_citation_ids: ['alkafi:12', 'made-up:999'],
      }) }] } }],
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
  const response = await worker.fetch(
    new Request('https://gw/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(sampleBody()),
    }),
    { GEMINI_API_KEY: 'k' },
  );
  const payload = await response.json();
  assert.deepEqual(payload.used_citation_ids, ['alkafi:12']);
});

test('upstream 429 maps to 429 and 401 maps to a key rejection', async () => {
  globalThis.fetch = async () => new Response('{}', { status: 429 });
  let response = await worker.fetch(
    new Request('https://gw/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(sampleBody()),
    }),
    { GEMINI_API_KEY: 'k' },
  );
  assert.equal(response.status, 429);

  globalThis.fetch = async () => new Response('{}', { status: 401 });
  response = await worker.fetch(
    new Request('https://gw/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(sampleBody()),
    }),
    { GEMINI_API_KEY: 'k' },
  );
  assert.equal(response.status, 502);
  assert.match((await response.json()).error, /key rejected/);
});

test('network failure reaching the model becomes a 502, not a crash', async () => {
  globalThis.fetch = async () => {
    throw new Error('dial tcp: no route');
  };
  const response = await worker.fetch(
    new Request('https://gw/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(sampleBody()),
    }),
    { GEMINI_API_KEY: 'k' },
  );
  assert.equal(response.status, 502);
  assert.match((await response.json()).error, /unreachable/);
});
