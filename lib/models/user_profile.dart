class UserProfile {
  final String fullName;
  final String nickname;
  final String bio;
  final String occupation;
  final String birthday;
  final String favoriteTheme;
  final String avatarBorderStyle;
  final String profilePhotoPath;
  final List<String> photoHistory;

  const UserProfile({
    required this.fullName,
    required this.nickname,
    required this.bio,
    required this.occupation,
    required this.birthday,
    required this.favoriteTheme,
    required this.avatarBorderStyle,
    required this.profilePhotoPath,
    required this.photoHistory,
  });

  String get displayName => fullName.trim().isNotEmpty ? fullName.trim() : 'Productivity Hero';
  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  bool get hasPhoto => profilePhotoPath.trim().isNotEmpty;

  UserProfile copyWith({
    String? fullName,
    String? nickname,
    String? bio,
    String? occupation,
    String? birthday,
    String? favoriteTheme,
    String? avatarBorderStyle,
    String? profilePhotoPath,
    List<String>? photoHistory,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      occupation: occupation ?? this.occupation,
      birthday: birthday ?? this.birthday,
      favoriteTheme: favoriteTheme ?? this.favoriteTheme,
      avatarBorderStyle: avatarBorderStyle ?? this.avatarBorderStyle,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      photoHistory: photoHistory ?? this.photoHistory,
    );
  }

  List<dynamic> toStorageList() {
    return [
      fullName,
      nickname,
      bio,
      occupation,
      birthday,
      favoriteTheme,
      avatarBorderStyle,
      profilePhotoPath,
      photoHistory,
    ];
  }

  factory UserProfile.fromStorageList(List<dynamic> values, {String fallbackName = 'Productivity Hero'}) {
    return UserProfile(
      fullName: _readString(values, 0, fallbackName),
      nickname: _readString(values, 1, ''),
      bio: _readString(values, 2, 'Small wins create extraordinary results.'),
      occupation: _readString(values, 3, ''),
      birthday: _readString(values, 4, ''),
      favoriteTheme: _readString(values, 5, 'Calm'),
      avatarBorderStyle: _readString(values, 6, 'Silver'),
      profilePhotoPath: _readString(values, 7, ''),
      photoHistory: values.length > 8 && values[8] is List ? (values[8] as List).map((item) => '$item').where((item) => item.trim().isNotEmpty).toList() : const <String>[],
    );
  }

  factory UserProfile.defaults({String fullName = 'Productivity Hero'}) {
    return UserProfile(
      fullName: fullName,
      nickname: '',
      bio: 'Small wins create extraordinary results.',
      occupation: '',
      birthday: '',
      favoriteTheme: 'Calm',
      avatarBorderStyle: 'Silver',
      profilePhotoPath: '',
      photoHistory: const <String>[],
    );
  }

  static String _readString(List<dynamic> values, int index, String fallback) {
    if (values.length <= index || values[index] == null) return fallback;
    final text = '${values[index]}'.trim();
    return text.isEmpty ? fallback : text;
  }
}
