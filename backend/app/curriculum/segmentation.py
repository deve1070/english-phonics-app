"""How a word breaks into the graphemes this curriculum teaches.

The ordering rule — a child only ever meets content built from sounds
they have already been taught — is only as good as the answer to "which
graphemes does this word actually use". Getting that answer by guessing
is what made the old check useless.

`utils.graphemes.content_is_decodable` asked whether a word could be
segmented *somehow* out of known graphemes. That question stops
discriminating the moment the child finishes the alphabet: sounds 1-26
of this curriculum are the twenty-six letters, so from sound 26 onward
every string of latin letters segments letter-by-letter and the check
returns True for everything. "through" passed for a child four sounds
into the course, and "through" needs `ough`, which this curriculum never
teaches at all.

The fix is not a cleverer matcher. A word has one true segmentation and
it is a fact about the word, not something derivable from the phoneme
table: "ship" is sh·i·p and "mishap" is s·h·a·p across a syllable
break, and nothing in the curriculum data distinguishes them. So the
segmentation is computed once, reviewed, and stored on the exercise. The
gate then reads it instead of re-deriving it.

What is stored is the segmentation. What the gate does with it lives in
`utils.graphemes`; this module only answers what the pieces are.

Atomic versus decomposable
--------------------------
The one judgement this module makes is which multi-letter spellings have
to be taught as a unit before a word containing them is readable.

A **digraph** spells a single sound with several letters. `sh` is one
sound, and a child who knows `s` and `h` cannot read "ship" — they will
say s-h-i-p. It must be taught. These are atomic.

A **blend** is several sounds that happen to be adjacent. `st` is /s/
then /t/, both audible. A child who knows `s` and `t` can read "stop"
without ever being taught `st` as a thing; the curriculum teaches blends
to build fluency, not to unlock decodability. Treating them as atomic
would mean claiming "stop" is unreadable until sound 50, which is false
and would strip a beginner of most of the words they can actually read.

So blends decompose into their letters and are never emitted as units.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable

from app.models.enums import PhonemeType
from app.models.phoneme import Phoneme

# Types whose multi-letter spellings are several audible sounds in a row
# rather than one sound, and so need no separate teaching to be read.
_DECOMPOSABLE_TYPES = {PhonemeType.CONSONANT_BLEND}

# Final clusters carrying a CONSONANT_BLEND's meaning under a
# LETTER_COMBINATION label. `nd` in "and" is /n/ then /d/, exactly as
# `st` is /s/ then /t/ — the type column disagrees with itself here, and
# following it literally would make "and" unreadable until sound 61.
#
# `ng` and `nk` are deliberately NOT in this list. Both end in the velar
# nasal /ŋ/, which is a sound of its own and not the /n/ a child already
# knows: "king" is not k-i-n-g.
_DECOMPOSABLE_SPELLINGS = {"nd", "nt", "lt", "mp"}


@dataclass(frozen=True)
class Grapheme:
    """A spelling the curriculum teaches, and when."""

    spelling: str
    order: int
    atomic: bool


def build_inventory(phonemes: Iterable[Phoneme]) -> dict[str, Grapheme]:
    """Every spelling the curriculum teaches, mapped to when it arrives.

    A spelling can be declared by more than one phoneme — `s` belongs to
    both /s/ (sound 19) and the voiced s of "dogs" (sound 71), and the
    schwa at sound 80 claims all five vowels. The earliest wins: once a
    child has been taught `s` they can read it, and a later phoneme
    reusing the letter does not make it unreadable again.
    """
    inventory: dict[str, Grapheme] = {}

    for phoneme in phonemes:
        declared = (phoneme.graphemes or "").strip()
        if not declared:
            continue

        for raw in declared.lower().split(","):
            spelling = re.sub(r"[^a-z]", "", raw)
            if not spelling:
                continue

            decomposable = (
                phoneme.type in _DECOMPOSABLE_TYPES
                or spelling in _DECOMPOSABLE_SPELLINGS
            )
            # A single letter is atomic by definition — there is nothing
            # to decompose it into.
            atomic = len(spelling) == 1 or not decomposable

            existing = inventory.get(spelling)
            if existing is None or phoneme.order < existing.order:
                inventory[spelling] = Grapheme(
                    spelling=spelling, order=phoneme.order, atomic=atomic
                )

    return inventory


def segment_word(word: str, inventory: dict[str, Grapheme]) -> list[str] | None:
    """Break one word into taught graphemes, longest atomic match first.

    Returns None when some run of letters is spelled by nothing the
    curriculum teaches — "through" needs `ough` and gets None, which is
    the correct answer rather than a fallback to seven single letters.

    Only atomic spellings are matched as units. Blends are absent from
    the candidates entirely, so "stop" comes back as s·t·o·p and never
    st·o·p, and the two agree on when the word becomes readable anyway.

    Greedy rather than exhaustive, and therefore occasionally wrong: it
    reads "mishap" as mi·sh·ap because `sh` is longer than `s`. That is
    why results are reviewed and stored rather than computed at the
    point of use.
    """
    word = re.sub(r"[^a-z]", "", word.lower())
    if not word:
        return []

    candidates = {g.spelling for g in inventory.values() if g.atomic}
    longest = max((len(s) for s in candidates), default=1)

    pieces: list[str] = []
    index = 0
    while index < len(word):
        window = min(longest, len(word) - index)
        for size in range(window, 0, -1):
            chunk = word[index : index + size]
            if chunk in candidates:
                pieces.append(chunk)
                index += size
                break
        else:
            return None
    return pieces


def segment_content(
    content: str, inventory: dict[str, Grapheme]
) -> list[str] | None:
    """Segment a whole exercise — a symbol, a word, a sentence, a story.

    Punctuation and spacing are dropped: they are not something a child
    decodes. Every word must segment; one unreadable word makes the
    whole passage unreadable, because the child meets it as one thing.
    """
    words = re.findall(r"[a-z]+", content.lower())
    pieces: list[str] = []
    for word in words:
        segmented = segment_word(word, inventory)
        if segmented is None:
            return None
        pieces.extend(segmented)
    return pieces


def required_order(
    pieces: Iterable[str], inventory: dict[str, Grapheme]
) -> int | None:
    """The curriculum position at which this content becomes readable.

    The highest-ordered grapheme in it, since that is the last one the
    child learns. None if any piece is untaught.

    This doubles as the natural home for a word: introduce it exactly
    when its hardest spelling arrives and it is never both new and
    unreadable.
    """
    highest = 0
    for piece in pieces:
        grapheme = inventory.get(piece)
        if grapheme is None:
            return None
        highest = max(highest, grapheme.order)
    return highest
