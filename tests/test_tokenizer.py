import pytest
from speed_reading.core.tokenizer import tokenize_text, Word


class TestTokenizeText:
    def test_empty_text(self):
        doc = tokenize_text("")
        assert doc.total_words == 0
        assert doc.words == []

    def test_single_word(self):
        doc = tokenize_text("hello")
        assert doc.total_words == 1
        assert doc.words[0].text == "hello"
        assert doc.words[0].paragraph_end is True
        assert doc.words[0].sentence_end is True

    def test_simple_sentence(self):
        doc = tokenize_text("The quick brown fox.")
        assert doc.total_words == 4
        assert doc.words[0].text == "The"
        assert doc.words[0].sentence_end is False
        assert doc.words[3].text == "fox."
        assert doc.words[3].sentence_end is True
        assert doc.words[3].paragraph_end is True

    def test_multiple_sentences(self):
        doc = tokenize_text("Hello world. How are you?")
        assert doc.total_words == 5
        assert doc.words[1].text == "world."
        assert doc.words[1].sentence_end is True
        assert doc.words[1].paragraph_end is False
        assert doc.words[4].text == "you?"
        assert doc.words[4].sentence_end is True
        assert doc.words[4].paragraph_end is True

    def test_paragraph_breaks(self):
        doc = tokenize_text("First paragraph.\n\nSecond paragraph.")
        assert doc.total_words == 4
        # First paragraph ends with "paragraph."
        assert doc.words[1].text == "paragraph."
        assert doc.words[1].paragraph_end is True
        # Second paragraph
        assert doc.words[2].text == "Second"
        assert doc.words[2].paragraph_end is False
        assert doc.words[3].text == "paragraph."
        assert doc.words[3].paragraph_end is True

    def test_abbreviations_not_sentence_end(self):
        doc = tokenize_text("Dr. Smith went to the store.")
        # "Dr." should NOT end sentence
        assert doc.words[0].text == "Dr."
        assert doc.words[0].sentence_end is False
        # "store." should end sentence
        assert doc.words[5].text == "store."
        assert doc.words[5].sentence_end is True

    def test_mr_mrs_abbreviations(self):
        doc = tokenize_text("Mr. and Mrs. Jones arrived.")
        assert doc.words[0].text == "Mr."
        assert doc.words[0].sentence_end is False
        assert doc.words[2].text == "Mrs."
        assert doc.words[2].sentence_end is False
        assert doc.words[4].text == "arrived."
        assert doc.words[4].sentence_end is True

    def test_ellipsis_not_sentence_end(self):
        doc = tokenize_text("Wait... I remember now.")
        assert doc.words[0].text == "Wait..."
        assert doc.words[0].sentence_end is False
        assert doc.words[3].text == "now."
        assert doc.words[3].sentence_end is True

    def test_exclamation_and_question(self):
        doc = tokenize_text("Really? Yes! That's great.")
        assert doc.words[0].text == "Really?"
        assert doc.words[0].sentence_end is True
        assert doc.words[1].text == "Yes!"
        assert doc.words[1].sentence_end is True
        assert doc.words[3].text == "great."
        assert doc.words[3].sentence_end is True

    def test_orp_calculation(self):
        doc = tokenize_text("I am reading")
        # "I" - 1 char - ORP 0
        assert doc.words[0].orp_index == 0
        # "am" - 2 chars - ORP 1
        assert doc.words[1].orp_index == 1
        # "reading" - 7 chars - ORP 2
        assert doc.words[2].orp_index == 2

    def test_windows_line_endings(self):
        doc = tokenize_text("First.\r\n\r\nSecond.")
        assert doc.total_words == 2
        assert doc.words[0].paragraph_end is True
        assert doc.words[1].paragraph_end is True

    def test_multiple_blank_lines(self):
        doc = tokenize_text("First.\n\n\n\n\nSecond.")
        assert doc.total_words == 2
        assert doc.words[0].paragraph_end is True

    def test_file_metadata(self):
        doc = tokenize_text("test", file_path="/path/to/file.txt", file_hash="abc123")
        assert doc.file_path == "/path/to/file.txt"
        assert doc.file_hash == "abc123"

    def test_quoted_sentence_ending(self):
        doc = tokenize_text('He said "Hello." Then left.')
        # "Hello." should end sentence (quotes after period)
        assert doc.words[2].text == '"Hello."'
        assert doc.words[2].sentence_end is True
