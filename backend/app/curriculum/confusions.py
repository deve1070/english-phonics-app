"""
Which sounds a child is likely to mix up.
=========================================
The distractors in a recognition question decide whether the child learns
anything. Offering /sh/ against /z/ teaches nothing — the answer falls out
without the mapping being consulted at all. Offering /sh/ against /ch/ is
where the work happens, because that is a distinction the child does not
yet reliably hold.

Two kinds of confusion are listed here and they are not the same thing:

  - **Visual**: the letters look alike. b/d/p/q is the famous one, and it
    is a shape problem, not a hearing problem.
  - **Auditory**: the sounds are close. Voiced/unvoiced pairs (b/p, d/t,
    g/k, f/v, s/z, th), the nasals, the short vowels, l/r.

Both belong in a distractor set, because both are real failure modes for
a beginning reader and this exercise is the one place the app can tell
them apart: a child who mixes up b and d visually but never confuses the
sounds is a different case from one who cannot hear the difference, and
the answers they give here say which.

Keyed by grapheme rather than by symbol. The curriculum records symbols
inconsistently — letter names for some sounds, IPA for others — but every
phoneme now carries an explicit spelling, and the spelling is what the
child is looking at.

This table is the starting point, not the final word. Once a child has a
history, their own wrong answers are better evidence than anything
written here, and the round builder prefers them.
"""

# Each entry lists the graphemes a learner plausibly reaches for instead.
# Deliberately not symmetric-by-construction — b is a common wrong answer
# for d, and the reverse is also true, but that is not automatic for every
# pair, so both directions are written where both are real.
CONFUSABLE_GRAPHEMES: dict[str, tuple[str, ...]] = {
    # ── Letter shapes that mirror or rotate into each other ──────
    "b": ("d", "p", "q"),
    "d": ("b", "p", "q", "t"),
    "p": ("q", "b", "d"),
    "q": ("p", "b", "d", "g"),
    "m": ("n", "w"),
    "n": ("m", "u", "r"),
    "u": ("n", "v"),
    "w": ("m", "v"),
    "i": ("j", "l", "e"),
    "j": ("i", "g", "y"),
    "g": ("q", "j", "y"),
    "y": ("j", "g", "v"),
    "h": ("n", "b", "k"),
    "l": ("i", "t", "r"),
    "f": ("t", "v"),

    # ── Voicing pairs: same mouth, one buzzes ────────────────────
    "t": ("d", "p", "k"),
    "k": ("g", "c", "t"),
    "c": ("k", "s", "g"),
    "v": ("f", "w", "b"),
    "s": ("z", "c", "sh"),
    "z": ("s", "v"),

    # ── Short vowels: the hardest set in early phonics ───────────
    "a": ("e", "u", "o"),
    "e": ("i", "a", "u"),
    "o": ("u", "a", "aw"),

    # ── Digraphs and blends against their nearest neighbours ─────
    "sh": ("ch", "s", "th"),
    "ch": ("sh", "t", "j"),
    "th": ("f", "s", "sh"),
    "ph": ("f", "p", "th"),
    "wh": ("w", "h", "v"),
    "ck": ("k", "c", "ch"),
    "ng": ("nk", "n", "m"),
    "nk": ("ng", "n", "k"),
    "qu": ("q", "kw", "w"),

    # ── Long vowels and their spellings ──────────────────────────
    "ai": ("ay", "a", "ee"),
    "ay": ("ai", "a", "y"),
    "ee": ("ea", "i", "ai"),
    "ea": ("ee", "e", "ai"),
    "oo": ("ou", "o", "u"),
    "ou": ("ow", "oo", "o"),
    "ow": ("ou", "o", "aw"),
    "oi": ("oy", "o", "ou"),
    "oy": ("oi", "y", "ou"),
    "au": ("aw", "a", "o"),
    "aw": ("au", "ow", "o"),

    # ── R-controlled vowels, which sound nearly identical ────────
    "ar": ("or", "er", "a"),
    "er": ("ir", "ur", "or"),
    "ir": ("er", "ur", "ar"),
    "ur": ("er", "ir", "or"),
    "or": ("ar", "er", "oar"),
    "oar": ("or", "ar", "ou"),

    # ── Consonant blends against their parts ─────────────────────
    "bl": ("cl", "br", "pl"),
    "cl": ("bl", "gl", "cr"),
    "br": ("bl", "cr", "dr"),
    "cr": ("cl", "br", "tr"),
    "fl": ("fr", "bl", "gl"),
    "fr": ("fl", "br", "tr"),
    "gl": ("gr", "cl", "bl"),
    "gr": ("gl", "cr", "dr"),
    "pl": ("bl", "pr", "cl"),
    "sl": ("sn", "sm", "cl"),
    "dr": ("tr", "gr", "br"),
    "tr": ("dr", "cr", "fr"),
    "sm": ("sn", "sl", "sp"),
    "sn": ("sm", "sl", "st"),
    "sp": ("st", "sk", "sm"),
    "sw": ("sl", "sp", "st"),
    "st": ("sp", "sk", "sn"),
    "sk": ("st", "sp", "sc"),
    "sc": ("sk", "st", "sp"),
    "spr": ("str", "spl", "sp"),
    "str": ("spr", "st", "spl"),
    "spl": ("spr", "sp", "sl"),
    "squ": ("qu", "sk", "sw"),

    # ── Silent-letter patterns ───────────────────────────────────
    "kn": ("n", "k", "ng"),
    "wr": ("r", "w", "wh"),
    "mb": ("m", "b", "mp"),
    "rh": ("r", "h", "wr"),

    # ── Suffixes, which rhyme with each other ────────────────────
    "ture": ("sure", "tion", "ch"),
    "sure": ("ture", "sion", "sh"),
    "tion": ("sion", "sh", "ture"),
    "ous": ("us", "es", "ful"),
    "ful": ("fl", "full", "ous"),
}


def confusable_with(grapheme: str) -> tuple[str, ...]:
    """Graphemes a learner plausibly picks instead of this one."""
    return CONFUSABLE_GRAPHEMES.get((grapheme or "").strip().lower(), ())
