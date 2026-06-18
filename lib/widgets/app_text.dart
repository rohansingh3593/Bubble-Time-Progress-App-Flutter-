import 'package:flutter/material.dart';

import '../utils/text_formatters.dart';

double responsiveFont(BuildContext context, double base) {
  final width = MediaQuery.of(context).size.width;
  if (width < 360) return base * 0.82;
  if (width < 430) return base * 0.90;
  if (width < 600) return base;
  if (width < 900) return base * 1.08;
  return base * 1.16;
}

class AppText extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final Color color;
  final int maxLines;
  final TextAlign? textAlign;
  final bool titleCase;

  const AppText({
    super.key,
    required this.text,
    required this.size,
    required this.weight,
    required this.color,
    this.maxLines = 1,
    this.textAlign,
    this.titleCase = true,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      titleCase ? toTitleCase(text) : text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: maxLines > 1,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: responsiveFont(context, size),
        fontWeight: weight,
        color: color,
      ),
    );
  }
}
