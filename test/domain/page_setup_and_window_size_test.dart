import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';

void main() {
  group('page margins', () {
    test('the default margins can be printed', () {
      expect(const PageSetup().marginProblem, isNull);
    });

    test('a margin outside 0 to 6 inches is rejected', () {
      expect(const PageSetup(topInches: -1).marginProblem, isNotNull);
      expect(const PageSetup(leftInches: 6.5).marginProblem, isNotNull);
      expect(
        const PageSetup(bottomInches: double.nan).marginProblem,
        isNotNull,
      );
    });

    test('top and bottom must leave an inch of printable height', () {
      expect(
        const PageSetup(topInches: 6, bottomInches: 6).marginProblem,
        isNotNull,
      );
      expect(
        const PageSetup(topInches: 4.5, bottomInches: 4.5).marginProblem,
        isNull,
      );
    });

    test('left and right must leave an inch of printable width', () {
      expect(
        const PageSetup(leftInches: 4, rightInches: 4).marginProblem,
        isNotNull,
      );
      expect(
        const PageSetup(leftInches: 3, rightInches: 3.5).marginProblem,
        isNull,
      );
    });
  });

  group('settings loaded from a damaged file', () {
    test('margins that leave no room to print fall back to the defaults', () {
      final settings = NotepadSettings.fromJson({
        'pageSetup': {'top': 6, 'bottom': 6, 'header': 'Mine'},
      });
      expect(settings.pageSetup.topInches, const PageSetup().topInches);
      expect(settings.pageSetup.bottomInches, const PageSetup().bottomInches);
      // The header is kept, because it does not affect the layout.
      expect(settings.pageSetup.header, 'Mine');
    });

    test('a margin outside the allowed range falls back to its default', () {
      final settings = NotepadSettings.fromJson({
        'pageSetup': {'left': -2, 'right': 0.5},
      });
      expect(settings.pageSetup.leftInches, const PageSetup().leftInches);
      expect(settings.pageSetup.rightInches, 0.5);
    });

    test('a window side below the minimum is raised to the minimum', () {
      final settings = NotepadSettings.fromJson({
        'windowWidth': 10,
        'windowHeight': 20,
      });
      expect(settings.windowWidth, kMinimumWindowSize.width);
      expect(settings.windowHeight, kMinimumWindowSize.height);
    });

    test('an absurdly large window side is capped', () {
      final settings = NotepadSettings.fromJson({'windowWidth': 1e9});
      expect(settings.windowWidth, 8192);
    });

    test('a reasonable window size is kept as saved', () {
      final settings = NotepadSettings.fromJson({
        'windowWidth': 720,
        'windowHeight': 500,
      });
      expect(settings.windowWidth, 720);
      expect(settings.windowHeight, 500);
    });
  });
}
