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
  final String Function(int index)? bubbleLabelBuilder;
  final String Function(int index)? belowLabelBuilder;
  final int? displayItemCount;
  final double minBubbleSize;
  final double maxBubbleSize;

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
    this.bubbleLabelBuilder,
    this.belowLabelBuilder,
    this.displayItemCount,
    this.minBubbleSize = 34,
    this.maxBubbleSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedCurrentIndex = currentIndex != null && currentIndex! >= 0 && currentIndex! < totalItems ? currentIndex : null;
    final visibleItems = displayItemCount ?? totalItems;
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
        final bubbleSize = cellWidth < minBubbleSize ? cellWidth : cellWidth.clamp(minBubbleSize, maxBubbleSize).toDouble();
        final cellHeight = belowLabelBuilder == null ? bubbleSize : bubbleSize + 18;

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
              Column(
                children: List.generate((visibleItems / itemsPerRow).ceil(), (rowIndex) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: rowIndex == (visibleItems / itemsPerRow).ceil() - 1 ? 0 : spacing),
                    child: Row(
                      children: List.generate(itemsPerRow, (columnIndex) {
                        final index = (rowIndex * itemsPerRow) + columnIndex;
                        if (index >= visibleItems) {
                          return const Expanded(child: SizedBox.shrink());
                        }
                        final isPlaceholder = index >= totalItems;
                        final label = isPlaceholder ? '' : bubbleLabelBuilder?.call(index) ?? '${index + 1}';
                        final belowLabel = isPlaceholder ? null : belowLabelBuilder?.call(index);
                        final bubble = Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: bubbleSize,
                            height: bubbleSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isPlaceholder ? theme.textMuted.withOpacity(0.12) : bubbleColor(index),
                              shape: BoxShape.circle,
                              boxShadow: !isPlaceholder && index == normalizedCurrentIndex ? [BoxShadow(color: theme.accent.withOpacity(0.55), blurRadius: 12, spreadRadius: 2)] : null,
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !isPlaceholder && (index < passedItems || index == normalizedCurrentIndex) ? theme.surface : theme.textMuted,
                                fontSize: bubbleSize < 40 ? 10 : 11,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ),
                        );
                        final cellContent = belowLabel == null
                            ? bubble
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  bubble,
                                  const SizedBox(height: 3),
                                  Text(
                                    belowLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: theme.textMuted, fontSize: 9, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              );
                        final cell = SizedBox(
                          height: cellHeight,
                          child: isPlaceholder
                              ? bubble
                              : Tooltip(
                                  message: tooltipBuilder?.call(index) ?? '${index + 1}',
                                  child: cellContent,
                                ),
                        );
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: columnIndex == itemsPerRow - 1 ? 0 : spacing),
                            child: cell,
                          ),
                        );
                      }),
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
