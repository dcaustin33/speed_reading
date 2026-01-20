import pytest
from speed_reading.core.orp import calculate_orp


class TestCalculateORP:
    def test_empty_string(self):
        assert calculate_orp("") == 0

    def test_single_char(self):
        assert calculate_orp("a") == 0
        assert calculate_orp("I") == 0

    def test_two_to_five_chars(self):
        assert calculate_orp("to") == 1
        assert calculate_orp("the") == 1
        assert calculate_orp("word") == 1
        assert calculate_orp("words") == 1

    def test_six_to_nine_chars(self):
        assert calculate_orp("reader") == 2
        assert calculate_orp("reading") == 2
        assert calculate_orp("speedier") == 2
        assert calculate_orp("something") == 2

    def test_ten_to_thirteen_chars(self):
        assert calculate_orp("understand") == 3
        assert calculate_orp("recognition") == 3
        assert calculate_orp("acceleration") == 3
        assert calculate_orp("understanding") == 3

    def test_fourteen_plus_chars(self):
        assert calculate_orp("representations") == 4
        assert calculate_orp("internationalization") == 4
        assert calculate_orp("supercalifragilistic") == 4
