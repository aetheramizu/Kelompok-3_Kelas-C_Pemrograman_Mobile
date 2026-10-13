const List<String> _dayNames = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// Contoh: "14:15".
String formatClock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

/// Contoh: "14:00".
String formatHour(DateTime time) => '${_two(time.hour)}:00';

/// Contoh: "Selasa, 13 Okt".
String formatDay(DateTime date) =>
    '${_dayNames[date.weekday - 1]}, ${date.day} ${_monthNames[date.month - 1]}';
