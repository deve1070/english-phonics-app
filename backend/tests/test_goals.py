"""How big a week's promise is allowed to be.

This is the load-bearing decision in the whole goals feature. A target
set too high teaches a child that goals are things other people reach,
which is the exact opposite of what the feature is for; set too low it is
not a goal at all. These tests pin the rule so that changing it has to be
deliberate.
"""

from app.services.goal_service import (
    MAX_DAYS,
    MAX_MASTERED,
    MIN_DAYS,
    MIN_FOUND,
    stretch_target,
)
from app.services.recognition_service import ROUND_SIZE


def days(recent: list[int]) -> int:
    return stretch_target(recent, MIN_DAYS, MAX_DAYS)


def test_a_child_who_has_never_come_gets_the_gentlest_goal():
    assert days([]) == MIN_DAYS
    assert days([0, 0, 0]) == MIN_DAYS


def test_the_goal_is_one_past_the_best_recent_week():
    # Their best, not their average. Aiming at a child's average asks
    # them to be typical, which is not something to aim at.
    assert days([2, 4, 3]) == 5


def test_a_single_good_week_counts():
    # A child who managed five days once has shown they can, even if the
    # weeks either side were quiet.
    assert days([1, 5, 1]) == 6


def test_it_never_asks_for_a_perfect_week():
    # Seven days means one busy Tuesday turns the week into a miss, and
    # there is no way for a child to opt into that.
    assert days([7, 7, 7]) == MAX_DAYS
    assert MAX_DAYS < 7


def test_the_floor_holds_for_every_kind():
    assert stretch_target([0], MIN_FOUND, 40) == MIN_FOUND
    assert stretch_target([], 1, MAX_MASTERED) == 1


def test_a_weeks_promise_cannot_be_kept_in_one_sitting():
    # Caught by looking at a real payload: a brand-new child was offered
    # "find 5 sounds" and a single five-question round finished it before
    # they had got up. A promise met by accident on Monday morning is not
    # a week's work and the prize that came with it meant nothing.
    assert MIN_FOUND > ROUND_SIZE
    assert stretch_target([], MIN_FOUND, 40) > ROUND_SIZE


def test_the_ceiling_holds_for_every_kind():
    assert stretch_target([99], MIN_FOUND, 40) == 40
    assert stretch_target([99], 1, MAX_MASTERED) == MAX_MASTERED


def test_a_steady_child_is_asked_for_one_more_not_double():
    # The step is always exactly one. A child at four days being asked
    # for eight would be told, in effect, that where they are is not
    # worth much.
    for best in range(0, MAX_DAYS):
        assert days([best]) <= max(MIN_DAYS, best + 1)
