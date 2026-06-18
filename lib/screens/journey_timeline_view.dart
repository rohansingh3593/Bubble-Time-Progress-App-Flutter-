import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/journal_entry.dart';
import '../models/journey_entry.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../widgets/profile_avatar.dart';
import '../utils/text_formatters.dart';

class JourneyTimelineView extends StatelessWidget {
  final HiveService hiveService;

  const JourneyTimelineView({super.key, required this.hiveService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journey Timeline')),
      body: ValueListenableBuilder(
        valueListenable: hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final manualEntries = hiveService.getAllJourneyEntries();
          final tasksByDate = hiveService.getAllTasksByDate();
          final journalEntries = hiveService.getAllJournalEntries();
          final allTasks = tasksByDate.values.expand((tasks) => tasks).toList();
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
                onDeleteEntry: hiveService.deleteJourneyEntry,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              _JourneyHero(onAdd: () => _showEntryDialog(context, allTasks), hiveService: hiveService),
              const SizedBox(height: 14),
              if (dailyJourneys.isEmpty)
                const _EmptyJourneyState()
              else
                ...timelineWidgets,
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEntryDialog(
          context,
          hiveService.getAllTasksByDate().values.expand((tasks) => tasks).toList(),
        ),
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Log journey'),
      ),
    );
  }

  Future<void> _showEntryDialog(BuildContext context, List<Task> tasks) async {
    final created = await showDialog<JourneyEntry>(
      context: context,
      builder: (context) => _JourneyEntryDialog(tasks: tasks),
    );

    if (created != null) {
      await hiveService.saveJourneyEntry(created);
    }
  }
}


class _DailyJourney {
  final DateTime date;
  final List<Task> tasks;
  final JournalEntry? journalEntry;
  final List<JourneyEntry> manualEntries;

  const _DailyJourney({
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
    return tasks.isNotEmpty ||
        journalEntry != null ||
        manualEntries.isNotEmpty;
  }

  Color get accentColor {
    if (completedTasks.isNotEmpty) return Color(completedTasks.first.colorValue);
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

    final journeys = dates.map((date) {
      final entries = (manualByDate[date] ?? const <JourneyEntry>[]).toList()
        ..sort((a, b) {
          if (a.isAutoDailySummary != b.isAutoDailySummary) return a.isAutoDailySummary ? -1 : 1;
          return b.date.compareTo(a.date);
        });
      return _DailyJourney(
        date: date,
        tasks: tasksByDate[date] ?? const <Task>[],
        journalEntry: journalsByDate[date],
        manualEntries: entries,
      );
    }).where((journey) => journey.hasActivity).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return journeys;
  }

  static bool _isCompletedTask(Task task) => task.done || task.status.trim().toLowerCase() == 'completed';
}

class _TimelineSectionHeader extends StatelessWidget {
  final String label;

  const _TimelineSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
      ),
    );
  }
}

class _DailyJourneyCard extends StatelessWidget {
  final _DailyJourney journey;
  final Future<void> Function(String id) onDeleteEntry;

  const _DailyJourneyCard({required this.journey, required this.onDeleteEntry});

  @override
  Widget build(BuildContext context) {
    final accent = journey.accentColor;
    final journal = journey.journalEntry;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.09),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_friendlyDate(journey.date), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      '${journey.completedTasks.length} completed • ${journey.habitUpdates.length} habit updates • ${journal?.mood ?? 'No mood'}',
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (journal != null) _MoodReflectionPanel(journal: journal),
          if (journey.completedTasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TaskWrap(
              title: 'Completed tasks',
              tasks: journey.completedTasks,
              icon: Icons.check_circle,
            ),
          ],
          if (journey.habitUpdates.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TaskWrap(
              title: 'Habit updates',
              tasks: journey.habitUpdates,
              icon: Icons.repeat,
            ),
          ],
          if (journey.manualEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
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

  const _MoodReflectionPanel({required this.journal});

  @override
  Widget build(BuildContext context) {
    final color = _moodColor(journal.mood);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
              Text(_moodEmoji(journal.mood), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(journal.mood, style: const TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('${journal.productivityScore}%', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ],
          ),
          if (journal.reflection.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(journal.reflection.trim(), maxLines: 4, overflow: TextOverflow.ellipsis),
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

  const _TaskWrap({required this.title, required this.tasks, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tasks.map((task) => _JourneyChip(label: task.task, icon: icon, color: Color(task.colorValue))).toList(),
        ),
      ],
    );
  }
}

class _JourneyHero extends StatelessWidget {
  final VoidCallback onAdd;
  final HiveService hiveService;

  const _JourneyHero({required this.onAdd, required this.hiveService});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7E57C2), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(profile: hiveService.getUserProfile(), radius: 24, accentColor: AppColors.accent, showGlow: false),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Personal Journey Timeline',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Log habit progress, milestone wins, reflections, routines, and optional progress images in one personal growth feed.',
            style: TextStyle(color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add journey entry'),
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

  const _JourneyEntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final accent = Color(entry.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.date.month}/${entry.date.day}/${entry.date.year} • ${entry.type}',
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (!entry.isAutoDailySummary)
                IconButton(
                  tooltip: 'Delete entry',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: onDelete,
                ),
            ],
          ),
          if (entry.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(entry.description, style: const TextStyle(color: Colors.black87, height: 1.3)),
          ],
          if (entry.relatedTaskName != null) ...[
            const SizedBox(height: 10),
            _JourneyChip(label: entry.relatedTaskName!, icon: Icons.repeat, color: accent),
          ],
          if (entry.hasImage) ...[
            const SizedBox(height: 10),
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

  const _RelatedTaskDropdownItem({required this.task, this.compact = false});

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
            decoration: BoxDecoration(color: Color(task.colorValue), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(toTitleCase(task.task), overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
      ),
    );
  }
}

class _JourneyChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _JourneyChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _JourneyImagePreview extends StatelessWidget {
  final String imageUrl;
  final Color color;

  const _JourneyImagePreview({required this.imageUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    final isNetworkImage = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 72),
        color: Colors.white.withOpacity(0.68),
        child: isNetworkImage
            ? Image.network(imageUrl, fit: BoxFit.cover)
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.image, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(imageUrl, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
      ),
    );
  }
}

class _EmptyJourneyState extends StatelessWidget {
  const _EmptyJourneyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.accent, size: 32),
          SizedBox(height: 8),
          Text('No journey entries yet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          SizedBox(height: 4),
          Text(
            'Add your first habit progress moment, reflection, milestone, or photo to start building your growth story.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _JourneyEntryDialog extends StatefulWidget {
  final List<Task> tasks;

  const _JourneyEntryDialog({required this.tasks});

  @override
  State<_JourneyEntryDialog> createState() => _JourneyEntryDialogState();
}

class _JourneyEntryDialogState extends State<_JourneyEntryDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageController = TextEditingController();

  DateTime _date = DateTime.now();
  String _type = 'Habit progress';
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
      title: const Text('Add journey entry'),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                labelText: 'Entry type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: _types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Task?>(
              value: _relatedTask,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Related habit/task',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              selectedItemBuilder: (context) => [
                const Text('No related task', overflow: TextOverflow.ellipsis),
                ...taskOptions.map((task) => _RelatedTaskDropdownItem(task: task, compact: true)),
              ],
              items: [
                const DropdownMenuItem<Task?>(value: null, child: Text('No related task')),
                ...taskOptions.map(
                  (task) => DropdownMenuItem<Task?>(
                    value: task,
                    child: _RelatedTaskDropdownItem(task: task),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _relatedTask = value),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('Date: ${_date.month}/${_date.day}/${_date.year}')),
                  TextButton(onPressed: _pickDate, child: const Text('Select')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Reflection / Description',
                hintText: 'What changed, improved, or motivated you?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imageController,
              decoration: InputDecoration(
                labelText: 'Optional image URL or path',
                hintText: 'Progress photo, screenshot, setup image...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save entry'),
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

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journey title is required')));
      return;
    }

    final entry = JourneyEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: _date,
      type: _type,
      title: title,
      description: _descriptionController.text.trim(),
      relatedTaskName: _relatedTask?.task,
      colorValue: _relatedTask?.colorValue ?? AppColors.accent.value,
      imageUrl: _imageController.text.trim().isEmpty ? null : _imageController.text.trim(),
    );

    Navigator.pop(context, entry);
  }

  List<Task> _uniqueTaskOptions(List<Task> tasks) {
    final byName = <String, Task>{};
    for (final task in tasks) {
      final key = task.task.trim().toLowerCase();
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
  final yesterday = today.subtract(const Duration(days: 1));
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

bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

Color _moodColor(String? mood) {
  switch (mood) {
    case 'Happy':
      return const Color(0xFFFFC857);
    case 'Good':
      return const Color(0xFF7BC96F);
    case 'Sad':
      return const Color(0xFF64B5F6);
    case 'Angry':
      return const Color(0xFFE57373);
    case 'Anxious':
      return const Color(0xFFFFB74D);
    case 'Neutral':
      return const Color(0xFF90A4AE);
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
