import pytest
import tempfile
from pathlib import Path

from speed_reading.io.file_loader import load_file, _strip_markdown, FileLoadError


class TestLoadTxt:
    def test_simple_txt(self):
        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False, mode="w") as f:
            f.write("Hello world. This is a test.")
            f.flush()
            content, hash_ = load_file(f.name)
            assert content == "Hello world. This is a test."
            assert len(hash_) == 64  # SHA256 hex

    def test_utf8_txt(self):
        with tempfile.NamedTemporaryFile(
            suffix=".txt", delete=False, mode="w", encoding="utf-8"
        ) as f:
            f.write("Hello wörld. Café résumé.")
            f.flush()
            content, _ = load_file(f.name)
            assert "wörld" in content
            assert "Café" in content

    def test_file_not_found(self):
        with pytest.raises(FileNotFoundError):
            load_file("/nonexistent/path/file.txt")

    def test_unsupported_format(self):
        with tempfile.NamedTemporaryFile(suffix=".xyz", delete=False) as f:
            f.write(b"test")
            f.flush()
            with pytest.raises(FileLoadError, match="Unsupported file format"):
                load_file(f.name)


class TestStripMarkdown:
    def test_headers(self):
        text = "# Header 1\n## Header 2\nNormal text"
        result = _strip_markdown(text)
        assert "Header 1" in result
        assert "Header 2" in result
        assert "#" not in result

    def test_bold_italic(self):
        text = "This is **bold** and *italic* text"
        result = _strip_markdown(text)
        assert result == "This is bold and italic text"

    def test_links(self):
        text = "Click [here](http://example.com) for more"
        result = _strip_markdown(text)
        assert result == "Click here for more"

    def test_code_blocks(self):
        text = "Before\n```python\ncode\n```\nAfter"
        result = _strip_markdown(text)
        assert "code" not in result
        assert "Before" in result
        assert "After" in result

    def test_inline_code(self):
        text = "Use `print()` function"
        result = _strip_markdown(text)
        assert "`" not in result

    def test_images(self):
        text = "See ![alt text](image.png) here"
        result = _strip_markdown(text)
        assert "alt text" not in result
        assert "image.png" not in result

    def test_list_markers(self):
        text = "- Item 1\n* Item 2\n1. Item 3"
        result = _strip_markdown(text)
        assert "-" not in result.split()[0] if result.split() else True
        assert "Item" in result


class TestLoadMarkdown:
    def test_markdown_file(self):
        with tempfile.NamedTemporaryFile(suffix=".md", delete=False, mode="w") as f:
            f.write("# Hello\n\nThis is **bold** text.")
            f.flush()
            content, _ = load_file(f.name)
            assert "Hello" in content
            assert "**" not in content
            assert "bold" in content


class TestHashConsistency:
    def test_same_content_same_hash(self):
        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False, mode="w") as f1:
            f1.write("Same content")
            f1.flush()
            _, hash1 = load_file(f1.name)

        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False, mode="w") as f2:
            f2.write("Same content")
            f2.flush()
            _, hash2 = load_file(f2.name)

        assert hash1 == hash2

    def test_different_content_different_hash(self):
        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False, mode="w") as f1:
            f1.write("Content A")
            f1.flush()
            _, hash1 = load_file(f1.name)

        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False, mode="w") as f2:
            f2.write("Content B")
            f2.flush()
            _, hash2 = load_file(f2.name)

        assert hash1 != hash2
