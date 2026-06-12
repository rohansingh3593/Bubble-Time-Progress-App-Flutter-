import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/journal_entry.dart';
import '../models/rank_profile.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../widgets/rank_profile_card.dart';

class JournalView extends StatefulWidget {
  final HiveService hiveService;
  final VoidCallback? onGoToDashboard;

  const JournalView({super.key, required this.hiveService, this.onGoToDashboard});

  static Route<void> route({required HiveService hiveService, VoidCallback? onGoToDashboard}) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => JournalView(
        hiveService: hiveService,
        onGoToDashboard: onGoToDashboard,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
    );
  }

  @override
  State<JournalView> createState() => _JournalViewState();
}

class _JournalViewState extends State<JournalView> {
  late DateTime _selectedDate;
  String _selectedMood = 'Good';
  final TextEditingController _reflectionController = TextEditingController();

  static const List<_MoodOption> _moods = [
    _MoodOption(label: 'Happy', emoji: '😊', color: Color(0xFFFFC857)),
    _MoodOption(label: 'Good', emoji: '🙂', color: Color(0xFF7BC96F)),
    _MoodOption(label: 'Neutral', emoji: '😐', color: Color(0xFF90A4AE)),
    _MoodOption(label: 'Sad', emoji: '😔', color: Color(0xFF64B5F6)),
    _MoodOption(label: 'Angry', emoji: '😠', color: Color(0xFFE57373)),
    _MoodOption(label: 'Anxious', emoji: '😟', color: Color(0xFFFFB74D)),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadEntryForSelectedDate();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  void _loadEntryForSelectedDate() {
    final entry = widget.hiveService.getJournalEntryForDate(_selectedDate);
    _selectedMood = entry?.mood ?? 'Good';
    _reflectionController.text = entry?.reflection ?? '';
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _loadEntryForSelectedDate();
    });
  }

  Future<void> _saveEntry(List<Task> tasksForDay) async {
    final total = tasksForDay.where((task) => task.status != 'Cancelled').length;
    final completed = tasksForDay
        .where((task) => _isCompleted(task) || widget.hiveService.isDailyJournalTask(task))
        .length;
    final score = total == 0 ? 0 : ((completed / total) * 100).round();

    await widget.hiveService.saveJournalEntry(
      JournalEntry(
        date: _selectedDate,
        mood: _selectedMood,
        reflection: _reflectionController.text.trim(),
        completedTasks: completed,
        totalTasks: total,
        productivityScore: score,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journal entry saved')),
    );
  }

  void _goBack() {
    Navigator.of(context).maybePop();
  }

  void _goToDashboard() {
    widget.onGoToDashboard?.call();
    Navigator.of(context).maybePop();
  }

  Future<void> _deleteEntry() async {
    await widget.hiveService.deleteJournalEntry(_selectedDate);
    if (!mounted) return;
    setState(() {
      _selectedMood = 'Good';
      _reflectionController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journal entry deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
        title: const Text('Journal & Reflection'),
        actions: [
          TextButton.icon(
            onPressed: _goToDashboard,
            icon: const Icon(Icons.home_rounded),
            label: const Text('Dashboard'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final allTasksByDate = widget.hiveService.getAllTasksByDate();
          final journalEntries = widget.hiveService.getAllJournalEntries();
          final tasksForDay = widget.hiveService.getTasksForDate(_selectedDate);
          final entry = widget.hiveService.getJournalEntryForDate(_selectedDate);
          final rankProfile = RankProfile.calculate(
            username: widget.hiveService.getUsername(),
            allTasksByDate: allTasksByDate,
            journalEntries: journalEntries,
          );
          final analytics = _JournalAnalytics.fromEntries(journalEntries);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              RankProfileCard(
                profile: rankProfile,
                onUsernameChanged: widget.hiveService.setUsername,
                compact: true,
                userProfile: widget.hiveService.getUserProfile(),
              ),
              const SizedBox(height: 14),
              _DateHeader(
                date: _selectedDate,
                hasEntry: entry != null,
                onPrevious: () => _changeDate(-1),
                onNext: () => _changeDate(1),
              ),
              const SizedBox(height: 14),
              _MoodSelector(
                moods: _moods,
                selectedMood: _selectedMood,
                onChanged: (mood) => setState(() => _selectedMood = mood),
              ),
              const SizedBox(height: 14),
              _ReflectionInput(controller: _reflectionController),
              const SizedBox(height: 14),
              _ProductivityConnection(tasks: tasksForDay, entry: entry),
              const SizedBox(height: 14),
              _ActionButtons(
                hasEntry: entry != null,
                onSave: () => _saveEntry(tasksForDay),
                onDelete: entry == null ? null : _deleteEntry,
              ),
              const SizedBox(height: 14),
              _JournalAnalyticsPanel(analytics: analytics),
              const SizedBox(height: 14),
              _JournalHistory(entries: journalEntries, tasksByDate: allTasksByDate),
            ],
          );
        },
      ),
    );
  }

  bool _isCompleted(Task task) => task.done || task.status == 'Completed';
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final bool hasEntry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _DateHeader({
    required this.date,
    required this.hasEntry,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _calmPanelDecoration(),
      child: Row(
        children: [
          IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Column(
              children: [
                const Text('Daily Reflection', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 4),
                Text('${date.month}/${date.day}/${date.year}', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 6),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(hasEntry ? 'Saved entry' : 'New entry'),
                  avatar: Icon(hasEntry ? Icons.check_circle : Icons.edit_note, size: 18),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final List<_MoodOption> moods;
  final String selectedMood;
  final ValueChanged<String> onChanged;

  const _MoodSelector({required this.moods, required this.selectedMood, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _calmPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How are you feeling today?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: moods.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.15,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final mood = moods[index];
              final selected = mood.label == selectedMood;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onChanged(mood.label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected ? mood.color.withOpacity(0.28) : AppColors.background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: selected ? mood.color : Colors.black12, width: selected ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(mood.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(mood.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReflectionInput extends StatelessWidget {
  final TextEditingController controller;

  const _ReflectionInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _calmPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Write your reflection', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Capture your thoughts, feelings, experiences, and what today taught you.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 6,
            maxLines: 10,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Today I noticed...',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductivityConnection extends StatelessWidget {
  final List<Task> tasks;
  final JournalEntry? entry;

  const _ProductivityConnection({required this.tasks, required this.entry});

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks.where((task) => task.status != 'Cancelled').toList();
    final completedTasks = activeTasks.where((task) => task.done || task.status == 'Completed').toList();
    final completed = completedTasks.length;
    final score = activeTasks.isEmpty ? 0 : ((completed / activeTasks.length) * 100).round();
    final accent = _taskAccentForTasks(activeTasks);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _calmPanelDecoration(accentColor: accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connected productivity data', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Tasks', value: '$completed/${activeTasks.length}', accentColor: accent)),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'Score', value: '$score%', accentColor: accent)),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'Saved mood', value: entry?.mood ?? '—', accentColor: accent)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: activeTasks.isEmpty ? 0.0 : completed / activeTasks.length,
            minHeight: 9,
            borderRadius: BorderRadius.circular(99),
            color: accent,
            backgroundColor: accent.withOpacity(0.14),
          ),
          if (activeTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeTasks.map((task) => _JournalTaskChip(task: task)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool hasEntry;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  const _ActionButtons({required this.hasEntry, required this.onSave, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save),
            label: Text(hasEntry ? 'Update Entry' : 'Save Entry'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Entry'),
          ),
        ),
      ],
    );
  }
}

class _JournalAnalyticsPanel extends StatelessWidget {
  final _JournalAnalytics analytics;

  const _JournalAnalyticsPanel({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _calmPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Journal Analytics', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AnalyticsPill(label: 'Entries', value: '${analytics.totalEntries}'),
              _AnalyticsPill(label: 'Top mood', value: analytics.topMood),
              _AnalyticsPill(label: 'Weekly reflections', value: '${analytics.weekEntries}'),
              _AnalyticsPill(label: 'Monthly reflections', value: '${analytics.monthEntries}'),
              _AnalyticsPill(label: 'Avg productivity', value: '${analytics.averageProductivity}%'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            analytics.patternInsight,
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _JournalHistory extends StatelessWidget {
  final List<JournalEntry> entries;
  final Map<DateTime, List<Task>> tasksByDate;

  const _JournalHistory({required this.entries, required this.tasksByDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _calmPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reflection History', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Text('No journal entries yet. Save your first reflection today.', style: TextStyle(color: Colors.black54))
          else
            ...entries.take(8).map((entry) => _HistoryTile(entry: entry, tasks: tasksByDate[_dateOnly(entry.date)] ?? const <Task>[])),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final JournalEntry entry;
  final List<Task> tasks;

  const _HistoryTile({required this.entry, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final preview = entry.reflection.trim().isEmpty ? 'No reflection text saved.' : entry.reflection.trim();
    final accent = _taskAccentForTasks(tasks);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(_emojiForMood(entry.mood), style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry.date.month}/${entry.date.day}/${entry.date.year} • ${entry.mood}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Productivity: ${entry.completedTasks}/${entry.totalTasks} tasks • ${entry.productivityScore}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? accentColor;

  const _MiniStat({required this.label, required this.value, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: accent)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AnalyticsPill extends StatelessWidget {
  final String label;
  final String value;

  const _AnalyticsPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
    );
  }
}


class _JournalTaskChip extends StatelessWidget {
  final Task task;

  const _JournalTaskChip({required this.task});

  @override
  Widget build(BuildContext context) {
    final taskColor = Color(task.colorValue);
    final isCompleted = task.done || task.status == 'Completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: taskColor.withOpacity(isCompleted ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: taskColor.withOpacity(isCompleted ? 0.38 : 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCompleted ? Icons.check_circle : Icons.circle_outlined, size: 15, color: taskColor),
          const SizedBox(width: 6),
          Text(
            task.task,
            style: TextStyle(color: taskColor, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

Color _taskAccentForTasks(List<Task> tasks) {
  final activeTasks = tasks.where((task) => task.status != 'Cancelled').toList();
  if (activeTasks.isEmpty) return AppColors.accent;

  for (final task in activeTasks) {
    if (task.done || task.status == 'Completed') return Color(task.colorValue);
  }

  return Color(activeTasks.first.colorValue);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _JournalAnalytics {
  final int totalEntries;
  final int weekEntries;
  final int monthEntries;
  final int averageProductivity;
  final String topMood;
  final String patternInsight;

  const _JournalAnalytics({
    required this.totalEntries,
    required this.weekEntries,
    required this.monthEntries,
    required this.averageProductivity,
    required this.topMood,
    required this.patternInsight,
  });

  factory _JournalAnalytics.fromEntries(List<JournalEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);
    final moodCounts = <String, int>{};
    var productivityTotal = 0;

    for (final entry in entries) {
      moodCounts.update(entry.mood, (value) => value + 1, ifAbsent: () => 1);
      productivityTotal += entry.productivityScore;
    }

    final topMood = moodCounts.isEmpty
        ? 'No mood yet'
        : moodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final averageProductivity = entries.isEmpty ? 0 : (productivityTotal / entries.length).round();
    final weekEntries = entries.where((entry) => !entry.date.isBefore(weekStart)).length;
    final monthEntries = entries.where((entry) => !entry.date.isBefore(monthStart)).length;

    final insight = entries.isEmpty
        ? 'Start journaling to connect emotions with productive and unproductive days.'
        : averageProductivity >= 70
            ? 'Your reflections are trending with strong productivity days.'
            : 'Keep reflecting to discover which moods support better task completion.';

    return _JournalAnalytics(
      totalEntries: entries.length,
      weekEntries: weekEntries,
      monthEntries: monthEntries,
      averageProductivity: averageProductivity,
      topMood: topMood,
      patternInsight: insight,
    );
  }
}

class _MoodOption {
  final String label;
  final String emoji;
  final Color color;

  const _MoodOption({required this.label, required this.emoji, required this.color});
}

BoxDecoration _calmPanelDecoration({Color? accentColor}) {
  final accent = accentColor;
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(24),
    border: accent == null ? null : Border.all(color: accent.withOpacity(0.18)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String _emojiForMood(String mood) {
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
