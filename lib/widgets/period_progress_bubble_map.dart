import 'package:flutter/material.dart';

import '../constants/dashboard_themes.dart';

class PeriodProgressBubbleMap extends StatelessWidget {
  final DashboardThemeStyle theme;
  final String title;
  final String subtitle;
  final int totalItems;
  final int passedItems;
  final int? currentIndex;
  final int itemsPerRow;
  final String passedLabel;
  final String currentLabel;
  final String remainingLabel;
  final String Function(int index)? tooltipBuilder;

  const PeriodProgressBubbleMap({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.totalItems,
    required this.passedItems,
    required this.currentIndex,
    required this.itemsPerRow,
    this.passedLabel = 'Passed',
    this.currentLabel = 'Today',
    this.remainingLabel = 'Remaining',
    this.tooltipBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedCurrentIndex = currentIndex != null && currentIndex! >= 0 && currentIndex! < totalItems ? currentIndex : null;
    final progress = totalItems == 0 ? 0.0 : (passedItems / totalItems).clamp(0.0, 1.0).toDouble();
    final progressLabel = '${(progress * 100).round()}%';

    Color bubbleColor(int index) {
      if (index == normalizedCurrentIndex) return theme.accent;
      if (index < passedItems) return theme.primary;
      return theme.textMuted.withOpacity(0.28);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 600 ? 4.0 : 5.0;
        final horizontalPadding = constraints.maxWidth < 600 ? 28.0 : 36.0;
        final availableWidth = constraints.maxWidth - horizontalPadding - (spacing * (itemsPerRow - 1));
        final cellWidth = availableWidth / itemsPerRow;
        final bubbleSize = cellWidth.clamp(10.0, 18.0).toDouble();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.primary.withOpacity(0.14)),
            boxShadow: [BoxShadow(color: theme.primary.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(subtitle, style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: (theme.cardTint ?? theme.elevatedSurface).withOpacity(theme.dark ? 0.40 : 0.72),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.primary.withOpacity(0.14)),
                    ),
                    child: Text(progressLabel, style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  color: theme.primary,
                  backgroundColor: theme.primary.withOpacity(0.12),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(totalItems, (index) {
                  return SizedBox(
                    width: cellWidth,
                    height: bubbleSize,
                    child: Tooltip(
                      message: tooltipBuilder?.call(index) ?? '${index + 1}',
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: bubbleSize,
                          height: bubbleSize,
                          decoration: BoxDecoration(
                            color: bubbleColor(index),
                            shape: BoxShape.circle,
                            boxShadow: index == normalizedCurrentIndex ? [BoxShadow(color: theme.accent.withOpacity(0.55), blurRadius: 12, spreadRadius: 2)] : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _LegendItem(theme: theme, color: theme.primary, label: passedLabel),
                  _LegendItem(theme: theme, color: theme.accent, label: currentLabel, glow: true),
                  _LegendItem(theme: theme, color: theme.textMuted.withOpacity(0.28), label: remainingLabel),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final DashboardThemeStyle theme;
  final Color color;
  final String label;
  final bool glow;

  const _LegendItem({required this.theme, required this.color, required this.label, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: glow ? [BoxShadow(color: theme.accent.withOpacity(0.45), blurRadius: 10, spreadRadius: 1)] : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: theme.textMuted, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
