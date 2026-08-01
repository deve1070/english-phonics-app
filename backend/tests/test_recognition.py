"""When a sound counts as recognised, and what the wrong answers are.

Two decisions live in this module and nowhere else: how wide the field of
symbols gets as a child steadies, and which symbols share the screen with
the answer. Both are easy to change by accident and expensive to get
wrong — a distractor the child can rule out without reading is a question
that teaches nothing, and a recognition threshold that is too generous
tells a parent their child knows a sound they are still guessing at.
"""

import random
from types import SimpleNamespace

from app.curriculum.confusions import confusable_with
from app.services.recognition_service import (
    MAX_OPTIONS,
    MIN_OPTIONS,
    RECOGNITION_STREAK,
    RecognitionStats,
    pick_distractors,
)


def stats(**kwargs) -> RecognitionStats:
    base = dict(
        phoneme_id=1,
        asked=0,
        correct=0,
        recent_correct_streak=0,
        hardest_width_passed=0,
    )
    base.update(kwargs)
    return RecognitionStats(**base)


def phoneme(id: int, grapheme: str, order: int) -> SimpleNamespace:
    """A stand-in. These functions only ever read three fields, and using
    the real model would drag a database session into a pure test."""
    return SimpleNamespace(
        id=id, symbol=grapheme, graphemes=grapheme, order=order
    )


# ── Is the sound recognised? ─────────────────────────────────────────


def test_three_in_a_row_at_full_width_is_recognised():
    assert stats(
        asked=6,
        correct=4,
        recent_correct_streak=RECOGNITION_STREAK,
        hardest_width_passed=MAX_OPTIONS,
    ).is_recognised


def test_three_in_a_row_out_of_two_symbols_is_not():
    # A coin toss three times running is not evidence of anything, which
    # is the whole reason the width is tracked separately from the streak.
    assert not stats(
        asked=3,
        correct=3,
        recent_correct_streak=3,
        hardest_width_passed=2,
    ).is_recognised


def test_a_recent_wrong_answer_undoes_it():
    # Right last week and wrong since is not "recognised". The streak is
    # the trailing one, not the best one ever managed.
    assert not stats(
        asked=20,
        correct=17,
        recent_correct_streak=0,
        hardest_width_passed=MAX_OPTIONS,
    ).is_recognised


# ── How wide the field gets ──────────────────────────────────────────


def test_a_new_sound_starts_at_the_narrowest():
    assert stats().next_option_count == MIN_OPTIONS


def test_two_correct_widens_the_field_by_one():
    assert (
        stats(asked=2, correct=2, recent_correct_streak=2, hardest_width_passed=2)
        .next_option_count
        == 3
    )


def test_widening_never_skips_a_step():
    # Even a long streak moves one at a time, so a child never jumps from
    # two symbols to four between one question and the next.
    assert (
        stats(asked=9, correct=9, recent_correct_streak=9, hardest_width_passed=2)
        .next_option_count
        == 3
    )


def test_it_stops_at_the_maximum():
    assert (
        stats(
            asked=12,
            correct=12,
            recent_correct_streak=12,
            hardest_width_passed=MAX_OPTIONS,
        ).next_option_count
        == MAX_OPTIONS
    )


def test_a_wrong_answer_drops_back_a_step():
    assert (
        stats(asked=5, correct=3, recent_correct_streak=0, hardest_width_passed=4)
        .next_option_count
        == 3
    )


def test_it_never_drops_below_the_minimum():
    # However badly it is going, the child is never left with one option
    # and no choice to make.
    assert (
        stats(asked=8, correct=0, recent_correct_streak=0, hardest_width_passed=2)
        .next_option_count
        == MIN_OPTIONS
    )


def test_one_correct_holds_the_current_width():
    assert (
        stats(asked=4, correct=1, recent_correct_streak=1, hardest_width_passed=3)
        .next_option_count
        == 3
    )


# ── Which wrong answers get offered ──────────────────────────────────


B = phoneme(1, "b", 2)
D = phoneme(2, "d", 4)
S = phoneme(3, "s", 6)
M = phoneme(4, "m", 8)
Z = phoneme(5, "z", 40)
POOL = [B, D, S, M, Z]


def test_the_curriculum_table_beats_a_distant_neighbour():
    [choice] = pick_distractors(B, POOL, 1, rng=random.Random(0))
    assert choice is D, "b should be offered against d, not against a stranger"


def test_the_childs_own_confusions_beat_the_table():
    # This child reaches for /s/ when they mean /b/ — unusual, not in the
    # table, and better evidence than anything written there.
    [choice] = pick_distractors(
        B, POOL, 1, personal_confusions={S.id: 4}, rng=random.Random(0)
    )
    assert choice is S


def test_the_most_confused_leads():
    chosen = pick_distractors(
        B, POOL, 2, personal_confusions={S.id: 1, M.id: 7}, rng=random.Random(0)
    )
    assert {p.id for p in chosen} == {S.id, M.id}


def test_a_sound_with_no_listed_confusions_still_gets_neighbours():
    # /z/ has no curriculum entry pointing at this pool, and a question
    # with no wrong answers is not a question. Order neighbours stand in.
    chosen = pick_distractors(Z, POOL, 2, rng=random.Random(0))
    assert len(chosen) == 2
    assert Z not in chosen


def test_the_target_is_never_its_own_distractor():
    chosen = pick_distractors(B, POOL, 4, rng=random.Random(1))
    assert B not in chosen


def test_a_pool_of_one_yields_nothing_rather_than_raising():
    assert pick_distractors(B, [B], 3, rng=random.Random(0)) == []


def test_asking_for_more_than_exist_returns_what_there_is():
    chosen = pick_distractors(B, POOL, 99, rng=random.Random(0))
    assert len(chosen) == len(POOL) - 1


def test_position_is_not_a_clue():
    # Same question twice must not put the same distractor first, or the
    # child learns the layout instead of the sound.
    seen = {
        tuple(p.id for p in pick_distractors(B, POOL, 3, rng=random.Random(seed)))
        for seed in range(12)
    }
    assert len(seen) > 1


# ── The table itself ─────────────────────────────────────────────────


def test_the_famous_pair_is_confusable_both_ways():
    assert "d" in confusable_with("b")
    assert "b" in confusable_with("d")


def test_lookup_is_forgiving_about_case_and_padding():
    assert confusable_with("  SH ") == confusable_with("sh")


def test_an_unknown_grapheme_is_empty_not_an_error():
    assert confusable_with("zzz") == ()
    assert confusable_with("") == ()
    assert confusable_with(None) == ()
