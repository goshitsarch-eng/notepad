/// Text that Edit > Time/Date inserts: the time without seconds, a space, then the short
/// date, in the en-US form Windows XP uses by default (for example "3:45 PM 10/7/2026").
String formatTimeDate(DateTime moment) {
  final hour = moment.hour % 12 == 0 ? 12 : moment.hour % 12;
  final minute = moment.minute.toString().padLeft(2, '0');
  final period = moment.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period ${moment.month}/${moment.day}/${moment.year}';
}
