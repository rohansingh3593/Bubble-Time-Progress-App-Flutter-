/// Date utilities for consistent UTC-based date key handling and week calculations.
/// All storage/retrieval calls use these helpers to prevent timezone inconsistencies.

/// Converts a DateTime to a date key string in UTC with zeroed time (yyyy-MM-dd format).
/// Input DateTime is converted to UTC; only the date portion is kept.
String toDateKeyUtc(DateTime date) {
  final utcDate = date.toUtc();
  return '${utcDate.year.toString().padLeft(4, '0')}-'
      '${utcDate.month.toString().padLeft(2, '0')}-'
      '${utcDate.day.toString().padLeft(2, '0')}';
}

/// Parses a date key string (yyyy-MM-dd) back to a UTC DateTime at 00:00:00 UTC.
DateTime fromDateKeyUtc(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length != 3) {
    throw FormatException('Invalid date key format: $dateKey. Expected yyyy-MM-dd');
  }
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  return DateTime.utc(year, month, day);
}

/// Returns the start of the week (Monday) in local time for the given date.
DateTime startOfWeekMonday(DateTime date) {
  // weekday: 1 = Monday, 7 = Sunday
  final daysToSubtract = date.weekday - 1;
  final startDate = date.subtract(Duration(days: daysToSubtract));
  // Return with time zeroed
  return DateTime(startDate.year, startDate.month, startDate.day);
}

/// Returns the end of the week (Sunday) in local time for the given date.
DateTime endOfWeekMonday(DateTime date) {
  final weekStart = startOfWeekMonday(date);
  final weekEnd = weekStart.add(const Duration(days: 6));
  // Return with time zeroed
  return DateTime(weekEnd.year, weekEnd.month, weekEnd.day);
}

/// Normalizes a DateTime to start of day (00:00:00) in local time.
DateTime normalizeToStartOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
