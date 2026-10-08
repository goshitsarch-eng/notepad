import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/text/time_date.dart';

void main() {
  test(
    'Time/Date uses the XP form: time without seconds, then the short date',
    () {
      expect(formatTimeDate(DateTime(2026, 10, 7, 15, 5)), '3:05 PM 10/7/2026');
    },
  );

  test('midnight and noon are 12, not 0', () {
    expect(formatTimeDate(DateTime(2026, 1, 1, 0, 0)), '12:00 AM 1/1/2026');
    expect(formatTimeDate(DateTime(2026, 1, 1, 12, 30)), '12:30 PM 1/1/2026');
  });
}
