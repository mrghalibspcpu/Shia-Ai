# Local retrieval API

Prepare the source corpus and run the standard-library HTTP service:

```sh
python3 scripts/prepare_databases.py
python3 -m shia_ai.api
```

It listens on `0.0.0.0:8000` by default. The first startup creates an FTS5 cache under `.cache/shia-ai/`; the 14 original SQLite files remain read-only. Arabic/Urdu matching folds common letter variants and diacritics while preserving the source records.

## `POST /api/search`

Request:

```json
{"query":"الشيخ السعيد","limit":5}
```

The response contains `matches[]`, each with the original Arabic and Urdu text, database-local locator, stable `book` key, `reader_target`, and `shiaai://reader?...` link. In the Flutter app the corresponding Check/action routes directly to the exact record.

## `POST /api/chat`

Request:

```json
{
  "question":"امیرالمومنین علیہ السلام کے بارے میں روایت کیا کہتی ہے؟",
  "session_id":"a-client-generated-id",
  "history":[],
  "reader_context":"کتاب: الکافی؛ باب: فضائل العلم؛ حدیث نمبر: 9001",
  "reader_target":{"book":"alkafi","record_id":9001},
  "limit":6
}
```

`reader_context` and `reader_target` are optional. The target lets the service add the exact active reader record to its grounded candidate set, so a question such as “explain this” can still use the record the reader was viewing. The response contains an answer and structured `sources[]` with `[R#]` markers and reader targets; the Flutter chat renders each source as an interactive Check button.

Retrieval first selects a shortlist with local normalized FTS5; when Gemini is configured, multilingual embeddings can rerank that shortlist before generation. This is hybrid shortlist reranking, not a precomputed vector index over every database row. Without `GEMINI_API_KEY`, `/api/chat` returns `503 gemini_unavailable` rather than an ungrounded answer. `/api/search` remains local and does not require Gemini.

The Flutter client can also use a **user-supplied Google AI Studio key** (`AIza…`) stored only in Android secure storage. In that mode search stays on-device and Gemini is called directly from the phone; no backend URL is required. Keys are never compiled into the APK.

For a hosted backend, set `GEMINI_API_KEY` and `SHIA_API_TOKEN` in the server environment. When a token is configured, send it as `Authorization: Bearer <token>` to `/api/chat`. A shared service token is still not strong public-client authentication; use deployment-appropriate identity, rate limits, and abuse controls before public release. The generator tries `gemini-2.0-flash`, then `gemini-2.5-flash` and other Flash aliases if a model id is missing for that key.
