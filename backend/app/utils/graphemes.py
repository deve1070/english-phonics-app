"""
Grapheme allow-lists.
=====================
Given the phonemes a child has been taught, decide whether a piece of
text is decodable for them — that is, whether every letter run in it can
be spelled out of sounds they already know.

This started life inside exercise_generation_service as a guardrail
against LLM hallucination. It lives here now because decodable stories
ask exactly the same question of exercises that already exist, and both
callers have to agree: content the generator accepted must not then be
judged undecodable by the story gate, or a child would be shown a story
built from sounds the app itself says they cannot read.

The matching is deliberately coarse. Phoneme symbols in this curriculum
are a mix of letter names ("Aa", "Bb") and IPA ("dʒ", "kʰ"), so all we
can reliably extract is the latin letters in each symbol. That makes the
check a filter for obvious violations, not a phonics engine — it will
pass some words it arguably should not. Erring towards passing is the
right direction: a false reject silently hides content, while a false
accept shows a child a word slightly ahead of them, which is what the
"stretch" slot does on purpose anyway.
"""

import re
from typing import Iterable

from app.models.phoneme import Phoneme


def build_allowed_graphemes(allowed_phonemes: Iterable[Phoneme]) -> set[str]:
    """Latin-letter spellings licensed by a set of taught phonemes.

    Prefers the phoneme's declared `graphemes`. Falls back to inferring
    them from the symbol, which is what this did before the column
    existed: each symbol contributes its letters-only form ("Aa" -> "aa")
    and every character in it ("a").

    The fallback is a guess and a poor one for IPA symbols — /ɪ/ yields
    nothing at all, so a curriculum that spells its sounds in IPA can
    leave whole letters undecodable. Populate `graphemes`; the inference
    is only there so an unmigrated row degrades instead of crashing.
    """
    graphemes: set[str] = set()
    for phoneme in allowed_phonemes:
        declared = (getattr(phoneme, "graphemes", None) or "").strip()
        if declared:
            for spelling in declared.lower().split(","):
                cleaned = re.sub(r"[^a-z]", "", spelling)
                if cleaned:
                    graphemes.add(cleaned)
            continue

        symbol = (phoneme.symbol or "").strip().lower()
        normalized = re.sub(r"[^a-z]", "", symbol)
        if not normalized:
            continue
        graphemes.add(normalized)
        for char in normalized:
            graphemes.add(char)
    return graphemes


def content_is_decodable(content: str, allowed_graphemes: set[str]) -> bool:
    """True if every word in `content` can be segmented into known graphemes.

    Greedy longest-match, left to right. Non-letter characters (spaces,
    full stops, apostrophes) are ignored entirely — punctuation is not
    something a child has to decode.
    """
    words = re.findall(r"[a-z]+", content.lower())
    if not words:
        return True

    max_len = max((len(g) for g in allowed_graphemes), default=1)
    for word in words:
        idx = 0
        while idx < len(word):
            matched = False
            max_window = min(max_len, len(word) - idx)
            for size in range(max_window, 0, -1):
                chunk = word[idx : idx + size]
                if chunk in allowed_graphemes:
                    idx += size
                    matched = True
                    break
            if not matched:
                return False
    return True
