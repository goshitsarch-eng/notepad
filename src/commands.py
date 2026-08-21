"""Buffer-level Find / Replace / Go To helpers for the NotePad editor."""

from gi.repository import Gtk, Pango


def search_flags(match_case=False):
    flags = Gtk.TextSearchFlags.VISIBLE_ONLY
    if not match_case:
        flags |= Gtk.TextSearchFlags.CASE_INSENSITIVE
    return flags


def selected_text(buffer):
    bounds = buffer.get_selection_bounds()
    if not bounds:
        return ""
    return buffer.get_text(bounds[0], bounds[1], True)


def selection_matches(buffer, text, match_case=False):
    if not text:
        return False
    selected = selected_text(buffer)
    if not selected:
        return False
    if match_case:
        return selected == text
    return selected.casefold() == text.casefold()


def _search_from(buffer, start, text, flags, wrap):
    match = start.forward_search(text, flags, None)
    if match or not wrap:
        return match
    return buffer.get_start_iter().forward_search(text, flags, None)


def find_next(buffer, text, match_case=False, wrap=True):
    """Select the next match after the current selection/cursor.

    Returns True if a match was found and selected.
    """
    if not text:
        return False
    flags = search_flags(match_case)
    bounds = buffer.get_selection_bounds()
    if bounds:
        start = bounds[1]
    else:
        start = buffer.get_iter_at_mark(buffer.get_insert())
    match = _search_from(buffer, start, text, flags, wrap)
    if not match:
        return False
    found_start, found_end = match
    buffer.select_range(found_start, found_end)
    return True


def replace_selection(buffer, replacement):
    if not buffer.get_has_selection():
        return False
    buffer.begin_user_action()
    buffer.delete_selection(True, True)
    buffer.insert_at_cursor(replacement)
    buffer.end_user_action()
    return True


def replace_and_find_next(buffer, text, replacement, match_case=False, wrap=True):
    """Replace the current match if selected, then jump to the next one.

    Returns ``"replaced"`` if a replacement happened, ``"found"`` if only a
    later match was selected, or ``None`` if nothing matched.
    """
    if not text:
        return None
    did_replace = False
    if selection_matches(buffer, text, match_case):
        replace_selection(buffer, replacement)
        did_replace = True
    found = find_next(buffer, text, match_case=match_case, wrap=wrap)
    if did_replace:
        return "replaced"
    if found:
        return "found"
    return None


def replace_all(buffer, text, replacement, match_case=False):
    """Replace every match in the document. Returns the number of replacements."""
    if not text:
        return 0
    flags = search_flags(match_case)
    buffer.begin_user_action()
    count = 0
    cursor = buffer.get_start_iter()
    while True:
        match = cursor.forward_search(text, flags, None)
        if not match:
            break
        start, end = match
        offset = start.get_offset()
        buffer.delete(start, end)
        insert_at = buffer.get_iter_at_offset(offset)
        buffer.insert(insert_at, replacement)
        cursor = buffer.get_iter_at_offset(offset + len(replacement))
        count += 1
    buffer.end_user_action()
    return count


def goto_line(buffer, line_number):
    """Move the cursor to the start of a 1-based line number.

    Returns True if the line exists.
    """
    if line_number < 1:
        return False
    if line_number > buffer.get_line_count():
        return False
    result = buffer.get_iter_at_line(line_number - 1)
    # PyGObject maps the out-iter as (ok, iter).
    if isinstance(result, tuple):
        ok, iterator = result[0], result[1]
        if not ok:
            return False
    else:
        iterator = result
    buffer.place_cursor(iterator)
    return True


def font_css(font_desc):
    """Build a CSS rule that applies ``font_desc`` to the editor TextView."""
    family = font_desc.get_family() or "Monospace"
    family_css = family.replace("\\", "\\\\").replace('"', '\\"')
    size = font_desc.get_size()
    if size <= 0:
        size_pt = 11.0
    elif font_desc.get_size_is_absolute():
        size_pt = (size / Pango.SCALE) * 72.0 / 96.0
    else:
        size_pt = size / Pango.SCALE
    weight = int(font_desc.get_weight()) or 400
    style = {
        Pango.Style.ITALIC: "italic",
        Pango.Style.OBLIQUE: "oblique",
    }.get(font_desc.get_style(), "normal")
    return (
        f'.notepad-text {{ font-family: "{family_css}"; '
        f"font-size: {size_pt:g}pt; font-weight: {weight}; "
        f"font-style: {style}; }}"
    )
