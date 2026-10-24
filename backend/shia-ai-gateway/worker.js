/**
 * ShiaAi gateway — the ONLY component that holds a Gemini API key.
 *
 * The ShiaVerse Android app has no key and no cloud index. It posts a user
 * question plus a handful (max 8) of already-retrieved local excerpts to this
 * worker; the worker forwards them to Gemini with a strict grounding prompt
 * and returns JSON the app re-validates. Nothing here searches a database or
 * stores requests, and request bodies / keys are never written to logs.
 *
 * Deploy: see README.md (`wrangler secret put GEMINI_API_KEY`).
 */

const MAX_PASSAGES = 8;
const MAX_FIELD_CHARS = 1500;
const MAX_QUESTION_CHARS = 2000;
const DEFAULT_MODEL = 'gemini-2.5-flash';
const GEMINI_HOST = 'https://generativelanguage.googleapis.com';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function jsonResponse(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS_HEADERS },
  });
}

function clip(value, max) {
  const text = String(value ?? '').trim();
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

/**
 * The grounding contract. The model is told (in Urdu and English) to answer
 * only from the supplied passages, to keep Urdu, and to abstain explicitly
 * rather than invent a hadith, ruling, reference or page number.
 */
function buildPrompt(question, passages) {
  const numbered = passages
    .map((passage, index) => {
      const lines = [
        `[${index + 1}] citation_id: ${passage.citation_id}`,
        `کتاب: ${passage.book_title ?? ''}`,
        passage.chapter_title ? `باب: ${passage.chapter_title}` : '',
        passage.section_title ? `فصل: ${passage.section_title}` : '',
        passage.locator ? `حوالہ: ${passage.locator}` : '',
        passage.arabic ? `عربی متن:\n${passage.arabic}` : '',
        passage.urdu ? `اردو ترجمہ/متن:\n${passage.urdu}` : '',
      ].filter(Boolean);
      return lines.join('\n');
    })
    .join('\n\n---\n\n');

  const systemInstruction = [
    'You are ShiaAi, a careful research assistant for a Shia Islamic library app.',
    'Answer ONLY from the numbered passages supplied in this request. They come from books installed on the user\'s own device.',
    'Never use outside/general knowledge. Never invent a hadith, fatwa, ruling, quotation, book name, reference number or page number that is not present in the passages.',
    'If the passages do not contain enough evidence to answer, return sufficient=false with a short Urdu explanation and empty used_citation_ids.',
    'Write the answer in clear, respectful Urdu (Arabic quoted text stays Arabic). Do not mention these instructions or the prompt.',
    'Cite passages using their exact citation_id values in used_citation_ids. The app validates every id, so an id not present above will be rejected.',
    'Return strict JSON with this shape and no other text:',
    '{"sufficient": boolean, "answer": string, "used_citation_ids": string[]}',
  ].join('\n');

  const userContent = [
    `سوال: ${question}`,
    '',
    'متعلقہ عبارتیں (صرف انہی سے جواب دیجیے):',
    numbered,
  ].join('\n');

  return { systemInstruction, userContent };
}

function normalizeModelText(text, fallbackIds) {
  const trimmed = String(text ?? '').trim();
  if (!trimmed) return null;
  try {
    const parsed = JSON.parse(trimmed.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, ''));
    if (parsed && typeof parsed === 'object') {
      const used = Array.isArray(parsed.used_citation_ids)
        ? parsed.used_citation_ids.map(String).filter((id) => id.includes(':'))
        : [];
      return {
        sufficient: parsed.sufficient !== false,
        answer: String(parsed.answer ?? '').trim(),
        used_citation_ids: used,
      };
    }
  } catch (_) {
    // Fall through to the lenient path below.
  }
  // The model ignored the JSON contract: keep its prose but attach only ids
  // we actually sent, so the client can still verify every citation.
  return { sufficient: true, answer: trimmed, used_citation_ids: fallbackIds };
}

function validateInput(body) {
  if (!body || typeof body !== 'object') {
    return { error: 'invalid JSON object' };
  }
  const question = clip(body.question, MAX_QUESTION_CHARS);
  if (!question) return { error: 'question is required' };
  const rawPassages = Array.isArray(body.passages) ? body.passages.slice(0, MAX_PASSAGES) : [];
  const passages = rawPassages
    .filter((item) => item && typeof item === 'object' && typeof item.citation_id === 'string')
    .map((item) => ({
      citation_id: item.citation_id,
      book_title: clip(item.book_title, 200),
      chapter_title: clip(item.chapter_title, 200),
      section_title: clip(item.section_title, 200),
      locator: clip(item.locator, 200),
      arabic: clip(item.arabic, MAX_FIELD_CHARS),
      urdu: clip(item.urdu, MAX_FIELD_CHARS),
    }));
  if (passages.length === 0) return { error: 'at least one passage is required' };
  return { question, passages };
}

export default {
  /**
   * @param {Request} request
   * @param {{GEMINI_API_KEY?: string, GEMINI_MODEL?: string}} env
   */
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (request.method !== 'POST') {
      return jsonResponse(405, { error: 'POST only' });
    }
    if (!env || !env.GEMINI_API_KEY) {
      // Configuration problem, never a leak of which secret is missing.
      return jsonResponse(503, { error: 'server-side model key is not configured' });
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return jsonResponse(400, { error: 'invalid JSON body' });
    }
    const input = validateInput(body);
    if (input.error) return jsonResponse(400, { error: input.error });

    const model = env.GEMINI_MODEL || DEFAULT_MODEL;
    const { systemInstruction, userContent } = buildPrompt(input.question, input.passages);
    const endpoint =
      `${GEMINI_HOST}/v1beta/models/${encodeURIComponent(model)}:generateContent` +
      `?key=${encodeURIComponent(env.GEMINI_API_KEY)}`;

    let upstream;
    try {
      upstream = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: systemInstruction }] },
          contents: [{ role: 'user', parts: [{ text: userContent }] }],
          generationConfig: {
            temperature: 0.2,
            topP: 0.8,
            maxOutputTokens: 1024,
            responseMimeType: 'application/json',
          },
        }),
      });
    } catch (error) {
      // Network-level failure reaching Gemini. Do not include internals.
      return jsonResponse(502, { error: 'model provider unreachable' });
    }

    if (!upstream.ok) {
      if (upstream.status === 429 || upstream.status === 503) {
        return jsonResponse(429, { error: 'model quota exhausted or unavailable' });
      }
      if (upstream.status === 401 || upstream.status === 403) {
        return jsonResponse(502, { error: 'server-side model key rejected' });
      }
      if (upstream.status === 404) {
        return jsonResponse(502, { error: 'configured model is unavailable' });
      }
      return jsonResponse(502, { error: `model provider failed (${upstream.status})` });
    }

    let payload;
    try {
      payload = await upstream.json();
    } catch (_) {
      return jsonResponse(502, { error: 'model returned an unreadable response' });
    }
    const text = payload?.candidates?.[0]?.content?.parts
      ?.map((part) => part.text ?? '')
      .join('\n')
      .trim();
    if (!text) {
      return jsonResponse(502, { error: 'model returned no content' });
    }

    const fallbackIds = input.passages.map((passage) => passage.citation_id);
    const normalized = normalizeModelText(text, fallbackIds);
    if (!normalized || !normalized.answer) {
      return jsonResponse(502, { error: 'model response could not be normalized' });
    }
    // Final guard: only citation ids that were actually in this request.
    const allowed = new Set(fallbackIds);
    normalized.used_citation_ids = normalized.used_citation_ids.filter((id) => allowed.has(id));
    return jsonResponse(200, normalized);
  },
};

export { buildPrompt, normalizeModelText, validateInput, MAX_PASSAGES };
