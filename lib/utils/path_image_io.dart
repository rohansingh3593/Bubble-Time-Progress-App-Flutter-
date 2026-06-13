import 'dart:io';

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
  final fallbackWidget = fallback ?? const SizedBox.shrink();
  final file = File(trimmedPath);

  if (trimmedPath.isNotEmpty && file.existsSync()) {
    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder ?? (_, __, ___) => fallbackWidget,
    );
  }

  final parsedUri = Uri.tryParse(trimmedPath);
  if (parsedUri != null && parsedUri.hasScheme) {
    return Image.network(
      trimmedPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder ?? (_, __, ___) => fallbackWidget,
    );
  }

  return SizedBox(width: width, height: height, child: fallbackWidget);
}
