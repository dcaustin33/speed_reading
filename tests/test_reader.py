import pytest
from speed_reading.core.reader import Reader
from speed_reading.core.tokenizer import tokenize_text


@pytest.fixture
def sample_document():
    text = """First sentence here. Second sentence now.

This is a new paragraph. It has two sentences.

Final paragraph here."""
    return tokenize_text(text)


@pytest.fixture
def reader(sample_document):
    return Reader(sample_document)


class TestReaderProperties:
    def test_initial_state(self, reader):
        assert reader.current_index == 0
        assert reader.is_playing is False
        assert reader.wpm == 300
        assert reader.paragraph_pause == 1.0

    def test_wpm_bounds(self, reader):
        reader.wpm = 50
        assert reader.wpm == 100  # Min

        reader.wpm = 1000
        assert reader.wpm == 800  # Max

        reader.wpm = 500
        assert reader.wpm == 500

    def test_paragraph_pause_bounds(self, reader):
        reader.paragraph_pause = 0.1
        assert reader.paragraph_pause == 0.25  # Min

        reader.paragraph_pause = 5.0
        assert reader.paragraph_pause == 3.0  # Max

        reader.paragraph_pause = 1.5
        assert reader.paragraph_pause == 1.5

    def test_current_index_bounds(self, reader, sample_document):
        reader.current_index = -10
        assert reader.current_index == 0

        reader.current_index = 1000
        assert reader.current_index == sample_document.total_words - 1

    def test_current_word(self, reader):
        word = reader.current_word
        assert word is not None
        assert word.text == "First"

    def test_progress(self, reader, sample_document):
        assert reader.progress == 0.0

        reader.current_index = sample_document.total_words // 2
        assert 0.4 < reader.progress < 0.6

    def test_time_remaining(self, reader):
        # At 300 WPM, 18 words should take about 3.6 seconds
        remaining = reader.time_remaining_seconds
        assert remaining > 0


class TestReaderNavigation:
    def test_skip_forward(self, reader):
        reader.skip_forward()
        assert reader.current_index == 5

    def test_skip_backward(self, reader):
        reader.current_index = 10
        reader.skip_backward()
        assert reader.current_index == 5

    def test_skip_backward_at_start(self, reader):
        reader.skip_backward()
        assert reader.current_index == 0

    def test_next_sentence(self, reader):
        reader.next_sentence()
        # Should be at "Second"
        assert reader.current_word.text == "Second"

    def test_prev_sentence(self, reader):
        # Index 5 is "now." - prev_sentence should go to start of current sentence
        reader.current_index = 5
        reader.prev_sentence()
        assert reader.current_index == 3  # "Second"

        # Now prev_sentence again should go to start of first sentence
        reader.prev_sentence()
        assert reader.current_index == 0  # "First"

    def test_next_paragraph(self, reader):
        reader.next_paragraph()
        # Should be at "This"
        assert reader.current_word.text == "This"

    def test_prev_paragraph(self, reader):
        # Go to second paragraph
        reader.next_paragraph()
        start_idx = reader.current_index
        # Then go to next
        reader.next_paragraph()
        # Now go back
        reader.prev_paragraph()
        assert reader.current_index == start_idx

    def test_go_to_word(self, reader):
        reader.go_to_word(5)
        assert reader.current_index == 5


class TestReaderCallbacks:
    def test_on_word_callback(self, sample_document):
        words_seen = []

        def on_word(word, index):
            words_seen.append((word.text, index))

        reader = Reader(sample_document, on_word=on_word)
        reader.go_to_word(3)

        assert len(words_seen) == 1
        assert words_seen[0][1] == 3


class TestReaderPlayback:
    def test_toggle(self, reader):
        # Without root set, play won't actually start
        reader._root = None
        reader.toggle()
        # Still false because no root
        assert reader.is_playing is False

    def test_stop_resets_index(self, reader):
        reader.current_index = 10
        reader.stop()
        assert reader.current_index == 0
