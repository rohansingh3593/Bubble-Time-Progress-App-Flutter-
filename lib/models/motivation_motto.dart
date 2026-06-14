class MotivationMotto {
  final String id;
  final String quote;
  final String description;
  final String category;
  final String mood;
  final String author;
  final bool enabled;
  final bool favorite;
  final bool pinned;
  final bool todaysMotto;
  final DateTime createdAt;
  final DateTime? lastShownAt;
  final int showCount;

  const MotivationMotto({
    required this.id,
    required this.quote,
    this.description = '',
    this.category = 'Focus',
    this.mood = '',
    this.author = '',
    this.enabled = true,
    this.favorite = false,
    this.pinned = false,
    this.todaysMotto = false,
    required this.createdAt,
    this.lastShownAt,
    this.showCount = 0,
  });

  factory MotivationMotto.create({
    required String quote,
    String description = '',
    String category = 'Focus',
    String mood = '',
    String author = '',
    bool enabled = true,
  }) {
    final now = DateTime.now();
    return MotivationMotto(
      id: 'motto_${now.microsecondsSinceEpoch}',
      quote: quote,
      description: description,
      category: category,
      mood: mood,
      author: author,
      enabled: enabled,
      createdAt: now,
    );
  }

  factory MotivationMotto.fromMap(Map<dynamic, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return MotivationMotto(
      id: (map['id'] ?? '').toString(),
      quote: (map['quote'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      category: (map['category'] ?? 'Focus').toString(),
      mood: (map['mood'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      enabled: map['enabled'] != false,
      favorite: map['favorite'] == true,
      pinned: map['pinned'] == true,
      todaysMotto: map['todaysMotto'] == true,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      lastShownAt: parseDate(map['lastShownAt']),
      showCount: (map['showCount'] is num) ? (map['showCount'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'quote': quote,
        'description': description,
        'category': category,
        'mood': mood,
        'author': author,
        'enabled': enabled,
        'favorite': favorite,
        'pinned': pinned,
        'todaysMotto': todaysMotto,
        'createdAt': createdAt.toIso8601String(),
        'lastShownAt': lastShownAt?.toIso8601String(),
        'showCount': showCount,
      };

  MotivationMotto copyWith({
    String? quote,
    String? description,
    String? category,
    String? mood,
    String? author,
    bool? enabled,
    bool? favorite,
    bool? pinned,
    bool? todaysMotto,
    DateTime? createdAt,
    DateTime? lastShownAt,
    int? showCount,
  }) {
    return MotivationMotto(
      id: id,
      quote: quote ?? this.quote,
      description: description ?? this.description,
      category: category ?? this.category,
      mood: mood ?? this.mood,
      author: author ?? this.author,
      enabled: enabled ?? this.enabled,
      favorite: favorite ?? this.favorite,
      pinned: pinned ?? this.pinned,
      todaysMotto: todaysMotto ?? this.todaysMotto,
      createdAt: createdAt ?? this.createdAt,
      lastShownAt: lastShownAt ?? this.lastShownAt,
      showCount: showCount ?? this.showCount,
    );
  }
}

class MottoReminderSettings {
  final bool popupEnabled;
  final int frequencyMinutes;
  final bool activeOnly;

  const MottoReminderSettings({this.popupEnabled = true, this.frequencyMinutes = 15, this.activeOnly = true});

  factory MottoReminderSettings.fromMap(Map<dynamic, dynamic> map) => MottoReminderSettings(
        popupEnabled: map['popupEnabled'] != false,
        frequencyMinutes: (map['frequencyMinutes'] is num) ? (map['frequencyMinutes'] as num).toInt() : 15,
        activeOnly: map['activeOnly'] != false,
      );

  Map<String, dynamic> toMap() => {
        'popupEnabled': popupEnabled,
        'frequencyMinutes': frequencyMinutes,
        'activeOnly': activeOnly,
      };
}
