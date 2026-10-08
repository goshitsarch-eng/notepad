import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';

void main() {
  test('defaults match XP Notepad: word wrap on, Lucida Console 10pt, 0.75/1 inch margins', () {
    const settings = NotepadSettings();
    expect(settings.wordWrap, isTrue);
    expect(settings.font.family, 'Lucida Console');
    expect(settings.font.sizePoints, 10);
    expect(settings.font.sizePixels, closeTo(13.333, 0.001));
    expect(settings.pageSetup.leftInches, 0.75);
    expect(settings.pageSetup.topInches, 1);
  });

  test('settings survive a JSON round trip', () {
    const original = NotepadSettings(
      wordWrap: false,
      statusBarVisible: false,
      font: EditorFont(
        family: 'Courier New',
        sizePoints: 12,
        style: FontFaceStyle.boldItalic,
      ),
      pageSetup: PageSetup(header: 'Report', leftInches: 1.25),
      lastDirectory: '/home/tester/docs',
      windowWidth: 640,
      windowHeight: 480,
    );
    final restored = NotepadSettings.fromJson(original.toJson());
    expect(restored.wordWrap, isFalse);
    expect(restored.statusBarVisible, isFalse);
    expect(restored.font, original.font);
    expect(restored.pageSetup.header, 'Report');
    expect(restored.pageSetup.leftInches, 1.25);
    expect(restored.lastDirectory, '/home/tester/docs');
    expect(restored.windowWidth, 640);
  });

  test('wrong types in the file fall back to defaults instead of throwing', () {
    final restored = NotepadSettings.fromJson({
      'wordWrap': 'yes',
      'font': 'Arial',
      'windowWidth': 'wide',
    });
    expect(restored.wordWrap, isTrue);
    expect(restored.font.family, 'Lucida Console');
    expect(restored.windowWidth, 600);
  });

  test('a font size the Font dialog cannot choose falls back to 10 points', () {
    for (final size in [0, -5, 1e9]) {
      final restored = NotepadSettings.fromJson({
        'font': {'size': size},
      });
      expect(restored.font.sizePoints, 10, reason: 'size $size');
    }
    for (final size in [1, 12.5, 1638]) {
      final restored = NotepadSettings.fromJson({
        'font': {'size': size},
      });
      expect(restored.font.sizePoints, size, reason: 'size $size');
    }
  });
}
