"""Editor-level Find / Replace / Go To helpers for the NotePad editor (Qt 6).

All helpers operate on a ``QPlainTextEdit`` so that tests can exercise the
exact same code path as the UI. Selection text is normalized: Qt reports
paragraph separators (U+2029) for multi-line selections, callers expect ``\\n``.
"""

from PySide6.QtGui import QTextCursor, QTextDocument

PARAGRAPH_SEPARATOR = "\u2029"


def _find(document, text, cursor, match_case):
    flags = QTextDocument.FindFlag(0)
    if match_case:
        flags |= QTextDocument.FindFlag.FindCaseSensitively
    return document.find(text, cursor, flags)


def selected_text(edit):
    cursor = edit.textCursor()
    if not cursor.hasSelection():
        return ""
    return cursor.selectedText().replace(PARAGRAPH_SEPARATOR, "\n")


def selection_matches(edit, text, match_case=False):
    if not text:
        return False
    selected = selected_text(edit)
    if not selected:
        return False
    if match_case:
        return selected == text
    return selected.casefold() == text.casefold()


def find_next(edit, text, match_case=False, wrap=True):
    """Select the next match after the current selection/cursor.

    Returns True if a match was found and selected.
    """
    if not text:
        return False
    document = edit.document()
    cursor = edit.textCursor()
    if cursor.hasSelection():
        cursor.setPosition(cursor.selectionEnd())
    found = _find(document, text, cursor, match_case)
    if found.isNull() and wrap:
        found = _find(document, text, QTextCursor(document), match_case)
    if found.isNull():
        return False
    edit.setTextCursor(found)
    edit.ensureCursorVisible()
    return True


def replace_selection(edit, replacement):
    if not edit.textCursor().hasSelection():
        return False
    cursor = edit.textCursor()
    cursor.beginEditBlock()
    cursor.insertText(replacement)
    cursor.endEditBlock()
    edit.setTextCursor(cursor)
    return True


def replace_and_find_next(edit, text, replacement, match_case=False, wrap=True):
    """Replace the current match if selected, then jump to the next one.

    Returns ``"replaced"`` if a replacement happened, ``"found"`` if only a
    later match was selected, or ``None`` if nothing matched.
    """
    if not text:
        return None
    did_replace = False
    if selection_matches(edit, text, match_case):
        replace_selection(edit, replacement)
        did_replace = True
    found = find_next(edit, text, match_case=match_case, wrap=wrap)
    if did_replace:
        return "replaced"
    if found:
        return "found"
    return None


def replace_all(edit, text, replacement, match_case=False):
    """Replace every match in the document. Returns the number of replacements."""
    if not text:
        return 0
    document = edit.document()
    cursor = QTextCursor(document)
    cursor.beginEditBlock()
    count = 0
    while True:
        found = _find(document, text, cursor, match_case)
        if found.isNull():
            break
        found.insertText(replacement)
        cursor = found
        count += 1
    cursor.endEditBlock()
    return count


def goto_line(edit, line_number):
    """Move the cursor to the start of a 1-based line number.

    Returns True if the line exists.
    """
    if line_number < 1:
        return False
    block = edit.document().findBlockByLineNumber(line_number - 1)
    # findBlockByLineNumber clamps to the last block, so verify the range.
    if not block.isValid() or block.blockNumber() != line_number - 1:
        return False
    edit.setTextCursor(QTextCursor(block))
    edit.ensureCursorVisible()
    return True
