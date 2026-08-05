"""What the generator is allowed to save.

The model is told to use only sounds the child has been taught. This is
the part that does not take its word for it. Azure is asked for content;
what reaches a child is whatever survives here.
"""

from types import SimpleNamespace

import pytest

from app.models.enums import ExerciseType, PhonemeType
from app.services.exercise_generation_service import _parse_response


def phoneme(symbol, graphemes, order, type=PhonemeType.ALPHABET):
    return SimpleNamespace(
        symbol=symbol, graphemes=graphemes, order=order, type=type
    )


ALPHABET = [
    phoneme(letter.upper() + letter, letter, order=index + 1)
    for index, letter in enumerate("abcdefghijklmnopqrstuvwxyz")
]
DIGRAPHS = [
    phoneme("ʃ (sh)", "sh", 51, PhonemeType.LETTER_COMBINATION),
    phoneme("ð (th)", "th", 55, PhonemeType.LETTER_COMBINATION),
    phoneme("ck", "ck", 57, PhonemeType.LETTER_COMBINATION),
]
CURRICULUM = ALPHABET + DIGRAPHS

# A child twenty sounds in: every letter up to `t`, no digraphs.
LEARNED = [p for p in CURRICULUM if p.order <= 20]


def response(*contents):
    import json

    return json.dumps(
        [{"type": "WORD", "content": c, "difficulty": 1} for c in contents]
    )


def parse(*contents, allowed=LEARNED):
    return _parse_response(
        response(*contents),
        lesson_id=1,
        allowed_phonemes=allowed,
        curriculum=CURRICULUM,
    )


class TestTheOrderingRule:
    def test_a_word_within_reach_is_kept(self):
        kept = parse("cat")
        assert [item["content"] for item in kept] == ["cat"]

    def test_a_word_using_an_unlearned_letter_is_dropped(self):
        # `z` is sound 26; this child is at 20.
        assert parse("zip") == []

    def test_a_word_resting_on_an_unlearned_digraph_is_dropped(self):
        # The one the old check could not see. Every letter of "the" is
        # known by sound 20, so a checker that guesses a segmentation
        # reads it as t·h·e and passes it. It is th·e, and `th` is
        # sound 55.
        assert parse("the") == []
        assert parse("ship") == []
        assert parse("back") == []

    def test_the_same_words_are_kept_once_their_digraph_arrives(self):
        kept = parse("the", "ship", "back", allowed=CURRICULUM)
        assert [item["content"] for item in kept] == ["the", "ship", "back"]

    def test_one_bad_word_does_not_discard_the_good_ones(self):
        kept = parse("cat", "the", "top")
        assert [item["content"] for item in kept] == ["cat", "top"]

    def test_a_blend_needs_no_teaching_of_its_own(self):
        # /st/ is /s/ then /t/. A child who has both can read "stop"
        # without ever meeting `st` as a unit.
        kept = parse("stop")
        assert [item["content"] for item in kept] == ["stop"]


class TestWhatGetsStored:
    def test_the_segmentation_that_proved_it_legal_is_kept(self):
        kept = parse("the", "ship", "cat", allowed=CURRICULUM)
        assert [item["graphemes"] for item in kept] == ["th,e", "sh,i,p", "c,a,t"]

    def test_every_saved_item_carries_one(self):
        # Content saved without a segmentation cannot be checked later,
        # and the gate withholds what it cannot check — it would be
        # generated and then never shown.
        for item in parse("cat", "top", "sat"):
            assert item["graphemes"]

    def test_a_sentence_is_segmented_across_its_words(self):
        raw = '[{"type": "SENTENCE", "content": "a cat sat", "difficulty": 2}]'
        kept = _parse_response(
            raw, lesson_id=1, allowed_phonemes=LEARNED, curriculum=CURRICULUM
        )
        assert kept[0]["graphemes"] == "a,c,a,t,s,a,t"


class TestMalformedResponses:
    def test_non_json_raises_rather_than_saving_nothing_quietly(self):
        with pytest.raises(ValueError):
            _parse_response(
                "sorry, I can't do that",
                lesson_id=1,
                allowed_phonemes=LEARNED,
                curriculum=CURRICULUM,
            )

    def test_an_unknown_type_is_skipped(self):
        raw = '[{"type": "HAIKU", "content": "cat", "difficulty": 1}]'
        assert (
            _parse_response(
                raw, lesson_id=1, allowed_phonemes=LEARNED, curriculum=CURRICULUM
            )
            == []
        )

    def test_empty_content_is_skipped(self):
        assert parse("", "   ") == []

    def test_an_out_of_range_difficulty_falls_back_to_one(self):
        raw = '[{"type": "WORD", "content": "cat", "difficulty": 9}]'
        kept = _parse_response(
            raw, lesson_id=1, allowed_phonemes=LEARNED, curriculum=CURRICULUM
        )
        assert kept[0]["difficulty"] == 1


def test_a_phoneme_exercise_is_held_to_the_same_rule():
    # PHONEME items used to skip the check entirely, on the grounds that
    # a bare symbol is not a word. `th` is a bare symbol too.
    raw = '[{"type": "PHONEME", "content": "th", "difficulty": 1}]'
    assert (
        _parse_response(
            raw, lesson_id=1, allowed_phonemes=LEARNED, curriculum=CURRICULUM
        )
        == []
    )
