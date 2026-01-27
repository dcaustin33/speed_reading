import hashlib
import re
import zipfile
from dataclasses import dataclass
from pathlib import Path

import ebooklib
from ebooklib import epub


class DRMError(Exception):
    """Raised when attempting to open a DRM-protected file."""

    pass


class FileLoadError(Exception):
    """Raised when a file cannot be loaded."""

    pass


@dataclass
class Chapter:
    """Represents a chapter/section in a book."""

    title: str
    start_char: int  # Character offset where chapter starts
    level: int = 0  # Nesting level (0 = top level)


@dataclass
class LoadedFile:
    """Result of loading a file."""

    content: str
    file_hash: str
    chapters: list[Chapter]


def has_drm(epub_path: str | Path) -> bool:
    """Check if an EPUB file contains DRM encryption."""
    try:
        with zipfile.ZipFile(epub_path, "r") as zf:
            if "META-INF/encryption.xml" in zf.namelist():
                encryption_content = zf.read("META-INF/encryption.xml").decode("utf-8")
                drm_indicators = [
                    "http://ns.adobe.com/adept",
                    "http://www.w3.org/2001/04/xmlenc",
                    "EncryptedData",
                ]
                # Check for actual content encryption, not just font obfuscation
                if any(indicator in encryption_content for indicator in drm_indicators):
                    # Font obfuscation uses idpf algorithm, not actual DRM
                    if "idpf" in encryption_content.lower() and "EncryptedData" not in encryption_content:
                        return False
                    return True
        return False
    except (zipfile.BadZipFile, KeyError, UnicodeDecodeError):
        return False


def _calculate_hash(content: str) -> str:
    """Calculate SHA256 hash of content."""
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def _load_txt(path: Path) -> str:
    """Load plain text file."""
    encodings = ["utf-8", "utf-8-sig", "latin-1", "cp1252"]
    for encoding in encodings:
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    raise FileLoadError(f"Could not decode file with any supported encoding: {path}")


def _strip_markdown(text: str) -> str:
    """Strip markdown formatting from text."""
    # Remove code blocks
    text = re.sub(r"```[\s\S]*?```", "", text)
    text = re.sub(r"`[^`]+`", "", text)

    # Remove headers (keep the text)
    text = re.sub(r"^#{1,6}\s*", "", text, flags=re.MULTILINE)

    # Remove bold/italic
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    text = re.sub(r"__([^_]+)__", r"\1", text)
    text = re.sub(r"_([^_]+)_", r"\1", text)

    # Remove images (must be before links since images are ![...](...))
    text = re.sub(r"!\[([^\]]*)\]\([^)]+\)", "", text)

    # Remove links, keep text
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)

    # Remove horizontal rules
    text = re.sub(r"^[-*_]{3,}\s*$", "", text, flags=re.MULTILINE)

    # Remove blockquotes marker
    text = re.sub(r"^>\s*", "", text, flags=re.MULTILINE)

    # Remove list markers
    text = re.sub(r"^[\s]*[-*+]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[\s]*\d+\.\s+", "", text, flags=re.MULTILINE)

    return text


def _load_markdown(path: Path) -> str:
    """Load and strip markdown file."""
    text = _load_txt(path)
    return _strip_markdown(text)


def _strip_html(content: str) -> str:
    """Strip HTML tags and decode entities."""
    clean = re.sub(r"<script[^>]*>[\s\S]*?</script>", "", content)
    clean = re.sub(r"<style[^>]*>[\s\S]*?</style>", "", clean)
    clean = re.sub(r"<[^>]+>", " ", clean)
    # Decode HTML entities
    clean = clean.replace("&nbsp;", " ")
    clean = clean.replace("&amp;", "&")
    clean = clean.replace("&lt;", "<")
    clean = clean.replace("&gt;", ">")
    clean = clean.replace("&quot;", '"')
    clean = clean.replace("&#39;", "'")
    clean = clean.replace("&rsquo;", "'")
    clean = clean.replace("&lsquo;", "'")
    clean = clean.replace("&rdquo;", '"')
    clean = clean.replace("&ldquo;", '"')
    clean = clean.replace("&mdash;", "—")
    clean = clean.replace("&ndash;", "–")
    clean = clean.replace("&hellip;", "...")
    # Normalize whitespace
    clean = re.sub(r"\s+", " ", clean).strip()
    return clean


def _extract_toc(book: epub.EpubBook) -> list[tuple[str, str, int]]:
    """Extract table of contents from EPUB.

    Returns list of (title, href, level) tuples.
    """
    toc_items = []

    def process_toc(items, level=0):
        for item in items:
            if isinstance(item, tuple):
                # It's a section with nested items
                section, children = item
                toc_items.append((section.title, "", level))
                process_toc(children, level + 1)
            elif isinstance(item, epub.Link):
                toc_items.append((item.title, item.href, level))

    process_toc(book.toc)
    return toc_items


def _load_epub(path: Path) -> tuple[str, list[Chapter]]:
    """Load EPUB file, checking for DRM first.

    Returns (content, chapters) tuple.
    """
    if has_drm(path):
        raise DRMError(
            "This EPUB file is DRM-protected and cannot be opened. "
            "DRM (Digital Rights Management) encryption prevents third-party "
            "applications from reading the content. Please use a DRM-free version "
            "of this file, or export from your ebook provider if they allow it."
        )

    try:
        book = epub.read_epub(str(path), options={"ignore_ncx": False})
    except Exception as e:
        raise FileLoadError(f"Failed to parse EPUB file: {e}") from e

    # Extract TOC
    toc_items = _extract_toc(book)

    # Build href to title mapping
    href_to_toc = {}
    for title, href, level in toc_items:
        if href:
            # Normalize href (remove anchors)
            base_href = href.split("#")[0]
            if base_href not in href_to_toc:
                href_to_toc[base_href] = (title, level)

    # Process content and track chapters
    text_parts = []
    chapters = []
    current_pos = 0

    for item in book.get_items():
        if item.get_type() == ebooklib.ITEM_DOCUMENT:
            # Check if this item starts a chapter
            item_href = item.get_name()
            if item_href in href_to_toc:
                title, level = href_to_toc[item_href]
                chapters.append(Chapter(title=title, start_char=current_pos, level=level))

            content = item.get_content().decode("utf-8", errors="ignore")
            clean = _strip_html(content)

            if clean:
                text_parts.append(clean)
                current_pos += len(clean) + 2  # +2 for paragraph break

    if not text_parts:
        raise FileLoadError("EPUB file contains no readable text content")

    # Join chapters with paragraph breaks
    content = "\n\n".join(text_parts)

    return content, chapters


def load_file(path: str | Path) -> tuple[str, str]:
    """Load a file and return its text content and hash.

    Supports .txt, .md, and .epub files.

    Note: For EPUB files with chapter info, use load_file_with_chapters().

    Returns:
        Tuple of (text_content, file_hash)

    Raises:
        FileLoadError: If file cannot be loaded
        DRMError: If EPUB is DRM-protected
        FileNotFoundError: If file does not exist
    """
    path = Path(path)

    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    suffix = path.suffix.lower()

    if suffix == ".txt":
        content = _load_txt(path)
    elif suffix == ".md":
        content = _load_markdown(path)
    elif suffix == ".epub":
        content, _ = _load_epub(path)
    else:
        raise FileLoadError(f"Unsupported file format: {suffix}")

    return content, _calculate_hash(content)


def load_file_with_chapters(path: str | Path) -> LoadedFile:
    """Load a file and return content, hash, and chapter information.

    Supports .txt, .md, and .epub files.
    For non-EPUB files, chapters list will be empty.

    Returns:
        LoadedFile with content, file_hash, and chapters

    Raises:
        FileLoadError: If file cannot be loaded
        DRMError: If EPUB is DRM-protected
        FileNotFoundError: If file does not exist
    """
    path = Path(path)

    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    suffix = path.suffix.lower()
    chapters = []

    if suffix == ".txt":
        content = _load_txt(path)
    elif suffix == ".md":
        content = _load_markdown(path)
    elif suffix == ".epub":
        content, chapters = _load_epub(path)
    else:
        raise FileLoadError(f"Unsupported file format: {suffix}")

    return LoadedFile(
        content=content,
        file_hash=_calculate_hash(content),
        chapters=chapters,
    )
