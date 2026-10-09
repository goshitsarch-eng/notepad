/// A selection as the two offsets that define it. Kept apart from Flutter's type so the
/// history stays plain Dart.
class SelectionOffsets {
  const SelectionOffsets(this.base, this.extent);

  final int base;
  final int extent;

  @override
  bool operator ==(Object other) =>
      other is SelectionOffsets && other.base == base && other.extent == extent;

  @override
  int get hashCode => Object.hash(base, extent);
}

/// One change to a document: [removed] stood at [offset] and [inserted] took its place.
class HistoryEntry {
  HistoryEntry({
    required this.offset,
    required this.removed,
    required this.inserted,
    required this.before,
    required this.after,
    required this.time,
  });

  int offset;
  String removed;
  String inserted;

  /// The selection before the change and after it.
  SelectionOffsets before;
  SelectionOffsets after;
  DateTime time;

  int get characters => removed.length + inserted.length;
}

/// The undo list of a document that is edited through a window of its text. The window can
/// move between two edits, so the list keeps each change as an offset in the whole text
/// instead of a copy of the window.
///
/// Typing and deleting one character at a time join into one entry when they follow each
/// other closely, as the editor's own undo does.
class EditHistory {
  EditHistory({
    this.maxEntries = 200,
    this.maxCharacters = 16 * 1024 * 1024,
    this.joinWithin = const Duration(milliseconds: 600),
    this.clock = DateTime.now,
  });

  final int maxEntries;

  /// Cap on the text the list holds. The oldest entries go first.
  final int maxCharacters;
  final Duration joinWithin;
  final DateTime Function() clock;

  /// A paste is never joined to the typing before it.
  static const _joinableLength = 64;

  final List<HistoryEntry> _entries = [];
  int _characters = 0;

  bool get canUndo => _entries.isNotEmpty;

  int get length => _entries.length;

  void record({
    required int offset,
    required String removed,
    required String inserted,
    required SelectionOffsets before,
    required SelectionOffsets after,
  }) {
    if (removed.isEmpty && inserted.isEmpty) return;
    final now = clock();
    if (_entries.isNotEmpty &&
        _tryJoin(offset, removed, inserted, after, now)) {
      return;
    }
    final entry = HistoryEntry(
      offset: offset,
      removed: removed,
      inserted: inserted,
      before: before,
      after: after,
      time: now,
    );
    _entries.add(entry);
    _characters += entry.characters;
    _trim();
  }

  bool _tryJoin(
    int offset,
    String removed,
    String inserted,
    SelectionOffsets after,
    DateTime now,
  ) {
    final last = _entries.last;
    if (now.difference(last.time) > joinWithin) return false;
    if (last.characters > _joinableLength ||
        removed.length + inserted.length > _joinableLength) {
      return false;
    }
    final typing =
        last.removed.isEmpty && removed.isEmpty && inserted.isNotEmpty;
    if (typing && offset == last.offset + last.inserted.length) {
      last.inserted += inserted;
      _characters += inserted.length;
    } else {
      final deleting = last.inserted.isEmpty && inserted.isEmpty;
      if (!deleting || removed.isEmpty) return false;
      if (offset + removed.length == last.offset) {
        // Backspace: the new text lies just before what was deleted.
        last.offset = offset;
        last.removed = removed + last.removed;
      } else if (offset == last.offset) {
        // Delete: the new text lies just after it.
        last.removed += removed;
      } else {
        return false;
      }
      _characters += removed.length;
    }
    last.after = after;
    last.time = now;
    return true;
  }

  /// Takes the newest entry off the list and returns it, or null when there is none.
  HistoryEntry? takeUndo() {
    if (_entries.isEmpty) return null;
    final entry = _entries.removeLast();
    _characters -= entry.characters;
    return entry;
  }

  void clear() {
    _entries.clear();
    _characters = 0;
  }

  void _trim() {
    while (_entries.length > 1 &&
        (_entries.length > maxEntries || _characters > maxCharacters)) {
      _characters -= _entries.removeAt(0).characters;
    }
  }
}
