"""The ordering rule: is this content readable by this child yet?

A child only ever meets content built from sounds they have already been
taught. This module is the one place that answers whether a given piece
of content clears that bar, and every feature that shows a child words —
the exercise generator, the daily quest, the decodable story shelf — has
to get the same answer.

How it used to work, and why it did not
---------------------------------------
This asked whether the content could be segmented *somehow* out of the
spellings a child knew, guessing the segmentation each time it was
called. That question stops discriminating the moment a child finishes
the alphabet. Sounds 1-26 of this curriculum are the twenty-six letters,
so from sound 26 onward every string of latin letters comes apart
letter-by-letter and the check returns True for everything. Measured
against the real curriculum, a child four sounds into the course was
cleared to read "ship", "the", "quick", "knee", "nation" and "through" —
twelve of twelve probes wrongly accepted. `through` needs `ough`, which
this curriculum never teaches at all.

It also inferred spellings from a phoneme's symbol when the `graphemes`
column was empty, turning "Aa" into the pair {aa, a}. That invented a
grapheme `aa` the curriculum does not teach and cannot be asked about.
Every phoneme now declares its spellings, so the guess is gone.

How it works now
----------------
A word's segmentation is a fact about the word, not something derivable
from the phoneme table — "ship" is sh·i·p while "mishap" breaks s·h
across a syllable. So it is computed once by
`app.curriculum.segmentation`, reviewed, and stored on the row. This
module reads what is stored and checks each piece against what the child
has been taught. No guessing at the point of use.

Content with no stored segmentation cannot be checked, and is therefore
withheld rather than allowed. An unfilled column is an unanswered
question, and the safe answer to "can this child read this?" is no.
"""

from typing import Iterable

from app.models.phoneme import Phoneme


def taught_spellings(phonemes: Iterable[Phoneme]) -> set[str]:
    """Every spelling these phonemes teach.

    Reads the `graphemes` column and nothing else. A phoneme that
    declares nothing teaches nothing here — better to withhold content
    than to invent a spelling from an IPA symbol and let content through
    on the strength of it.
    """
    spellings: set[str] = set()
    for phoneme in phonemes:
        for raw in (phoneme.graphemes or "").lower().split(","):
            cleaned = raw.strip()
            if cleaned:
                spellings.add(cleaned)
    return spellings


def stored_is_decodable(stored: str | None, taught: set[str]) -> bool:
    """True if every grapheme in a stored segmentation has been taught.

    `stored` is the comma-separated segmentation held on the row —
    "sh,i,p" for "ship". None or empty means nobody has worked out how
    this content breaks apart, which is not the same as it being simple:
    it is unchecked, so it is withheld.
    """
    if not stored:
        return False
    pieces = [p.strip() for p in stored.lower().split(",") if p.strip()]
    if not pieces:
        return False
    return all(piece in taught for piece in pieces)
