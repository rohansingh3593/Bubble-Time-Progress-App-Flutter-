import 'package:flutter/material.dart';
import '../widgets/recoverable_delete.dart';

import '../constants/colors.dart';
import '../models/journal_entry.dart';
import '../models/journey_entry.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../widgets/profile_avatar.dart';
import '../utils/text_formatters.dart';

class JourneyTimelineView extends StatelessWidget {
  final HiveService hiveService;

  JourneyTimelineView({super.key, required this.hiveService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Journey Timeline')),
      body: ValueListenableBuilder(
        valueListenable: hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final manualEntries = hiveService.getAllJourneyEntries();
          final tasksByDate = hiveService.getAllTasksByDate();
          final journalEntries = hiveService.getAllJournalEntries();
          final dailyJourneys = _DailyJourney.build(
            tasksByDate: tasksByDate,
            journalEntries: journalEntries,
            manualEntries: manualEntries,
          );

          final timelineWidgets = <Widget>[];
          String? currentSection;
          for (final journey in dailyJourneys) {
            final section = _sectionLabelForDate(journey.date);
            if (section != currentSection) {
              timelineWidgets.add(_TimelineSectionHeader(label: section));
              currentSection = section;
            }
            timelineWidgets.add(
              _DailyJourneyCard(
                journey: journey,
                onDeleteEntry: (id) async {
                  final entry =
                      manualEntries.firstWhere((entry) => entry.id == id);
                  await recoverableDelete(context,
                      label: 'journey entry',
                      remove: () => hiveService.deleteJourneyEntry(id),
                      restore: () => hiveService.saveJourneyEntry(entry));
                },
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              Text('Your activity and reflections',
                  style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _showEntryDialog(
                    context,
                    hiveService
                        .getAllTasksByDate()
                        .values
                        .expand((tasks) => tasks)
                        .toList(),
                  ),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Log journey'),
                ),
              ),
              SizedBox(height: 14),
              if (dailyJourneys.isEmpty)
                _EmptyJourneyState()
              else
                ...timelineWidgets,
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEntryDialog(BuildContext context, List<Task> tasks) async {
    await showDialog<JourneyEntry>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _JourneyEntryDialog(
          tasks: tasks, onSave: hiveService.saveJourneyEntry),
    );
  }
}

class _DailyJourney {
  final DateTime date;
  final List<Task> tasks;
  final JournalEntry? journalEntry;
  final List<JourneyEntry> manualEntries;

  _DailyJourney({
    required this.date,
    required this.tasks,
    required this.journalEntry,
    required this.manualEntries,
  });

  List<Task> get completedTasks => tasks.where(_isCompletedTask).toList();

  List<Task> get habitUpdates {
    return tasks.where((task) {
      if (!task.repeatTask) return false;
      final status = task.status.trim().toLowerCase();
      return _isCompletedTask(task) ||
          status == 'cancelled' ||
          status == 'missed' ||
          status == 'overdue' ||
          status == 'in progress';
    }).toList();
  }

  bool get hasActivity {
    return tasks.isNotEmpty || journalEntry != null || manualEntries.isNotEmpty;
  }

  Color get accentColor {
    if (completedTasks.isNotEmpty)
      return Color(completedTasks.first.colorValue);
    if (habitUpdates.isNotEmpty) return Color(habitUpdates.first.colorValue);
    if (tasks.isNotEmpty) return Color(tasks.first.colorValue);
    if (manualEntries.isNotEmpty) return Color(manualEntries.first.colorValue);
    return _moodColor(journalEntry?.mood);
  }

  static List<_DailyJourney> build({
    required Map<DateTime, List<Task>> tasksByDate,
    required List<JournalEntry> journalEntries,
    required List<JourneyEntry> manualEntries,
  }) {
    final dates = <DateTime>{};
    final journalsByDate = <DateTime, JournalEntry>{};
    final manualByDate = <DateTime, List<JourneyEntry>>{};

    for (final entry in tasksByDate.entries) {
      dates.add(_dateOnly(entry.key));
    }
    for (final journal in journalEntries) {
      final date = _dateOnly(journal.date);
      dates.add(date);
      journalsByDate[date] = journal;
    }
    for (final entry in manualEntries) {
      final date = _dateOnly(entry.date);
      dates.add(date);
      manualByDate.putIfAbsent(date, () => <JourneyEntry>[]).add(entry);
    }

    final journeys = dates
        .map((date) {
          final entries = (manualByDate[date] ?? <JourneyEntry>[]).toList()
            ..sort((a, b) {
              if (a.isAutoDailySummary != b.isAutoDailySummary)
                return a.isAutoDailySummary ? -1 : 1;
              return b.date.compareTo(a.date);
            });
          return _DailyJourney(
            date: date,
            tasks: tasksByDate[date] ?? <Task>[],
            journalEntry: journalsByDate[date],
            manualEntries: entries,
          );
        })
        .where((journey) => journey.hasActivity)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return journeys;
  }

  static bool _isCompletedTask(Task task) =>
      task.done || task.status.trim().toLowerCase() == 'completed';
}

class _TimelineSectionHeader extends StatelessWidget {
  final String label;

  _TimelineSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

class _DailyJourneyCard extends StatelessWidget {
  final _DailyJourney journey;
  final Future<void> Function(String id) onDeleteEntry;

  _DailyJourneyCard({required this.journey, required this.onDeleteEntry});

  @override
  Widget build(BuildContext context) {
    final accent = journey.accentColor;
    final journal = journey.journalEntry;

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.09),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.timeline, color: accent),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_friendlyDate(journey.date),
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                      '${journey.completedTasks.length} completed • ${journey.habitUpdates.length} habit updates • ${journal?.mood ?? 'No mood'}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (journal != null) _MoodReflectionPanel(journal: journal),
          if (journey.completedTasks.isNotEmpty) ...[
            SizedBox(height: 10),
            _TaskWrap(
              title: 'Completed tasks',
              tasks: journey.completedTasks,
              icon: Icons.check_circle,
            ),
          ],
          if (journey.habitUpdates.isNotEmpty) ...[
            SizedBox(height: 10),
            _TaskWrap(
              title: 'Habit updates',
              tasks: journey.habitUpdates,
              icon: Icons.repeat,
            ),
          ],
          if (journey.manualEntries.isNotEmpty) ...[
            SizedBox(height: 10),
            ...journey.manualEntries.map(
              (entry) => _JourneyEntryCard(
                entry: entry,
                onDelete: () {
                  onDeleteEntry(entry.id);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodReflectionPanel extends StatelessWidget {
  final JournalEntry journal;

  _MoodReflectionPanel({required this.journal});

  @override
  Widget build(BuildContext context) {
    final color = _moodColor(journal.mood);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_moodEmoji(journal.mood), style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(journal.mood, style: TextStyle(fontWeight: FontWeight.w600)),
              Spacer(),
              Text('${journal.productivityScore}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          if (journal.reflection.trim().isNotEmpty) ...[
            SizedBox(height: 8),
            Text(journal.reflection.trim(),
                maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

class _TaskWrap extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final IconData icon;

  _TaskWrap({required this.title, required this.tasks, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tasks
              .map((task) => _JourneyChip(
                  label: task.task, icon: icon, color: Color(task.colorValue)))
              .toList(),
        ),
      ],
    );
  }
}

class _JourneyHero extends StatelessWidget {
  final VoidCallback onAdd;
  final HiveService hiveService;

  _JourneyHero({required this.onAdd, required this.hiveService});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7E57C2), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.18),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                  profile: hiveService.getUserProfile(),
                  radius: 24,
                  accentColor: AppColors.accent,
                  showGlow: false),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Personal Journey Timeline',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 20),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Log habit progress, milestone wins, reflections, routines, and optional progress images in one personal growth feed.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add),
            label: Text('Add journey entry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyEntryCard extends StatelessWidget {
  final JourneyEntry entry;
  final VoidCallback onDelete;

  _JourneyEntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final accent = Color(entry.colorValue);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_iconForType(entry.type), color: accent),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    SizedBox(height: 2),
                    Text(
                      '${entry.date.month}/${entry.date.day}/${entry.date.year} • ${entry.type}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (!entry.isAutoDailySummary)
                IconButton(
                  tooltip: 'Delete entry',
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: onDelete,
                ),
            ],
          ),
          if (entry.description.trim().isNotEmpty) ...[
            SizedBox(height: 10),
            Text(entry.description,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.3)),
          ],
          if (entry.relatedTaskName != null) ...[
            SizedBox(height: 10),
            _JourneyChip(
                label: entry.relatedTaskName!,
                icon: Icons.repeat,
                color: accent),
          ],
          if (entry.hasImage) ...[
            SizedBox(height: 10),
            _JourneyImagePreview(imageUrl: entry.imageUrl!, color: accent),
          ],
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Habit progress':
        return Icons.track_changes;
      case 'Weekly achievement':
        return Icons.emoji_events;
      case 'Routine update':
        return Icons.repeat;
      case 'Daily auto update':
        return Icons.auto_graph;
      case 'Milestone':
        return Icons.flag;
      default:
        return Icons.edit_note;
    }
  }
}

class _RelatedTaskDropdownItem extends StatelessWidget {
  final Task task;
  final bool compact;

  _RelatedTaskDropdownItem({required this.task, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? double.infinity : 260,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: Color(task.colorValue), shape: BoxShape.circle),
          ),
          SizedBox(width: 8),
          Flexible(
              child: Text(toTitleCase(task.task),
                  overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
      ),
    );
  }
}

class _JourneyChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  _JourneyChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _JourneyImagePreview extends StatelessWidget {
  final String imageUrl;
  final Color color;

  _JourneyImagePreview({required this.imageUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    final isNetworkImage =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: 72),
        color: Colors.white.withOpacity(0.68),
        child: isNetworkImage
            ? Image.network(imageUrl, fit: BoxFit.cover)
            : Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.image, color: color),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(imageUrl,
                            style: TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
      ),
    );
  }
}

class _EmptyJourneyState extends StatelessWidget {
  _EmptyJourneyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.accent, size: 32),
          SizedBox(height: 8),
          Text('No journey entries yet',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          SizedBox(height: 4),
          Text(
            'Add your first habit progress moment, reflection, milestone, or photo to start building your growth story.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _JourneyEntryDialog extends StatefulWidget {
  final List<Task> tasks;

  final Future<void> Function(JourneyEntry) onSave;
  _JourneyEntryDialog({required this.tasks, required this.onSave});

  @override
  State<_JourneyEntryDialog> createState() => _JourneyEntryDialogState();
}

class _JourneyEntryDialogState extends State<_JourneyEntryDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageController = TextEditingController();

  DateTime _date = DateTime.now();
  String _type = 'Habit progress';
  bool _saving = false;
  String? _error;
  final String _entryId = DateTime.now().microsecondsSinceEpoch.toString();
  Task? _relatedTask;

  static const _types = [
    'Habit progress',
    'Weekly achievement',
    'Routine update',
    'Reflection',
    'Milestone',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskOptions = _uniqueTaskOptions(widget.tasks);
    final accent = Color(_relatedTask?.colorValue ?? AppColors.accent.value);

    return AlertDialog(
      title: Text('Add journey entry'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Title *',
                errorText: _error,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                labelText: 'Entry type',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: _types
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<Task?>(
              value: _relatedTask,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Related habit/task',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              selectedItemBuilder: (context) => [
                Text('No related task', overflow: TextOverflow.ellipsis),
                ...taskOptions.map((task) =>
                    _RelatedTaskDropdownItem(task: task, compact: true)),
              ],
              items: [
                DropdownMenuItem<Task?>(
                    value: null, child: Text('No related task')),
                ...taskOptions.map(
                  (task) => DropdownMenuItem<Task?>(
                    value: task,
                    child: _RelatedTaskDropdownItem(task: task),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _relatedTask = value),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(
                          'Date: ${_date.month}/${_date.day}/${_date.year}')),
                  TextButton(onPressed: _pickDate, child: Text('Select')),
                ],
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Reflection / Description',
                hintText: 'What changed, improved, or motivated you?',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _imageController,
              decoration: InputDecoration(
                labelText: 'Optional image URL or path',
                hintText: 'Progress photo, screenshot, setup image...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text('Save entry'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a journey title');
      return;
    }

    final entry = JourneyEntry(
      id: _entryId,
      date: _date,
      type: _type,
      title: title,
      description: _descriptionController.text.trim(),
      relatedTaskName: _relatedTask?.task,
      colorValue: _relatedTask?.colorValue ?? AppColors.accent.value,
      imageUrl: _imageController.text.trim().isEmpty
          ? null
          : _imageController.text.trim(),
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(entry);
      if (mounted) Navigator.pop(context, entry);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Could not save. Please retry.';
        });
    }
  }

  List<Task> _uniqueTaskOptions(List<Task> tasks) {
    final byName = <String, Task>{};
    for (final task in tasks) {
      final key = task.id;
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => task);
    }
    return byName.values.toList()..sort((a, b) => a.task.compareTo(b.task));
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _sectionLabelForDate(DateTime date) {
  final now = DateTime.now();
  final today = _dateOnly(now);
  final yesterday = today.subtract(Duration(days: 1));
  final weekStart = today.subtract(Duration(days: today.weekday - 1));

  if (_isSameDate(date, today)) return "Today's Activity";
  if (_isSameDate(date, yesterday)) return 'Yesterday';
  if (!date.isBefore(weekStart)) return 'Weekly History';
  return 'Monthly Journey';
}

String _friendlyDate(DateTime date) {
  final section = _sectionLabelForDate(date);
  if (section == "Today's Activity" || section == 'Yesterday') return section;
  return '${date.month}/${date.day}/${date.year}';
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Color _moodColor(String? mood) {
  switch (mood) {
    case 'Happy':
      return Color(0xFFFFC857);
    case 'Good':
      return Color(0xFF7BC96F);
    case 'Sad':
      return Color(0xFF64B5F6);
    case 'Angry':
      return Color(0xFFE57373);
    case 'Anxious':
      return Color(0xFFFFB74D);
    case 'Neutral':
      return Color(0xFF90A4AE);
    default:
      return AppColors.accent;
  }
}

String _moodEmoji(String mood) {
  switch (mood) {
    case 'Happy':
      return '😊';
    case 'Good':
      return '🙂';
    case 'Neutral':
      return '😐';
    case 'Sad':
      return '😔';
    case 'Angry':
      return '😠';
    case 'Anxious':
      return '😟';
    default:
      return '📝';
  }
}
