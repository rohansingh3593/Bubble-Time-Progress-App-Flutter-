import 'dart:math';

final _random = Random.secure();

/// Opaque identity, independent of names, dates, ordering, and display text.
String newEntityId() => List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
