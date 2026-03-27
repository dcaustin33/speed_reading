import re
from dataclasses import dataclass, field

from speed_reading.core.orp import calculate_orp
from speed_reading.io.file_loader import Chapter

# Common abbreviations that shouldn't end sentences
ABBREVIATIONS = frozenset([
    "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "gen", "vs", "etc", "inc",
    "ltd", "corp", "co", "dept",
    "e.g", "i.e", "a.m", "p.m",
    "u.s", "u.k",
    "st", "ave", "blvd", "rd", "apt", "no", "vol", "pg", "pp",
    "fig", "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "sept",
    "oct", "nov", "dec", "mon", "tue", "wed", "thu", "fri", "sat", "sun",
])


@dataclass
class Word:
    text: str
    orp_index: int
    paragraph_end: bool
    sentence_end: bool


@dataclass
class ChapterMarker:
    """Chapter with word index for navigation."""

    title: str
    word_index: int
    level: int = 0


@dataclass
class Document:
    words: list[Word]
    total_words: int
    file_path: str
    file_hash: str
    chapters: list[ChapterMarker] = field(default_factory=list)


def _is_sentence_end(word: str, next_word: str | None) -> bool:
    """Determine if a word ends a sentence."""
    if not word:
        return False

    # Check if word ends with sentence-ending punctuation
    stripped = word.rstrip('"\')]}')
    if not stripped:
        return False

    if stripped[-1] not in ".!?":
        return False

    # Handle ellipsis - not a sentence end
    if stripped.endswith("..."):
        return False

    # Check for abbreviations
    base_word = stripped.rstrip(".!?").lower()
    if base_word in ABBREVIATIONS:
        return False

    # Single letter followed by period (initials) - not sentence end unless last word
    if len(base_word) == 1 and stripped.endswith(".") and next_word:
        return False

    return True


def tokenize_text(
    text: str,
    file_path: str = "",
    file_hash: str = "",
    chapters: list[Chapter] | None = None,
) -> Document:
    """Tokenize text into a Document with Word objects.

    Splits text into paragraphs, sentences, and words while tracking
    paragraph and sentence boundaries.

    If chapters are provided (from EPUB), maps chapter character positions
    to word indices for navigation.
    """
    # Normalize line endings and split into paragraphs
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    paragraphs = re.split(r"\n\s*\n+", text)

    words: list[Word] = []
    char_to_word: list[tuple[int, int]] = []  # (char_start, word_index) for chapter mapping

    current_char = 0

    for para_idx, paragraph in enumerate(paragraphs):
        # Skip empty paragraphs
        paragraph_stripped = paragraph.strip()
        if not paragraph_stripped:
            # Account for paragraph break
            current_char += len(paragraph) + 2
            continue

        # Find where this paragraph actually starts in original text
        para_start = text.find(paragraph_stripped, current_char)
        if para_start == -1:
            para_start = current_char

        # Split paragraph into words
        para_words = paragraph_stripped.split()
        if not para_words:
            current_char = para_start + len(paragraph_stripped) + 2
            continue

        word_char_pos = para_start
        for word_idx, word_text in enumerate(para_words):
            # Track character position for this word
            char_to_word.append((word_char_pos, len(words)))

            is_last_in_para = word_idx == len(para_words) - 1
            next_word = para_words[word_idx + 1] if word_idx < len(para_words) - 1 else None

            # Determine if this is a sentence end
            is_sentence_end = _is_sentence_end(word_text, next_word)

            # If it's the last word in paragraph, it's also a paragraph end
            is_para_end = is_last_in_para

            word = Word(
                text=word_text,
                orp_index=calculate_orp(word_text),
                paragraph_end=is_para_end,
                sentence_end=is_sentence_end or is_para_end,
            )
            words.append(word)

            # Move char position past this word and following space
            word_char_pos += len(word_text) + 1

        current_char = para_start + len(paragraph_stripped) + 2

    # Map chapters to word indices
    chapter_markers: list[ChapterMarker] = []
    if chapters:
        for chapter in chapters:
            # Find the word index for this chapter's character position
            word_index = 0
            for char_pos, w_idx in char_to_word:
                if char_pos >= chapter.start_char:
                    word_index = w_idx
                    break
                word_index = w_idx

            chapter_markers.append(ChapterMarker(
                title=chapter.title,
                word_index=word_index,
                level=chapter.level,
            ))

    return Document(
        words=words,
        total_words=len(words),
        file_path=file_path,
        file_hash=file_hash,
        chapters=chapter_markers,
    )
