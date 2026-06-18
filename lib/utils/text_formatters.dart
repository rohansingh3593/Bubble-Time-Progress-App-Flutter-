String toTitleCase(String text) {
  if (text.trim().isEmpty) return text;

  return text
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        if (_shouldPreserveWord(word)) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

String toTitleCaseMetadata(Iterable<Object?> parts) {
  return parts
      .where((part) => part != null && part.toString().trim().isNotEmpty)
      .map((part) => toTitleCase(part.toString().trim()))
      .join(' • ');
}

bool _shouldPreserveWord(String word) {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return true;
  if (trimmed.contains('@')) return true;
  if (trimmed.contains('://') || trimmed.startsWith('www.')) return true;
  if (trimmed.contains('/') || trimmed.contains('\\')) return true;
  if (trimmed.startsWith('#') || trimmed.startsWith('@')) return true;
  if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed) && RegExp(r'\d').hasMatch(trimmed)) return true;
  return false;
}
