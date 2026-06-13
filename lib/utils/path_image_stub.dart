import 'package:flutter/material.dart';

Widget imageFromPath(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
  Widget? fallback,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final trimmedPath = path.trim();
  final parsedUri = Uri.tryParse(trimmedPath);
  final hasImageUri = parsedUri != null && parsedUri.hasScheme;
  final fallbackWidget = fallback ?? const SizedBox.shrink();

  if (!hasImageUri) {
    return SizedBox(width: width, height: height, child: fallbackWidget);
  }

  return Image.network(
    trimmedPath,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder ?? (_, __, ___) => fallbackWidget,
  );
}
