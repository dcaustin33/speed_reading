import hashlib
import re
import zipfile
from pathlib import Path

import ebooklib
from ebooklib import epub


class DRMError(Exception):
    """Raised when attempting to open a DRM-protected file."""

    pass


class FileLoadError(Exception):
    """Raised when a file cannot be loaded."""

    pass


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


def _load_epub(path: Path) -> str:
    """Load EPUB file, checking for DRM first."""
    if has_drm(path):
        raise DRMError(
            "This EPUB file is DRM-protected and cannot be opened. "
            "DRM (Digital Rights Management) encryption prevents third-party "
            "applications from reading the content. Please use a DRM-free version "
            "of this file, or export from your ebook provider if they allow it."
        )

    try:
        book = epub.read_epub(str(path), options={"ignore_ncx": True})
    except Exception as e:
        raise FileLoadError(f"Failed to parse EPUB file: {e}") from e

    text_parts = []

    for item in book.get_items():
        if item.get_type() == ebooklib.ITEM_DOCUMENT:
            content = item.get_content().decode("utf-8", errors="ignore")
            # Strip HTML tags
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
            # Normalize whitespace
            clean = re.sub(r"\s+", " ", clean).strip()
            if clean:
                text_parts.append(clean)

    if not text_parts:
        raise FileLoadError("EPUB file contains no readable text content")

    # Join chapters with paragraph breaks
    return "\n\n".join(text_parts)


def load_file(path: str | Path) -> tuple[str, str]:
    """Load a file and return its text content and hash.

    Supports .txt, .md, and .epub files.

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
        content = _load_epub(path)
    else:
        raise FileLoadError(f"Unsupported file format: {suffix}")

    return content, _calculate_hash(content)
