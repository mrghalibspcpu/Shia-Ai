"""Optional Gemini-embedding reranker for local FTS candidate passages."""
from __future__ import annotations

import hashlib
import math
import threading
from collections import OrderedDict
from dataclasses import replace
from typing import Callable

from .gemini import embed_texts
from .search import Passage

_CACHE_LIMIT = 2048
_EMBEDDING_CACHE: OrderedDict[str, list[float]] = OrderedDict()
_CACHE_LOCK = threading.Lock()


def _passage_text(passage: Passage) -> str:
    pieces = [passage.chapter_title, passage.section_title, passage.arabic, passage.urdu]
    return "\n".join(piece.strip()[:4000] for piece in pieces if piece and piece.strip())


def _cache_key(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _cosine(left: list[float], right: list[float]) -> float:
    if not left or len(left) != len(right):
        return 0.0
    dot = sum(a * b for a, b in zip(left, right))
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    if left_norm == 0.0 or right_norm == 0.0:
        return 0.0
    return dot / (left_norm * right_norm)


def rerank_semantically(
    question: str,
    passages: list[Passage],
    *,
    embedder: Callable[[list[str]], list[list[float]]] = embed_texts,
) -> list[Passage]:
    """Rerank FTS candidates using multilingual Gemini embeddings.

    Candidate recall still comes from the local normalized FTS5 index; embedding
    calls only rerank that shortlist and never invent or alter source locators.
    Passage vectors are held in a bounded process-local cache to avoid repeatedly
    embedding the same records during a chat session.
    """
    if len(passages) < 2:
        return passages
    texts = [_passage_text(passage) for passage in passages]
    keys = [_cache_key(text) for text in texts]
    with _CACHE_LOCK:
        cached = {key: _EMBEDDING_CACHE[key] for key in keys if key in _EMBEDDING_CACHE}
        for key in cached:
            _EMBEDDING_CACHE.move_to_end(key)
    missing_keys = list(dict.fromkeys(key for key in keys if key not in cached))
    key_to_text = {key: text for key, text in zip(keys, texts)}
    vectors_by_key = dict(cached)

    # Gemini's first vector is marked as a retrieval query; the rest are docs.
    texts_to_embed = [question[:4000], *(key_to_text[key] for key in missing_keys)]
    vectors = embedder(texts_to_embed)
    if len(vectors) != len(texts_to_embed):
        raise ValueError("Embedding service returned a mismatched vector count")
    query_vector = vectors[0]
    vectors_by_key.update(zip(missing_keys, vectors[1:]))
    with _CACHE_LOCK:
        for key in missing_keys:
            _EMBEDDING_CACHE[key] = vectors_by_key[key]
            _EMBEDDING_CACHE.move_to_end(key)
        while len(_EMBEDDING_CACHE) > _CACHE_LIMIT:
            _EMBEDDING_CACHE.popitem(last=False)

    max_lexical = max((passage.relevance for passage in passages), default=0.0)
    reranked: list[Passage] = []
    for passage, key in zip(passages, keys):
        semantic_similarity = (_cosine(query_vector, vectors_by_key[key]) + 1.0) / 2.0
        lexical_score = passage.relevance / max_lexical if max_lexical > 0 else 0.0
        hybrid_score = 0.75 * semantic_similarity + 0.25 * lexical_score
        reranked.append(replace(passage, relevance=hybrid_score))
    return sorted(reranked, key=lambda passage: passage.relevance, reverse=True)
