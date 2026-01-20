import re
from dataclasses import dataclass

from speed_reading.core.orp import calculate_orp

# Common abbreviations that shouldn't end sentences
ABBREVIATIONS = frozenset([
    "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "vs", "etc", "inc", "ltd",
    "corp", "co", "st", "ave", "blvd", "rd", "apt", "no", "vol", "pg", "pp",
    "fig", "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "oct",
    "nov", "dec", "mon", "tue", "wed", "thu", "fri", "sat", "sun",
])


@dataclass
class Word:
    text: str
    orp_index: int
    paragraph_end: bool
    sentence_end: bool


@dataclass
class Document:
    words: list[Word]
    total_words: int
    file_path: str
    file_hash: str


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


def tokenize_text(text: str, file_path: str = "", file_hash: str = "") -> Document:
    """Tokenize text into a Document with Word objects.

    Splits text into paragraphs, sentences, and words while tracking
    paragraph and sentence boundaries.
    """
    # Normalize line endings and split into paragraphs
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    paragraphs = re.split(r"\n\s*\n+", text)

    words: list[Word] = []

    for para_idx, paragraph in enumerate(paragraphs):
        # Skip empty paragraphs
        paragraph = paragraph.strip()
        if not paragraph:
            continue

        # Split paragraph into words
        para_words = paragraph.split()
        if not para_words:
            continue

        for word_idx, word_text in enumerate(para_words):
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

    return Document(
        words=words,
        total_words=len(words),
        file_path=file_path,
        file_hash=file_hash,
    )
