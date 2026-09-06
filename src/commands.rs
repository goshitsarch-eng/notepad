// SPDX-License-Identifier: GPL-3.0-or-later

//! Editor-level Find / Replace / Go To helpers.
//!
//! All helpers operate on a UTF-8 document string and byte offsets so tests can
//! exercise the same code path as the UI without a GUI toolkit.

/// Result of [`replace_and_find_next`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReplaceResult {
    /// The current selection was replaced. `next` is the following match, if any.
    Replaced {
        text: String,
        next: Option<(usize, usize)>,
    },
    /// Nothing was replaced; a later match was selected.
    Found { range: (usize, usize) },
}

fn match_prefix_ci(hay: &str, needle: &str) -> Option<usize> {
    let mut hay_chars = hay.char_indices();
    let mut needle_chars = needle.chars();
    let mut end = 0;
    loop {
        match (hay_chars.next(), needle_chars.next()) {
            (_, None) => return Some(end),
            (None, Some(_)) => return None,
            (Some((i, hay_ch)), Some(needle_ch)) => {
                if hay_ch.to_lowercase().eq(needle_ch.to_lowercase()) {
                    end = i + hay_ch.len_utf8();
                } else {
                    return None;
                }
            }
        }
    }
}

fn find_from(
    haystack: &str,
    needle: &str,
    mut start: usize,
    match_case: bool,
) -> Option<(usize, usize)> {
    if needle.is_empty() || start > haystack.len() {
        return None;
    }
    if !haystack.is_char_boundary(start) {
        start = haystack
            .char_indices()
            .map(|(i, _)| i)
            .find(|&i| i > start)
            .unwrap_or(haystack.len());
    }
    let hay = &haystack[start..];
    if match_case {
        hay.find(needle).map(|i| {
            let from = start + i;
            (from, from + needle.len())
        })
    } else {
        for (idx, _) in hay.char_indices() {
            if let Some(len) = match_prefix_ci(&hay[idx..], needle) {
                let from = start + idx;
                return Some((from, from + len));
            }
        }
        None
    }
}

/// Whether `selected` matches `needle`, optionally case-sensitively.
#[must_use]
pub fn selection_matches(selected: &str, needle: &str, match_case: bool) -> bool {
    if needle.is_empty() || selected.is_empty() {
        return false;
    }
    if match_case {
        selected == needle
    } else {
        selected.to_lowercase() == needle.to_lowercase()
    }
}

/// Find the next match after `start` (byte offset). Wraps to the beginning when
/// `wrap` is true and nothing is found after `start`.
#[must_use]
pub fn find_next(
    text: &str,
    start: usize,
    needle: &str,
    match_case: bool,
    wrap: bool,
) -> Option<(usize, usize)> {
    if needle.is_empty() {
        return None;
    }
    if let Some(found) = find_from(text, needle, start, match_case) {
        return Some(found);
    }
    if wrap && start > 0 {
        find_from(text, needle, 0, match_case)
    } else {
        None
    }
}

/// Replace the current match if `selection` matches, then jump to the next one.
#[must_use]
pub fn replace_and_find_next(
    text: &str,
    selection: Option<(usize, usize)>,
    needle: &str,
    replacement: &str,
    match_case: bool,
    wrap: bool,
) -> Option<ReplaceResult> {
    if needle.is_empty() {
        return None;
    }
    if let Some((start, end)) = selection {
        if end <= text.len()
            && start <= end
            && text.is_char_boundary(start)
            && text.is_char_boundary(end)
        {
            let selected = &text[start..end];
            if selection_matches(selected, needle, match_case) {
                let mut new_text =
                    String::with_capacity(text.len() - (end - start) + replacement.len());
                new_text.push_str(&text[..start]);
                new_text.push_str(replacement);
                new_text.push_str(&text[end..]);
                let continue_at = start + replacement.len();
                let next = find_next(&new_text, continue_at, needle, match_case, wrap);
                return Some(ReplaceResult::Replaced {
                    text: new_text,
                    next,
                });
            }
        }
        let start = selection.map_or(0, |(_, end)| end);
        return find_next(text, start, needle, match_case, wrap)
            .map(|range| ReplaceResult::Found { range });
    }
    find_next(text, 0, needle, match_case, wrap).map(|range| ReplaceResult::Found { range })
}

/// Replace every match in the document. Returns the new text and replacement count.
#[must_use]
pub fn replace_all(
    text: &str,
    needle: &str,
    replacement: &str,
    match_case: bool,
) -> (String, usize) {
    if needle.is_empty() {
        return (text.to_string(), 0);
    }
    let mut out = String::with_capacity(text.len());
    let mut cursor = 0;
    let mut count = 0;
    while let Some((start, end)) = find_from(text, needle, cursor, match_case) {
        out.push_str(&text[cursor..start]);
        out.push_str(replacement);
        cursor = end;
        count += 1;
        if start == end {
            break;
        }
    }
    out.push_str(&text[cursor..]);
    (out, count)
}

/// Number of lines in `text`. An empty document is one line, matching Notepad.
#[must_use]
#[allow(dead_code)]
pub fn line_count(text: &str) -> usize {
    text.split('\n').count()
}

/// Byte offset of the start of a 1-based line number. `None` if out of range.
#[must_use]
pub fn goto_line(text: &str, line_number: usize) -> Option<usize> {
    if line_number < 1 {
        return None;
    }
    let lines: Vec<&str> = text.split('\n').collect();
    if line_number > lines.len() {
        return None;
    }
    let mut offset = 0;
    for line in lines.iter().take(line_number - 1) {
        offset += line.len() + 1;
    }
    Some(offset)
}

/// 1-based line and column of a byte offset.
#[must_use]
pub fn line_col_at(text: &str, mut offset: usize) -> (usize, usize) {
    offset = offset.min(text.len());
    while offset > 0 && !text.is_char_boundary(offset) {
        offset -= 1;
    }
    let prefix = &text[..offset];
    let line = prefix.bytes().filter(|&b| b == b'\n').count() + 1;
    let col = prefix
        .rsplit('\n')
        .next()
        .map_or(1, |s| s.chars().count() + 1);
    (line, col)
}

/// Convert a 0-based line/column to a byte offset.
///
/// If `column` is past the end of `line`, the offset of that line's newline
/// (or EOF on the last line) is returned rather than walking into later lines.
#[must_use]
pub fn offset_at_line_col(text: &str, line: usize, column: usize) -> usize {
    let mut current_line = 0usize;
    let mut current_col = 0usize;
    for (i, ch) in text.char_indices() {
        if current_line == line && current_col == column {
            return i;
        }
        if ch == '\n' {
            if current_line == line {
                return i;
            }
            current_line += 1;
            current_col = 0;
        } else {
            current_col += 1;
        }
    }
    text.len()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_first_match_from_start() {
        let found = find_next("one two one", 0, "one", false, true).unwrap();
        assert_eq!(found, (0, 3));
    }

    #[test]
    fn skips_current_selection_to_next_match() {
        let first = find_next("one two one", 0, "one", false, true).unwrap();
        let second = find_next("one two one", first.1, "one", false, true).unwrap();
        assert_eq!(second, (8, 11));
    }

    #[test]
    fn wraps_around_to_first_match() {
        let first = find_next("one two one", 0, "one", false, true).unwrap();
        let second = find_next("one two one", first.1, "one", false, true).unwrap();
        let wrapped = find_next("one two one", second.1, "one", false, true).unwrap();
        assert_eq!(wrapped, (0, 3));
    }

    #[test]
    fn case_insensitive_by_default() {
        let found = find_next("Hello HELLO", 0, "hello", false, true).unwrap();
        assert_eq!(&"Hello HELLO"[found.0..found.1], "Hello");
    }

    #[test]
    fn match_case() {
        let found = find_next("Hello hello", 0, "hello", true, true).unwrap();
        assert_eq!(found, (6, 11));
        assert_eq!(&"Hello hello"[found.0..found.1], "hello");
    }

    #[test]
    fn missing_text_returns_none() {
        assert!(find_next("hello", 0, "xyz", false, true).is_none());
        assert!(find_next("hello", 0, "", false, true).is_none());
    }

    #[test]
    fn replace_current_then_find_next() {
        let first = find_next("one two one", 0, "one", false, true).unwrap();
        let result =
            replace_and_find_next("one two one", Some(first), "one", "ONE", false, true).unwrap();
        match result {
            ReplaceResult::Replaced { text, next } => {
                assert_eq!(text, "ONE two one");
                assert_eq!(next, Some((8, 11)));
                assert_eq!(&text[next.unwrap().0..next.unwrap().1], "one");
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn replace_finds_first_if_nothing_selected() {
        let result = replace_and_find_next("one two one", None, "one", "ONE", false, true).unwrap();
        assert_eq!(result, ReplaceResult::Found { range: (0, 3) });
    }

    #[test]
    fn replace_all_all_matches() {
        let (text, count) = replace_all("one two one two one", "one", "ONE", false);
        assert_eq!(count, 3);
        assert_eq!(text, "ONE two ONE two ONE");
    }

    #[test]
    fn replace_all_is_case_sensitive_when_asked() {
        let (text, count) = replace_all("One one ONE", "one", "x", true);
        assert_eq!(count, 1);
        assert_eq!(text, "One x ONE");
    }

    #[test]
    fn replace_all_empty_needle_is_noop() {
        let (text, count) = replace_all("abc", "", "x", false);
        assert_eq!(count, 0);
        assert_eq!(text, "abc");
    }

    #[test]
    fn selection_matches_ignores_case_by_default() {
        assert!(selection_matches("Hello", "hello", false));
        assert!(!selection_matches("Hello", "hello", true));
    }

    #[test]
    fn empty_document_has_one_line() {
        assert_eq!(line_count(""), 1);
        assert_eq!(line_count("a\nb"), 2);
    }

    #[test]
    fn goes_to_requested_line() {
        let offset = goto_line("a\nb\nc", 2).unwrap();
        assert_eq!(offset, 2);
        assert_eq!(line_col_at("a\nb\nc", offset), (2, 1));
    }

    #[test]
    fn rejects_out_of_range() {
        assert!(goto_line("a\nb", 0).is_none());
        assert!(goto_line("a\nb", 3).is_none());
        assert!(goto_line("a\nb", 2).is_some());
    }

    #[test]
    fn rejects_far_out_of_range() {
        assert!(goto_line("a\nb", 100).is_none());
    }

    #[test]
    fn line_col_at_snaps_mid_utf8_to_previous_boundary() {
        let text = "é\nx";
        assert_eq!(text.as_bytes()[0], 0xc3);
        assert_eq!(line_col_at(text, 1), (1, 1));
        assert_eq!(line_col_at(text, 2), (1, 2));
        assert_eq!(line_col_at(text, 3), (2, 1));
    }

    #[test]
    fn offset_at_line_col_stays_on_requested_line() {
        let text = "ab\ncd";
        assert_eq!(offset_at_line_col(text, 0, 0), 0);
        assert_eq!(offset_at_line_col(text, 0, 2), 2);
        assert_eq!(offset_at_line_col(text, 0, 99), 2);
        assert_eq!(offset_at_line_col(text, 1, 0), 3);
        assert_eq!(offset_at_line_col(text, 1, 99), 5);
    }

    #[test]
    fn find_from_snaps_forward_from_mid_utf8_start() {
        let text = "éabc";
        assert_eq!(find_from(text, "abc", 1, true), Some((2, 5)));
        assert!(find_from(text, "abc", text.len() + 1, true).is_none());
    }

    #[test]
    fn line_col_and_find_handle_cjk() {
        let text = "日本語\nnext";
        assert_eq!(line_col_at(text, 0), (1, 1));
        assert_eq!(line_col_at(text, "日".len()), (1, 2));
        assert_eq!(line_col_at(text, "日本語".len()), (1, 4));
        let mid = 1;
        assert!(!text.is_char_boundary(mid));
        assert_eq!(line_col_at(text, mid), (1, 1));
        assert_eq!(
            find_next(text, mid, "next", true, true),
            Some(("日本語\n".len(), text.len()))
        );
        assert_eq!(offset_at_line_col(text, 0, 99), "日本語".len());
        assert_eq!(offset_at_line_col(text, 1, 0), "日本語\n".len());
    }

    #[test]
    fn find_next_wraps_after_last_match() {
        let text = "日本語 one 日本語";
        let first = find_next(text, 0, "日本語", true, true).unwrap();
        assert_eq!(first, (0, "日本語".len()));
        let second = find_next(text, first.1, "日本語", true, true).unwrap();
        assert_eq!(&text[second.0..second.1], "日本語");
        let wrapped = find_next(text, second.1, "日本語", true, true).unwrap();
        assert_eq!(wrapped, first);
    }
}
