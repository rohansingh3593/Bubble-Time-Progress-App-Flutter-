class JourneyEntry {
  final String id;
  final DateTime date;
  final String type;
  final String title;
  final String description;
  final String? relatedTaskName;
  final int colorValue;
  final String? imageUrl;

  const JourneyEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.title,
    required this.description,
    required this.colorValue,
    this.relatedTaskName,
    this.imageUrl,
  });

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  List<dynamic> toStorageList() {
    return [
      id,
      date.toIso8601String(),
      type,
      title,
      description,
      relatedTaskName,
      colorValue,
      imageUrl,
    ];
  }

  factory JourneyEntry.fromStorageList(List<dynamic> values, DateTime fallbackDate) {
    final parsedDate = values.length > 1 && values[1] is String
        ? DateTime.tryParse(values[1] as String)
        : null;

    return JourneyEntry(
      id: values.isNotEmpty ? '${values[0]}' : fallbackDate.microsecondsSinceEpoch.toString(),
      date: parsedDate ?? fallbackDate,
      type: values.length > 2 ? '${values[2]}' : 'Reflection',
      title: values.length > 3 ? '${values[3]}' : 'Journey update',
      description: values.length > 4 ? '${values[4]}' : '',
      relatedTaskName: _readNullableString(values, 5),
      colorValue: _readInt(values, 6, 0xFF1E88E5),
      imageUrl: _readNullableString(values, 7),
    );
  }

  static String? _readNullableString(List<dynamic> values, int index) {
    if (values.length <= index || values[index] == null) return null;
    final text = '${values[index]}'.trim();
    return text.isEmpty ? null : text;
  }

  static int _readInt(List<dynamic> values, int index, int fallback) {
    if (values.length <= index) return fallback;
    final value = values[index];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }
}
