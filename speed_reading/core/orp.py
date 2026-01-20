from speed_reading.utils.constants import ORP_POSITIONS, ORP_DEFAULT_POSITION


def calculate_orp(word: str) -> int:
    """Calculate the Optimal Recognition Point index for a word.

    The ORP is the letter position where the eye naturally focuses when reading.
    For most words, this is slightly left of center.

    Returns the 0-indexed position of the ORP letter.
    """
    length = len(word)
    if length == 0:
        return 0
    return ORP_POSITIONS.get(length, ORP_DEFAULT_POSITION)
