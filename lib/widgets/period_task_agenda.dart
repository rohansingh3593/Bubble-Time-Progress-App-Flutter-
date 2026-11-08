import 'package:flutter/material.dart';

import '../services/hive_service.dart';

class PeriodTaskAgenda extends StatelessWidget {
  const PeriodTaskAgenda({
    super.key,
    required this.hiveService,
    required this.dates,
    required this.onOpenDate,
  });

  final HiveService hiveService;
  final List<DateTime> dates;
  final ValueChanged<DateTime> onOpenDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = [
      for (final date in dates)
        (
          date: date,
          tasks: hiveService
              .getMasterTaskOccurrencesForDate(date)
              .where((task) => DateUtils.isSameDay(task.dueDate, date))
              .toList(),
        ),
    ].where((entry) => entry.tasks.isNotEmpty).toList();

    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Agenda', style: theme.textTheme.titleMedium),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'No tasks scheduled for this period.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              ...entries.map((entry) {
                final names = entry.tasks
                    .take(2)
                    .map((task) => task.task.trim())
                    .where((name) => name.isNotEmpty)
                    .join(' • ');
                final remaining = entry.tasks.length -
                    entry.tasks
                        .take(2)
                        .where((task) => task.task.trim().isNotEmpty)
                        .length;
                final subtitle = [
                  '${entry.tasks.length} ${entry.tasks.length == 1 ? 'task' : 'tasks'}',
                  if (names.isNotEmpty)
                    '$names${remaining > 0 ? ' • +$remaining more' : ''}',
                ].join(' • ');

                return ListTile(
                  dense: true,
                  title: Text(_dateLabel(entry.date)),
                  subtitle: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenDate(entry.date),
                );
              }),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}
