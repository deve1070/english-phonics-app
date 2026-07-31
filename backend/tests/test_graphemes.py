"""Decodability: which text a child can be given.

This gate decides what the generator is allowed to save and which stories
unlock, so a mistake here is either invisible content starvation or a
child being handed a word built from sounds they have never met.
"""

from types import SimpleNamespace

from app.utils.graphemes import build_allowed_graphemes, content_is_decodable


def phoneme(symbol: str, graphemes: str | None = None):
    return SimpleNamespace(symbol=symbol, graphemes=graphemes)


class TestBuildAllowedGraphemes:
    def test_declared_spellings_win(self):
        assert build_allowed_graphemes([phoneme("ʃ (sh)", "sh")]) == {"sh"}

    def test_a_declared_list_is_split_on_commas(self):
        assert build_allowed_graphemes([phoneme("iː", "ee,ea")]) == {"ee", "ea"}

    def test_declared_spellings_do_not_leak_their_letters(self):
        # /sh/ licenses "sh", not "s" and "h" separately — those are their
        # own phonemes and have to be earned on their own.
        assert "s" not in build_allowed_graphemes([phoneme("ʃ (sh)", "sh")])

    def test_a_letter_name_symbol_still_works_without_a_declaration(self):
        assert build_allowed_graphemes([phoneme("Aa")]) == {"aa", "a"}

    def test_an_ipa_symbol_alone_yields_nothing(self):
        # The bug the graphemes column exists to fix: /ɪ/ carries no latin
        # spelling, so before the column a child could be taught the whole
        # alphabet and still not be allowed to read the letter i.
        assert build_allowed_graphemes([phoneme("ɪ")]) == set()
        assert build_allowed_graphemes([phoneme("ɪ", "i")]) == {"i"}


class TestContentIsDecodable:
    def test_a_word_made_of_known_letters_passes(self):
        allowed = build_allowed_graphemes(
            [phoneme("c", "c"), phoneme("a", "a"), phoneme("t", "t")]
        )
        assert content_is_decodable("cat", allowed)

    def test_one_unknown_letter_fails_the_whole_text(self):
        allowed = build_allowed_graphemes([phoneme("c", "c"), phoneme("a", "a")])
        assert not content_is_decodable("cat", allowed)

    def test_punctuation_and_case_are_not_decoded(self):
        allowed = build_allowed_graphemes(
            [phoneme("c", "c"), phoneme("a", "a"), phoneme("t", "t")]
        )
        assert content_is_decodable("Cat, cat!", allowed)

    def test_a_digraph_is_matched_before_its_letters(self):
        # Longest match first: "ship" must decode as sh-i-p even though
        # "s" and "h" happen to be separately available.
        allowed = build_allowed_graphemes(
            [
                phoneme("sh", "sh"),
                phoneme("i", "i"),
                phoneme("p", "p"),
                phoneme("s", "s"),
                phoneme("h", "h"),
            ]
        )
        assert content_is_decodable("ship", allowed)

    def test_text_with_no_letters_is_trivially_decodable(self):
        assert content_is_decodable("...", set())

    def test_nothing_is_decodable_with_an_empty_allow_list(self):
        assert not content_is_decodable("cat", set())
