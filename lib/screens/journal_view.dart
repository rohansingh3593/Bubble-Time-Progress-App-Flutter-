import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/journal_entry.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';
import '../widgets/recoverable_delete.dart';

class JournalView extends StatefulWidget {
  final HiveService hiveService;
  final VoidCallback? onGoToDashboard;
  final DateTime? initialDate;

  JournalView(
      {super.key,
      required this.hiveService,
      this.onGoToDashboard,
      this.initialDate});

  static Route<void> route({
    required HiveService hiveService,
    VoidCallback? onGoToDashboard,
    DateTime? initialDate,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => JournalView(
        hiveService: hiveService,
        onGoToDashboard: onGoToDashboard,
        initialDate: initialDate,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: 360),
      reverseTransitionDuration: Duration(milliseconds: 280),
    );
  }

  @override
  State<JournalView> createState() => _JournalViewState();
}

class _JournalViewState extends State<JournalView> {
  late DateTime _selectedDate;
  String _selectedMood = 'Good';
  final _reflectionController = TextEditingController();
  Future<void> _draftWrite = Future.value();
  int _draftRevision = 0;
  bool _loading = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _leaving = false;
  String? _error;
  String _draftStatus = '';

  static const _moods = ['Happy', 'Good', 'Neutral', 'Sad', 'Angry', 'Anxious'];

  @override
  void initState() {
    super.initState();
    final date = widget.initialDate ?? DateTime.now();
    _selectedDate = DateUtils.dateOnly(date);
    _loadEntry();
    _reflectionController.addListener(_queueDraft);
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  void _loadEntry() {
    _loading = true;
    final saved = widget.hiveService.getJournalEntryForDate(_selectedDate);
    final draft = widget.hiveService.getJournalDraft(_selectedDate);
    final draftMood = draft?['mood'] as String?;
    final draftText = draft?['text'] as String?;
    final draftMatchesSaved = saved != null &&
        draftText?.trim() == saved.reflection.trim() &&
        draftMood == saved.mood;
    final hasUnsavedDraft = draft != null && !draftMatchesSaved;
    _selectedMood = hasUnsavedDraft
        ? draftMood ?? saved?.mood ?? 'Good'
        : saved?.mood ?? draftMood ?? 'Good';
    _reflectionController.text = hasUnsavedDraft
        ? draftText ?? saved?.reflection ?? ''
        : saved?.reflection ?? draftText ?? '';
    _draftStatus = hasUnsavedDraft
        ? 'Draft restored'
        : saved == null
            ? 'New reflection'
            : 'Entry saved';
    if (draftMatchesSaved) {
      final date = _selectedDate;
      _draftWrite = _draftWrite.then((_) async {
        try {
          await widget.hiveService.clearJournalDraft(date);
        } catch (_) {
          if (mounted && _selectedDate == date) {
            setState(() => _error =
                'Your entry is saved, but an older draft copy could not be cleared.');
          }
        }
      });
    }
    _error = null;
    _loading = false;
  }

  void _queueDraft() {
    if (_loading) return;
    final revision = ++_draftRevision;
    final date = _selectedDate;
    final text = _reflectionController.text;
    final mood = _selectedMood;
    final saved = widget.hiveService.getJournalEntryForDate(date);
    final matchesSaved = saved != null &&
        text.trim() == saved.reflection.trim() &&
        mood == saved.mood;
    setState(() {
      _draftStatus = matchesSaved ? 'Entry saved' : 'Saving draft...';
      _error = null;
    });
    // Serialize writes so a slow earlier write cannot replace newer typing.
    _draftWrite = _draftWrite.then((_) async {
      try {
        if (matchesSaved) {
          await widget.hiveService.clearJournalDraft(date);
        } else {
          await widget.hiveService.saveJournalDraft(date, text, mood);
        }
        if (mounted && date == _selectedDate && revision == _draftRevision) {
          setState(() => _draftStatus =
              matchesSaved ? 'Entry saved' : 'Draft saved on this device');
        }
      } catch (_) {
        if (mounted && revision == _draftRevision) {
          setState(() => _error = matchesSaved
              ? 'Your entry is saved, but an older draft copy could not be cleared.'
              : 'Draft could not be saved. Keep this page open and retry.');
        }
      }
    });
  }

  Future<bool> _flushDraft() async {
    _queueDraft();
    await _draftWrite;
    return _error == null;
  }

  Future<void> _changeDate(int days) async {
    if (_saving || _leaving) return;
    _leaving = true;
    final safe = await _flushDraft();
    if (mounted && safe)
      setState(() {
        _selectedDate = _selectedDate.add(Duration(days: days));
        _loadEntry();
      });
    _leaving = false;
  }

  Future<void> _leave() async {
    if (_saving || _leaving) return;
    _leaving = true;
    final safe = await _flushDraft();
    if (mounted && safe) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
    _leaving = false;
  }

  Future<void> _saveEntry() async {
    if (_saving) return;
    final reflection = _reflectionController.text.trim();
    if (reflection.isEmpty) {
      setState(() => _error = 'Write a reflection before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final date = _selectedDate;
    final tasks = widget.hiveService
        .getTasksForDate(date)
        .where((t) => t.status != 'Cancelled')
        .toList();
    final completed = tasks
        .where((t) =>
            t.done ||
            t.status == 'Completed' ||
            widget.hiveService.isDailyJournalTask(t))
        .length;
    final now = DateTime.now();
    try {
      await _draftWrite;
      await widget.hiveService.saveJournalEntry(JournalEntry(
        date: DateTime(
            date.year, date.month, date.day, now.hour, now.minute, now.second),
        mood: _selectedMood,
        reflection: reflection,
        completedTasks: completed,
        totalTasks: tasks.length,
        productivityScore:
            tasks.isEmpty ? 0 : (completed / tasks.length * 100).round(),
      ));
      await widget.hiveService.clearJournalDraft(date);
      if (mounted) {
        setState(() => _draftStatus = 'Entry saved');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Journal entry saved')));
      }
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Could not save the entry. Your writing is still here; please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEntry() async {
    final date = _selectedDate;
    final entry = widget.hiveService.getJournalEntryForDate(date);
    if (entry == null) return;
    await recoverableDelete(context, label: 'journal entry', remove: () async {
      await _draftWrite;
      await widget.hiveService.deleteJournalEntry(date);
      await widget.hiveService.clearJournalDraft(date);
      if (mounted) setState(_loadEntry);
    }, restore: () async {
      await widget.hiveService.saveJournalEntry(entry);
      if (mounted && _selectedDate == date) setState(_loadEntry);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text('Journal'),
            leading: IconButton(
                tooltip: 'Back',
                onPressed: _saving ? null : _leave,
                icon: Icon(Icons.arrow_back))),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: FilledButton.icon(
                    onPressed: _saving ? null : _saveEntry,
                    icon: Icon(Icons.check),
                    label: Text(_saving ? 'Saving...' : 'Save reflection')))),
        body: ListView(padding: EdgeInsets.all(16), children: [
          Row(children: [
            IconButton(
                tooltip: 'Previous day',
                onPressed: _saving ? null : () => _changeDate(-1),
                icon: Icon(Icons.chevron_left)),
            Expanded(
                child: Text(
                    MaterialLocalizations.of(context)
                        .formatFullDate(_selectedDate),
                    textAlign: TextAlign.center)),
            IconButton(
                tooltip: 'Next day',
                onPressed: _saving ? null : () => _changeDate(1),
                icon: Icon(Icons.chevron_right)),
          ]),
          Semantics(
              liveRegion: true,
              child: Text(_draftStatus,
                  style: Theme.of(context).textTheme.bodySmall)),
          SizedBox(height: 12),
          Wrap(
              spacing: 8,
              children: _moods
                  .map((mood) => ChoiceChip(
                      label: Text(mood),
                      selected: _selectedMood == mood,
                      onSelected: _saving
                          ? null
                          : (_) {
                              setState(() => _selectedMood = mood);
                              _queueDraft();
                            }))
                  .toList()),
          SizedBox(height: 16),
          TextField(
              controller: _reflectionController,
              enabled: !_saving,
              minLines: 8,
              maxLines: null,
              decoration: InputDecoration(
                  labelText: 'Your reflection',
                  hintText: 'What mattered today?',
                  alignLabelWithHint: true,
                  errorText: _error,
                  border: OutlineInputBorder())),
          if (_error != null)
            TextButton(
                onPressed: _flushDraft, child: Text('Retry saving draft')),
          SizedBox(height: 24),
          ExpansionTile(title: Text('History and insights'), children: [
            _JournalAnalyticsPanel(
                analytics: _JournalAnalytics.fromEntries(
                    widget.hiveService.getAllJournalEntries())),
            _JournalHistory(
                entries: widget.hiveService.getAllJournalEntries(),
                tasksByDate: widget.hiveService.getAllTasksByDate()),
          ]),
          if (widget.hiveService.getJournalEntryForDate(_selectedDate) != null)
            TextButton.icon(
                onPressed: _saving ? null : _deleteEntry,
                icon: Icon(Icons.delete_outline),
                label: Text('Delete entry')),
        ]),
      ),
    );
  }
}

class _JournalAnalyticsPanel extends StatelessWidget {
  final _JournalAnalytics analytics;

  _JournalAnalyticsPanel({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _calmPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Journal Analytics',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AnalyticsPill(
                  label: 'Entries', value: '${analytics.totalEntries}'),
              _AnalyticsPill(label: 'Top mood', value: analytics.topMood),
              _AnalyticsPill(
                  label: 'Weekly reflections',
                  value: '${analytics.weekEntries}'),
              _AnalyticsPill(
                  label: 'Monthly reflections',
                  value: '${analytics.monthEntries}'),
              _AnalyticsPill(
                  label: 'Avg productivity',
                  value: '${analytics.averageProductivity}%'),
            ],
          ),
          SizedBox(height: 12),
          Text(
            analytics.patternInsight,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _JournalHistory extends StatelessWidget {
  final List<JournalEntry> entries;
  final Map<DateTime, List<Task>> tasksByDate;

  _JournalHistory({required this.entries, required this.tasksByDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _calmPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reflection History',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          SizedBox(height: 10),
          if (entries.isEmpty)
            Text('No journal entries yet. Save your first reflection today.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            ...entries.take(8).map((entry) => _HistoryTile(
                entry: entry,
                tasks: tasksByDate[_dateOnly(entry.date)] ?? <Task>[])),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final JournalEntry entry;
  final List<Task> tasks;

  _HistoryTile({required this.entry, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final preview = entry.reflection.trim().isEmpty
        ? 'No reflection text saved.'
        : entry.reflection.trim();
    final accent = _taskAccentForTasks(tasks);
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
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
            child:
                Text(_emojiForMood(entry.mood), style: TextStyle(fontSize: 22)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${entry.date.month}/${entry.date.day}/${entry.date.year} • ${entry.mood}',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: 4),
                Text(
                  'Productivity: ${entry.completedTasks}/${entry.totalTasks} tasks • ${entry.productivityScore}%',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: accent),
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

  _MiniStat({required this.label, required this.value, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.accent;
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16, color: accent)),
          SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11)),
        ],
      ),
    );
  }
}

class _AnalyticsPill extends StatelessWidget {
  final String label;
  final String value;

  _AnalyticsPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11)),
        ],
      ),
    );
  }
}

class _JournalTaskChip extends StatelessWidget {
  final Task task;

  _JournalTaskChip({required this.task});

  @override
  Widget build(BuildContext context) {
    final taskColor = Color(task.colorValue);
    final isCompleted = task.done || task.status == 'Completed';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: taskColor.withOpacity(isCompleted ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: taskColor.withOpacity(isCompleted ? 0.38 : 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCompleted ? Icons.check_circle : Icons.circle_outlined,
              size: 15, color: taskColor),
          SizedBox(width: 6),
          Text(
            task.task,
            style: TextStyle(
                color: taskColor, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

Color _taskAccentForTasks(List<Task> tasks) {
  final activeTasks =
      tasks.where((task) => task.status != 'Cancelled').toList();
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

  _JournalAnalytics({
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
    final averageProductivity =
        entries.isEmpty ? 0 : (productivityTotal / entries.length).round();
    final weekEntries =
        entries.where((entry) => !entry.date.isBefore(weekStart)).length;
    final monthEntries =
        entries.where((entry) => !entry.date.isBefore(monthStart)).length;

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

BoxDecoration _calmPanelDecoration(BuildContext context, {Color? accentColor}) {
  final accent = accentColor;
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(24),
    border: accent == null ? null : Border.all(color: accent.withOpacity(0.18)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 18,
        offset: Offset(0, 8),
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
