import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import 'task_completion.dart';

class TaskRow extends StatefulWidget {
  const TaskRow(
      {super.key,
      required this.task,
      required this.date,
      required this.service,
      this.onEdit,
      this.details,
      this.onDelete,
      this.compact = false,
      this.emphasizeSchedule = false});
  final Task task;
  final DateTime date;
  final HiveService service;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? details;
  final bool compact;
  final bool emphasizeSchedule;
  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _busy = false;

  Future<void> _moveTo(DateTime date) async {
    final original = widget.task;
    final moved = original.copyWith(
        dueDate: DateTime(date.year, date.month, date.day,
            original.dueDate.hour, original.dueDate.minute));
    setState(() => _busy = true);
    try {
      await widget.service.saveTaskChanges(original, moved);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Task moved to ${MaterialLocalizations.of(context).formatMediumDate(date)}')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not move this task. Please retry.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final complete = taskCompleted(task);
    final future = DateUtils.dateOnly(widget.date)
        .isAfter(DateUtils.dateOnly(DateTime.now()));
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final canMove = !task.repeatTask && !complete && task.status != 'Cancelled';
    final minutes = widget.service.getTaskScheduledStartMinutes(task);
    final time = minutes == null
        ? null
        : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final overdue = !complete &&
        task.status != 'Cancelled' &&
        DateUtils.dateOnly(widget.date).isBefore(today);
    final theme = Theme.of(context);
    final overdueColor = theme.colorScheme.error;
    final metadata = [
      if (overdue) 'Overdue',
      MaterialLocalizations.of(context).formatMediumDate(widget.date),
      if (time != null && !widget.emphasizeSchedule) time.format(context),
      if (task.repeatTask) task.repeatFrequency ?? 'Daily'
    ].join(' \u2022 ');
    return Card(
        margin: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 3)
            : null,
        color: overdue
            ? Color.alphaBlend(
                overdueColor.withValues(alpha: 0.10), theme.colorScheme.surface)
            : null,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Tooltip(
              message: future
                  ? 'Available on the task date'
                  : complete
                      ? 'Reopen task'
                      : 'Complete task',
              child: Checkbox(
                  value: complete,
                  semanticLabel:
                      '${complete ? 'Reopen' : 'Complete'} ${task.task}',
                  onChanged: _busy ||
                          future ||
                          (task.repeatTask && !task.routineEnabled) ||
                          task.status == 'Cancelled'
                      ? null
                      : (value) async {
                          setState(() => _busy = true);
                          await changeTaskCompletion(context, widget.service,
                              task, widget.date, value == true);
                          if (mounted) setState(() => _busy = false);
                        })),
          Expanded(
              child: InkWell(
                  onTap: _busy ? null : widget.onEdit,
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: widget.compact ? 7 : 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task.task,
                                style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: complete
                                        ? TextDecoration.lineThrough
                                        : null)),
                            if (widget.emphasizeSchedule && time != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.schedule,
                                      size: 14,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(time.format(context),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w700)),
                                  if (metadata.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(metadata,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: overdue
                                                      ? overdueColor
                                                      : theme.colorScheme
                                                          .onSurfaceVariant)),
                                    ),
                                  ],
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Text(metadata,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: overdue
                                          ? overdueColor
                                          : theme
                                              .colorScheme.onSurfaceVariant)),
                            ],
                            if (widget.details != null)
                              Text(widget.details!,
                                  style: theme.textTheme.bodySmall),
                          ])))),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, semanticsLabel: 'Saving task'))),
          if (widget.onEdit != null || widget.onDelete != null || canMove)
            PopupMenuButton<String>(
              enabled: !_busy,
              tooltip: 'Actions for ${task.task}',
              onSelected: (value) {
                if (value == 'edit')
                  widget.onEdit?.call();
                else if (value == 'today')
                  _moveTo(today);
                else if (value == 'tomorrow')
                  _moveTo(tomorrow);
                else
                  widget.onDelete?.call();
              },
              itemBuilder: (_) => [
                if (widget.onEdit != null)
                  const PopupMenuItem(
                      value: 'edit', child: Text('Edit details')),
                if (canMove && !DateUtils.isSameDay(widget.date, today))
                  const PopupMenuItem(
                      value: 'today', child: Text('Move to today')),
                if (canMove && !DateUtils.isSameDay(widget.date, tomorrow))
                  const PopupMenuItem(
                      value: 'tomorrow', child: Text('Move to tomorrow')),
                if (widget.onDelete != null)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ]));
  }
}
