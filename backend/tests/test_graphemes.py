"""Decodability: which text a child can be given.

This gate decides what the generator is allowed to save and which
stories unlock, so a mistake here is either invisible content
starvation or a child being handed a word built from sounds they have
never met.

The suite it replaces asserted the behaviour of a checker that guessed
a word's segmentation at the point of use. Those tests passed while the
gate was letting "through" reach a child four sounds into the course,
because every one of them used a hand-made allow-list of three or four
letters — never the real curriculum, where all twenty-six letters are
taught before the first digraph and any word therefore comes apart
letter-by-letter. The regressions at the bottom of this file are the
ones that suite could not have caught.
"""

from types import SimpleNamespace

import pytest

from app.curriculum.segmentation import (
    build_inventory,
    required_order,
    segment_content,
    segment_word,
)
from app.models.enums import PhonemeType
from app.utils.graphemes import stored_is_decodable, taught_spellings


def phoneme(
    symbol: str,
    graphemes: str | None = None,
    order: int = 1,
    type: PhonemeType = PhonemeType.ALPHABET,
):
    return SimpleNamespace(
        symbol=symbol, graphemes=graphemes, order=order, type=type
    )


# The shape of the real thing: the alphabet first, then digraphs and
# blends much later. Nothing here discriminates unless the fixture has
# that shape.
ALPHABET = [
    phoneme(letter.upper() + letter, letter, order=index + 1)
    for index, letter in enumerate("abcdefghijklmnopqrstuvwxyz")
]
LATER = [
    phoneme("ʃ (sh)", "sh", order=51, type=PhonemeType.LETTER_COMBINATION),
    phoneme("tʃ (ch)", "ch", order=52, type=PhonemeType.LETTER_COMBINATION),
    phoneme("ð (th)", "th", order=55, type=PhonemeType.LETTER_COMBINATION),
    phoneme("ck", "ck", order=57, type=PhonemeType.LETTER_COMBINATION),
    phoneme("st", "st", order=50, type=PhonemeType.CONSONANT_BLEND),
    phoneme("nd", "nd", order=61, type=PhonemeType.LETTER_COMBINATION),
    phoneme("ng", "ng", order=59, type=PhonemeType.LETTER_COMBINATION),
    phoneme("iː (ee/ea)", "ee,ea", order=33, type=PhonemeType.LONG_VOWEL),
]
CURRICULUM = ALPHABET + LATER


class TestTaughtSpellings:
    def test_declared_spellings_win(self):
        assert taught_spellings([phoneme("ʃ (sh)", "sh")]) == {"sh"}

    def test_a_declared_list_is_split_on_commas(self):
        assert taught_spellings([phoneme("iː", "ee,ea")]) == {"ee", "ea"}

    def test_declared_spellings_do_not_leak_their_letters(self):
        # /sh/ licenses "sh", not "s" and "h" separately — those are
        # their own phonemes and have to be earned on their own.
        assert "s" not in taught_spellings([phoneme("ʃ (sh)", "sh")])

    def test_an_undeclared_phoneme_teaches_nothing(self):
        # This used to infer {"aa", "a"} from the symbol "Aa", inventing
        # a grapheme `aa` that the curriculum does not teach. Withholding
        # beats guessing: every phoneme declares its spellings now.
        assert taught_spellings([phoneme("Aa")]) == set()
        assert taught_spellings([phoneme("ɪ")]) == set()


class TestSegmentation:
    def test_a_digraph_beats_its_letters(self):
        inventory = build_inventory(CURRICULUM)
        assert segment_word("ship", inventory) == ["sh", "i", "p"]
        assert segment_word("the", inventory) == ["th", "e"]
        assert segment_word("back", inventory) == ["b", "a", "ck"]

    def test_a_blend_is_never_emitted_as_a_unit(self):
        # /st/ is /s/ then /t/, both audible. A child who knows s and t
        # can read "stop" without being taught `st`, so treating it as a
        # unit would withhold most of a beginner's readable vocabulary.
        inventory = build_inventory(CURRICULUM)
        assert segment_word("stop", inventory) == ["s", "t", "o", "p"]
        assert segment_word("and", inventory) == ["a", "n", "d"]

    def test_a_velar_nasal_is_not_its_letters(self):
        # `ng` is one sound and genuinely needs teaching: "king" is not
        # k-i-n-g. It stays atomic where `nd` does not.
        inventory = build_inventory(CURRICULUM)
        assert segment_word("king", inventory) == ["k", "i", "ng"]

    def test_a_letter_the_curriculum_never_teaches_refuses_to_segment(self):
        inventory = build_inventory(ALPHABET[:5])
        assert segment_word("zebra", inventory) is None

    def test_the_segmenter_is_a_first_pass_not_an_oracle(self):
        # Both documented limits, pinned so a change to the matcher has
        # to face them. `ough` is in no curriculum entry, so "through"
        # cannot be read as th·r·ough; and greedy matching takes the
        # longest lump it can, so "mishap" breaks across its syllable.
        # This is why segmentations are reviewed and stored, not
        # recomputed at the point of use.
        inventory = build_inventory(CURRICULUM)
        assert segment_word("through", inventory) == ["th", "r", "o", "u", "g", "h"]
        assert segment_word("mishap", inventory) == ["m", "i", "sh", "a", "p"]

    def test_the_earliest_teaching_of_a_spelling_wins(self):
        # `s` belongs to /s/ at 19 and the voiced s of "dogs" at 71.
        # Once taught it stays readable.
        inventory = build_inventory(
            CURRICULUM
            + [phoneme("s (voiced)", "s", order=71, type=PhonemeType.LETTER_COMBINATION)]
        )
        assert inventory["s"].order == 19

    def test_punctuation_and_case_are_not_decoded(self):
        inventory = build_inventory(CURRICULUM)
        assert segment_content("Cat, cat!", inventory) == list("catcat")

    def test_one_unreadable_word_sinks_the_passage(self):
        # A child meets a sentence as one thing; a single word they
        # cannot decode makes the whole of it unreadable.
        inventory = build_inventory(ALPHABET[:20])
        assert segment_content("a cat", inventory) == ["a", "c", "a", "t"]
        assert segment_content("a cat by a zebra", inventory) is None

    def test_required_order_is_the_last_sound_learned(self):
        inventory = build_inventory(CURRICULUM)
        assert required_order(["b", "a", "ck"], inventory) == 57
        assert required_order(["c", "a", "t"], inventory) == 20


class TestStoredIsDecodable:
    def test_every_piece_must_be_taught(self):
        assert stored_is_decodable("c,a,t", {"c", "a", "t"})
        assert not stored_is_decodable("c,a,t", {"c", "a"})

    def test_a_missing_segmentation_is_withheld_not_allowed(self):
        # An unfilled column is an unanswered question, and the safe
        # answer to "can this child read this?" is no.
        assert not stored_is_decodable(None, {"c", "a", "t"})
        assert not stored_is_decodable("", {"c", "a", "t"})
        assert not stored_is_decodable("  ,  ", {"c", "a", "t"})

    def test_case_and_padding_do_not_matter(self):
        assert stored_is_decodable("SH, I ,p", {"sh", "i", "p"})

    def test_nothing_passes_an_empty_allow_list(self):
        assert not stored_is_decodable("c,a,t", set())


class TestTheLeakThatMotivatedAllThis:
    """The twelve words that passed for a child thirty sounds in.

    Measured against the real curriculum, not a toy allow-list: a child
    who has finished the alphabet and the magic-e vowels. Each word
    needs a digraph taught much later, and each was cleared to reach
    them.
    """

    @pytest.mark.parametrize(
        "word, blocking, taught_at",
        [
            ("ship", "sh", 51),
            ("chip", "ch", 52),
            ("the", "th", 55),
            ("duck", "ck", 57),
            ("king", "ng", 59),
            ("bead", "ea", 33),
        ],
    )
    def test_a_digraph_word_is_withheld_until_its_digraph_arrives(
        self, word, blocking, taught_at
    ):
        full = build_inventory(CURRICULUM)
        pieces = segment_content(word, full)
        assert pieces is not None and blocking in pieces
        assert required_order(pieces, full) == taught_at

        # A child at sound 30 — alphabet finished, digraph not reached.
        early = taught_spellings([p for p in CURRICULUM if p.order <= 30])
        assert not stored_is_decodable(",".join(pieces), early)

        # And released once it is.
        arrived = taught_spellings(
            [p for p in CURRICULUM if p.order <= taught_at]
        )
        assert stored_is_decodable(",".join(pieces), arrived)

    def test_knowing_every_letter_is_not_knowing_every_word(self):
        # The heart of it. The alphabet alone used to clear everything.
        letters = taught_spellings(ALPHABET)
        assert stored_is_decodable("c,a,t", letters)
        assert not stored_is_decodable("th,e", letters)
        assert not stored_is_decodable("b,a,ck", letters)
