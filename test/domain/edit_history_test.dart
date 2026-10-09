import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/text/edit_history.dart';

void main() {
  late DateTime now;
  late EditHistory history;

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    history = EditHistory(clock: () => now);
  });

  void type(int offset, String text, {int tick = 50}) {
    now = now.add(Duration(milliseconds: tick));
    history.record(
      offset: offset,
      removed: '',
      inserted: text,
      before: SelectionOffsets(offset, offset),
      after: SelectionOffsets(offset + text.length, offset + text.length),
    );
  }

  void remove(int offset, String text, {int tick = 50}) {
    now = now.add(Duration(milliseconds: tick));
    history.record(
      offset: offset,
      removed: text,
      inserted: '',
      before: SelectionOffsets(offset + text.length, offset + text.length),
      after: SelectionOffsets(offset, offset),
    );
  }

  test('starts empty and ignores a change that changes nothing', () {
    expect(history.canUndo, isFalse);
    history.record(
      offset: 0,
      removed: '',
      inserted: '',
      before: const SelectionOffsets(0, 0),
      after: const SelectionOffsets(0, 0),
    );
    expect(history.canUndo, isFalse);
    expect(history.takeUndo(), isNull);
  });

  test('typing one character after another is one entry', () {
    type(10, 'h');
    type(11, 'e');
    type(12, 'y');
    expect(history.length, 1);
    final entry = history.takeUndo()!;
    expect(entry.offset, 10);
    expect(entry.inserted, 'hey');
    expect(entry.before, const SelectionOffsets(10, 10));
    expect(entry.after, const SelectionOffsets(13, 13));
    expect(history.canUndo, isFalse);
  });

  test('a pause starts a new entry', () {
    type(10, 'a');
    type(11, 'b', tick: 2000);
    expect(history.length, 2);
  });

  test('typing somewhere else starts a new entry', () {
    type(10, 'a');
    type(50, 'b');
    expect(history.length, 2);
  });

  test('backspace and delete each join their own run', () {
    remove(9, 'c');
    remove(8, 'b');
    remove(7, 'a');
    expect(history.length, 1);
    var entry = history.takeUndo()!;
    expect(entry.offset, 7);
    expect(entry.removed, 'abc');

    remove(20, 'x');
    remove(20, 'y');
    expect(history.length, 1);
    entry = history.takeUndo()!;
    expect(entry.offset, 20);
    expect(entry.removed, 'xy');
  });

  test('a paste is never joined to the typing before it', () {
    type(0, 'a');
    type(1, 'b' * 100);
    expect(history.length, 2);
  });

  test('a replacement is an entry of its own', () {
    type(0, 'a');
    now = now.add(const Duration(milliseconds: 10));
    history.record(
      offset: 1,
      removed: 'x',
      inserted: 'y',
      before: const SelectionOffsets(1, 2),
      after: const SelectionOffsets(2, 2),
    );
    expect(history.length, 2);
  });

  test('the oldest entries go first when the list is too long or too big', () {
    final small = EditHistory(maxEntries: 3, clock: () => now);
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(seconds: 5));
      small.record(
        offset: i * 10,
        removed: '',
        inserted: 'x',
        before: SelectionOffsets(i * 10, i * 10),
        after: SelectionOffsets(i * 10 + 1, i * 10 + 1),
      );
    }
    expect(small.length, 3);
    expect(small.takeUndo()!.offset, 50);

    final big = EditHistory(maxCharacters: 100, clock: () => now);
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(seconds: 5));
      big.record(
        offset: 0,
        removed: '',
        inserted: 'y' * 60,
        before: const SelectionOffsets(0, 0),
        after: const SelectionOffsets(60, 60),
      );
    }
    expect(big.length, 1);
  });

  test('clear forgets everything', () {
    type(0, 'a');
    history.clear();
    expect(history.canUndo, isFalse);
  });
}
