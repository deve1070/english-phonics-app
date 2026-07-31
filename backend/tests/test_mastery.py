"""What counts as having mastered a sound.

One definition, used by the parent dashboard, the collectibles, the
quest's review slot and the story gate. These tests exist mainly so that
changing the threshold is a deliberate act with a visible cost, rather
than something that quietly desynchronises four features.
"""

from app.services.mastery_service import MASTERY_THRESHOLD, is_mastered


def test_a_consistent_pass_is_mastery():
    assert is_mastered(85.0, attempts=3)


def test_the_threshold_itself_counts_as_mastered():
    assert is_mastered(MASTERY_THRESHOLD, attempts=2)


def test_below_the_threshold_is_not():
    assert not is_mastered(MASTERY_THRESHOLD - 0.1, attempts=5)


def test_one_lucky_attempt_is_not_mastery():
    # This is the behaviour change: the parent dashboard used to award
    # mastery on a single high score, which meant a child could be told
    # they had mastered a sound they had said correctly once.
    assert not is_mastered(100.0, attempts=1)


def test_a_sound_never_attempted_is_not_mastered():
    assert not is_mastered(None, attempts=0)
