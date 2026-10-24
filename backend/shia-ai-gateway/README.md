# ShiaAi gateway

The small server-side component behind ShiaVerse's **ShiaAi** feature.

The Android app contains **no Gemini API key, no cloud search index and no
book database**. It keeps full-text retrieval on the device (the existing
SQLite collections and FTS index) and only posts:

* the user's question, and
* at most **8 short excerpts** (each capped at 1,200 characters) from passages
  already retrieved on the device,

to this gateway. The gateway holds the Gemini API key as a server-side secret,
forwards the request with a strict grounding prompt, and returns JSON that the
app re-validates before showing anything.

```
Phone (offline corpus + FTS)  ── 8 excerpts + question ──▶  this worker
                                                                │  key stays here
                                                                ▼
                                                            Gemini API
Phone  ◀── {answer, sufficient, used_citation_ids} ─────────────┘
```

Every `used_citation_id` is checked against the ids the phone actually sent;
unknown ids are dropped (here and again in the app), and citations are built
on the device from the real records. The model cannot create a citation.

## Files

| file | purpose |
| --- | --- |
| `worker.js` | The whole service: input validation, prompt construction, Gemini call, error mapping, id re-validation. No storage, no body logging. |
| `wrangler.toml` | Cloudflare Workers configuration (model name only; no secrets). |
| `test/worker.test.mjs` | Node's built-in test runner; mocks the Gemini call. |

## Deploy (Cloudflare Workers, free tier is enough)

```bash
cd backend/shia-ai-gateway
npm install
npx wrangler login                       # one-time browser login
npx wrangler deploy
# Store the key where the worker can read it. This never touches git,
# the APK, the GitHub Actions logs, or the Flutter client:
npx wrangler secret put GEMINI_API_KEY   # paste the Gemini key
# Optional: choose a different model (default: gemini-2.5-flash)
npx wrangler secret put GEMINI_MODEL
```

The deploy output prints the worker URL, e.g.
`https://shia-ai-gateway.<account>.workers.dev`.

### Point the app at it

1. Open the app → **Xplore → ShiaAi → ⚙ ترتیبات** (or Settings →
   **ShiaAi — ذہین سوال و جواب**).
2. Switch on **آن لائن خلاصہ فعال کریں** (explicit consent).
3. Paste the worker HTTPS URL and save.

Until that is done, ShiaAi runs fully offline: it still retrieves and opens the
best local passages, it simply does not produce a synthesized answer.

## Request / response contract

`POST /` with JSON:

```json
{
  "question": "وضو کیسے کریں؟",
  "language": "ur",
  "passages": [
    {
      "citation_id": "alkafi:1234",
      "book_title": "الکافی",
      "chapter_title": "...",
      "section_title": "...",
      "locator": "...",
      "arabic": "...",
      "urdu": "..."
    }
  ]
}
```

Success (`200`):

```json
{
  "sufficient": true,
  "answer": "…اردو جواب…",
  "used_citation_ids": ["alkafi:1234"]
}
```

Failure codes used by the app's graceful states:

| HTTP | meaning in the app |
| --- | --- |
| `400` | malformed request (app shows a service error) |
| `405` | wrong HTTP method |
| `429` | quota exhausted / model unavailable → "حد ختم ہو چکی" state |
| `502` | key rejected, model missing, or bad upstream response |
| `503` | `GEMINI_API_KEY` is not configured on the server |

## Security and dataset rights

* The key is read from the worker's secret store; it is never put in
  `wrangler.toml`, git, logs, or the APK.
* The worker validates and clips every field, caps passages at 8, and stores
  nothing.
* Per `docs/store/dataset-rights-audit.md`, redistribution rights for the Urdu
  corpus are **not cleared**. Sending short retrieved excerpts to Gemini is
  therefore gated behind explicit in-app consent, defaults to off, never
  uploads a full book/database, and should be reviewed with the same care as
  the redistribution question before shipping at scale. Consider adding
  rate limiting (Cloudflare WAF/Workers Rate Limiting) and, if desired, an
  extra shared secret header once the audience grows.
* Twilio is intentionally not involved: it is a messaging/voice channel, not
  an answer-generation or search engine.

## Run the tests

```bash
node --test
```

No dependencies and no network are required — the Gemini call is mocked.

## Hosting elsewhere

The worker is a single stateless `fetch(request, env)` function. The same
logic ports directly to a small Node/Express service, Google Cloud Function or
AWS Lambda as long as: the key comes from the platform's secret manager,
requests are served over HTTPS, and the response keeps the JSON shape above.
