"""The rules a streak freeze follows.

Pure functions only — the database side of streak_summary is exercised
live by scripts/verify_basic_functions.py. What is worth pinning down
here is the arithmetic, because every case below is one a real child hits
and getting any of them wrong either destroys a streak that should have
survived or keeps alive one that should not.
"""

from datetime import date, timedelta

from app.services.streak_service import (
    freeze_candidate,
    qualifying_weeks,
    streak_from_days,
    week_start,
)

# A Thursday, so "yesterday" and "last week" are unambiguous below.
TODAY = date(2026, 7, 30)
WED = TODAY - timedelta(days=1)
TUE = TODAY - timedelta(days=2)
MON = TODAY - timedelta(days=3)
SUN = TODAY - timedelta(days=4)


class TestWeekStart:
    def test_monday_is_its_own_week_start(self):
        assert week_start(MON) == MON

    def test_sunday_belongs_to_the_week_that_began_six_days_earlier(self):
        # Matches parents._current_week_monday, which the screen-time and
        # weekly-report code already use. A freeze week that disagreed
        # with the report week would be indefensible to a parent.
        assert week_start(SUN) == SUN - timedelta(days=6)


class TestQualifyingWeeks:
    def test_a_week_qualifies_once_the_goal_is_met(self):
        assert qualifying_weeks({MON, TUE, WED}, 3) == {MON}

    def test_falling_one_day_short_earns_nothing(self):
        assert qualifying_weeks({MON, TUE}, 3) == set()

    def test_exceeding_the_goal_still_earns_exactly_one(self):
        # The cap is structural — one row per (child, week) — so this is
        # really asserting that the week is counted once, not four times.
        assert qualifying_weeks({MON, TUE, WED, TODAY}, 3) == {MON}

    def test_days_are_counted_per_week_not_in_total(self):
        last_week = MON - timedelta(days=7)
        assert qualifying_weeks({MON, TUE, last_week}, 3) == set()

    def test_a_goal_of_zero_earns_nothing(self):
        # Guards against a parent setting lessons_per_week to 0 and the
        # child silently accruing a freeze every week for doing nothing.
        assert qualifying_weeks({MON}, 0) == set()


class TestFreezeCandidate:
    def test_a_single_missed_day_inside_a_run_is_bridged(self):
        # Practised Mon, Tue, missed Wed, practised today.
        assert freeze_candidate({MON, TUE, TODAY}, TODAY) == WED

    def test_bridging_actually_lengthens_the_streak(self):
        days = {MON, TUE, TODAY}
        assert streak_from_days(days, TODAY) == 1
        assert streak_from_days(days | {WED}, TODAY) == 4

    def test_a_lapsed_run_is_saved_when_yesterday_was_the_only_miss(self):
        # Practised through Tuesday, missed Wednesday, and has not yet
        # practised today. The streak reads 0 but is not really broken.
        days = {MON, TUE}
        assert streak_from_days(days, TODAY) == 0
        assert freeze_candidate(days, TODAY) == WED
        assert streak_from_days(days | {WED}, TODAY) == 3

    def test_a_two_day_gap_is_a_real_break(self):
        # One freeze covers one day. Letting it stretch further would make
        # the streak a number nobody can lose, and so a number that means
        # nothing.
        assert freeze_candidate({MON}, TODAY) is None

    def test_an_unbroken_run_spends_nothing(self):
        assert freeze_candidate({SUN, MON, TUE, WED, TODAY}, TODAY) is None

    def test_today_is_never_frozen(self):
        # The child may still practise before midnight. Spending the token
        # now would throw it away.
        assert freeze_candidate({MON, TUE, WED}, TODAY) is None

    def test_the_gap_before_yesterday_is_bridged_too(self):
        # Practised today and yesterday, missed Tuesday, practised Monday.
        assert freeze_candidate({MON, WED, TODAY}, TODAY) == TUE

    def test_a_first_ever_day_has_nothing_behind_it_to_bridge(self):
        assert freeze_candidate({TODAY}, TODAY) is None

    def test_no_practice_at_all_is_not_rescuable(self):
        assert freeze_candidate(set(), TODAY) is None
