class JournalEntry {
  final DateTime date;
  final String mood;
  final String reflection;
  final int completedTasks;
  final int totalTasks;
  final int productivityScore;

  const JournalEntry({
    required this.date,
    required this.mood,
    required this.reflection,
    required this.completedTasks,
    required this.totalTasks,
    required this.productivityScore,
  });

  bool get hasReflection => reflection.trim().isNotEmpty;
  double get completionRatio => totalTasks == 0 ? 0 : completedTasks / totalTasks;

  List<dynamic> toStorageList() {
    return [
      mood,
      reflection,
      date.toIso8601String(),
      completedTasks,
      totalTasks,
      productivityScore,
    ];
  }

  factory JournalEntry.fromStorageList(List<dynamic> values, DateTime fallbackDate) {
    final parsedDate = values.length > 2 && values[2] is String
        ? DateTime.tryParse(values[2] as String)
        : null;
    return JournalEntry(
      mood: values.isNotEmpty ? '${values[0]}' : 'Neutral',
      reflection: values.length > 1 ? '${values[1]}' : '',
      date: parsedDate ?? _dateOnly(fallbackDate),
      completedTasks: _readInt(values, 3),
      totalTasks: _readInt(values, 4),
      productivityScore: _readInt(values, 5),
    );
  }

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static int _readInt(List<dynamic> values, int index) {
    if (values.length <= index) return 0;
    final value = values[index];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
