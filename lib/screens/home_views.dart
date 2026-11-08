import 'dart:async';
import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../constants/dashboard_themes.dart';
import '../models/task_model.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/task_row.dart';
import '../widgets/task_completion.dart';
import '../widgets/dashboard_wallpaper_background.dart';
import 'day_view.dart';
import 'week_view.dart';
import 'month_view.dart';
import 'year_view.dart';
import 'task_screen.dart';
import 'journal_view.dart';
import 'streak_view.dart';
import 'log_earn_view.dart';
import 'journey_timeline_view.dart';
import 'instruction_dashboard_view.dart';
import 'goal_dashboard_view.dart';
import 'reward_money_history_view.dart';
import 'motivation_motto_dashboard_view.dart';
import 'voice_tasks_screen.dart';

const _todayTaskPreviewLimit = 3;

void openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class TodayView extends StatefulWidget {
  const TodayView({super.key, required this.service, this.now});
  final HiveService service;
  final DateTime Function()? now;
  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> with WidgetsBindingObserver {
  late DateTime _day;
  Timer? _midnight;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDate();
  }

  void _refreshDate() {
    _day = DateUtils.dateOnly(widget.now?.call() ?? DateTime.now());
    _midnight?.cancel();
    _midnight = Timer(
        DateTime(_day.year, _day.month, _day.day + 1)
                .difference(widget.now?.call() ?? DateTime.now()) +
            const Duration(seconds: 1), () {
      if (mounted) setState(_refreshDate);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(_refreshDate);
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _edit(Task task) => showTaskFormDialog(context,
      date: _day,
      initialTask: task,
      title: 'Edit task',
      actionLabel: 'Save task',
      onSave: (updated) => widget.service.saveTaskChanges(task, updated));

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Today'),
            actions: [
              IconButton(
                  tooltip: 'Journal: write a reflection for this date',
                  onPressed: () => openPage(
                      context,
                      JournalView(
                          hiveService: widget.service, initialDate: _day)),
                  icon: const Icon(Icons.edit_note)),
              IconButton(
                  tooltip: 'Voice tasks: add a task by speaking',
                  onPressed: () => openPage(
                      context, VoiceTasksScreen(hiveService: widget.service)),
                  icon: const Icon(Icons.mic)),
            ]),
        body: ValueListenableBuilder(
            valueListenable: widget.service.getBoxListenable(),
            builder: (context, _, __) {
              final tasks = widget.service
                  .getMasterTaskOccurrencesForDate(_day)
                  .where((t) =>
                      t.status != 'Cancelled' &&
                      (t.repeatTask || DateUtils.isSameDay(t.dueDate, _day)) &&
                      (!t.repeatTask || t.routineEnabled))
                  .toList()
                ..sort((a, b) =>
                    (widget.service.getTaskScheduledStartMinutes(a) ?? 1440)
                        .compareTo(
                            widget.service.getTaskScheduledStartMinutes(b) ??
                                1440));
              final overdue = widget.service
                  .getAllTasksByDate()
                  .values
                  .expand((tasks) => tasks)
                  .where((t) =>
                      !t.repeatTask &&
                      !taskCompleted(t) &&
                      t.status != 'Cancelled' &&
                      DateUtils.dateOnly(t.dueDate).isBefore(_day) &&
                      !widget.service.isDailyJournalTask(t))
                  .toList()
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              final pending = tasks.where((t) => !taskCompleted(t)).toList();
              final done = tasks.length - pending.length;
              final motto = widget.service.getNextMotivationMotto();
              final palette = widget.service.getDashboardPalette();
              final style = DashboardThemeStyle.of(
                  widget.service.getDashboardTheme(),
                  palette: palette);
              final contentTop =
                  MediaQuery.viewPaddingOf(context).top + kToolbarHeight + 16;
              return DashboardWallpaperBackground(
                  palette: palette,
                  style: style,
                  child: ListView(
                      padding: EdgeInsets.fromLTRB(16, contentTop, 16, 16),
                      children: [
                        Text(
                            MaterialLocalizations.of(context)
                                .formatFullDate(_day),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: () => showQuickAddTaskDialog(
                                context, _day, widget.service),
                            icon: const Icon(Icons.add),
                            label: const Text('Add task')),
                        const SizedBox(height: 20),
                        Text(
                            pending.isEmpty
                                ? 'You have space for what matters'
                                : 'Next up',
                            style: Theme.of(context).textTheme.titleLarge),
                        if (pending.isEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(tasks.isEmpty
                                  ? 'Add your first task, or write a reflection.'
                                  : 'Your planned tasks are complete. Review your day or plan tomorrow.')),
                        for (final task in pending.take(_todayTaskPreviewLimit))
                          TaskRow(
                              key: ValueKey(task.id),
                              task: task,
                              date: _day,
                              service: widget.service,
                              compact: true,
                              emphasizeSchedule: true,
                              onEdit: () => _edit(task)),
                        if (pending.length > _todayTaskPreviewLimit)
                          ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                  'Show ${pending.length - _todayTaskPreviewLimit} more tasks'),
                              children: [
                                for (final task
                                    in pending.skip(_todayTaskPreviewLimit))
                                  TaskRow(
                                      key: ValueKey(task.id),
                                      task: task,
                                      date: _day,
                                      service: widget.service,
                                      compact: true,
                                      emphasizeSchedule: true,
                                      onEdit: () => _edit(task)),
                              ]),
                        if (overdue.isNotEmpty)
                          ExpansionTile(
                              title: Text('Overdue (${overdue.length})'),
                              subtitle: const Text(
                                  'Review, complete or move to another day'),
                              children: [
                                for (final task in overdue.take(5))
                                  TaskRow(
                                      key: ValueKey('overdue-${task.id}'),
                                      task: task,
                                      date: task.dueDate,
                                      service: widget.service,
                                      compact: true,
                                      emphasizeSchedule: true,
                                      onEdit: () => _edit(task)),
                                TextButton(
                                    onPressed: () => openPage(
                                        context,
                                        TaskScreen(
                                            date: _day,
                                            hiveService: widget.service,
                                            initialFilter: 'Overdue')),
                                    child:
                                        const Text('View all overdue tasks')),
                              ]),
                        if (tasks.isNotEmpty)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '$done of ${tasks.length} tasks completed',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                            value: done / tasks.length,
                                            semanticsLabel:
                                                'Today task completion progress',
                                            semanticsValue:
                                                '${(done / tasks.length * 100).round()}'),
                                      ]))),
                        OutlinedButton.icon(
                            onPressed: () => openPage(
                                context,
                                JournalView(
                                    hiveService: widget.service,
                                    initialDate: _day)),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Reflect on today')),
                        if (motto != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(motto.quote,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge)),
                        const SizedBox(height: 20),
                        if (done > 0)
                          ExpansionTile(
                              title: Text('Completed ($done)'),
                              children: tasks
                                  .where(taskCompleted)
                                  .map((task) => TaskRow(
                                      task: task,
                                      date: _day,
                                      service: widget.service,
                                      compact: true,
                                      emphasizeSchedule: true,
                                      onEdit: () => _edit(task)))
                                  .toList()),
                      ]));
            }),
      );
}

class PlanView extends StatefulWidget {
  const PlanView({super.key, required this.service});
  final HiveService service;
  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  int _scale = 2;
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  void _selectDate(DateTime date) =>
      setState(() => _date = DateUtils.dateOnly(date));

  void _openDay(DateTime date) {
    setState(() {
      _date = DateUtils.dateOnly(date);
      _scale = 0;
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (date != null && mounted) _selectDate(date);
  }

  DateTime _shiftDate(int direction) {
    switch (_scale) {
      case 0:
        return _date.add(Duration(days: direction));
      case 1:
        return _date.add(Duration(days: direction * 7));
      case 2:
        final month = DateTime(_date.year, _date.month + direction, 1);
        final lastDay = DateTime(month.year, month.month + 1, 0).day;
        return DateTime(month.year, month.month, _date.day.clamp(1, lastDay));
      default:
        final year = _date.year + direction;
        final lastDay = DateTime(year, _date.month + 1, 0).day;
        return DateTime(year, _date.month, _date.day.clamp(1, lastDay));
    }
  }

  String _selectedPeriodLabel() {
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
    if (_scale == 3) return '${_date.year}';
    if (_scale == 2) return '${months[_date.month - 1]} ${_date.year}';
    if (_scale == 1) {
      final start = _date.subtract(Duration(days: _date.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]} ${end.year}';
    }
    return '${_date.day} ${months[_date.month - 1]} ${_date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              Expanded(
                  child: Semantics(
                      header: true,
                      child: Text('Plan',
                          style: Theme.of(context).textTheme.titleLarge))),
              TextButton(
                  onPressed: () => _selectDate(DateTime.now()),
                  child: const Text('Today')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(children: [
              IconButton(
                tooltip: 'Previous ${['day', 'week', 'month', 'year'][_scale]}',
                onPressed: () => _selectDate(_shiftDate(-1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Tooltip(
                  message: 'Choose a date',
                  child: TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_selectedPeriodLabel()),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next ${['day', 'week', 'month', 'year'][_scale]}',
                onPressed: () => _selectDate(_shiftDate(1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(spacing: 8, children: [
              for (var i = 0; i < 4; i++)
                ChoiceChip(
                    label: Text(['Day', 'Week', 'Month', 'Year'][i]),
                    tooltip:
                        'Show ${['day', 'week', 'month', 'year'][i]} calendar',
                    selected: _scale == i,
                    onSelected: (_) => setState(() => _scale = i)),
            ]),
          ),
          Expanded(
              child: KeyedSubtree(
                  key: ValueKey(_scale),
                  child: switch (_scale) {
                    0 => DayView(
                        hiveService: widget.service,
                        initialDate: _date,
                        onDateChanged: _selectDate,
                        showPeriodControls: false),
                    1 => WeekView(
                        hiveService: widget.service,
                        initialDate: _date,
                        onDateChanged: _selectDate,
                        onOpenDate: _openDay,
                        showPeriodControls: false),
                    2 => MonthView(
                        hiveService: widget.service,
                        initialDate: _date,
                        onDateChanged: _selectDate,
                        onOpenDate: _openDay,
                        showPeriodControls: false),
                    _ => YearView(
                        hiveService: widget.service,
                        initialDate: _date,
                        onDateChanged: _selectDate,
                        onOpenDate: _openDay,
                        showPeriodControls: false),
                  })),
        ])),
      );
}

class MoreView extends StatefulWidget {
  const MoreView({super.key, required this.service});
  final HiveService service;
  @override
  State<MoreView> createState() => _MoreViewState();
}

class _MoreViewState extends State<MoreView> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final groups =
        <String, List<(String, String, IconData, Widget Function())>>{
      'Plan and act': [
        (
          'Tasks',
          'Find, edit and organize all tasks',
          Icons.task_alt,
          () => TaskScreen(date: DateTime.now(), hiveService: service)
        ),
        (
          'Routines and streaks',
          'Build habits with a daily checklist',
          Icons.repeat,
          () => StreakView(hiveService: service)
        ),
        (
          'Instructions',
          'Manage rules and task checklists',
          Icons.rule,
          () => InstructionDashboardView(hiveService: service)
        ),
        (
          'Add by voice',
          'Capture tasks using your microphone',
          Icons.mic_outlined,
          () => VoiceTasksScreen(hiveService: service)
        ),
      ],
      'Reflect': [
        (
          'Journal',
          'Write and revisit daily reflections',
          Icons.edit_note,
          () => JournalView(hiveService: service)
        ),
        (
          'Journey',
          'Remember milestones and meaningful moments',
          Icons.timeline,
          () => JourneyTimelineView(hiveService: service)
        ),
        (
          'Motivation',
          'Quotes and optional reminders',
          Icons.lightbulb_outline,
          () => MotivationMottoDashboardView(hiveService: service)
        ),
      ],
      'Rewards': [
        (
          'Log & Earn',
          'Review completed tasks and earned rewards',
          Icons.checklist,
          () => LogEarnView(hiveService: service)
        ),
        (
          'Reward goals',
          'Plan what you are saving towards',
          Icons.flag_outlined,
          () => GoalDashboardView(hiveService: service)
        ),
        (
          'Reward budget',
          'Track reward money and spending',
          Icons.account_balance_wallet_outlined,
          () => RewardMoneyHistoryView(hiveService: service)
        ),
      ],
      'Preferences': [
        (
          'Settings',
          'Appearance, text size, start screen and reminders',
          Icons.settings_outlined,
          () => SettingsView(service: service)
        ),
      ],
    };
    final query = _search.text.trim().toLowerCase();
    final filtered = groups.map((group, items) => MapEntry(
        group,
        items
            .where((item) =>
                '$group ${item.$1} ${item.$2}'.toLowerCase().contains(query))
            .toList()))
      ..removeWhere((_, items) => items.isEmpty);
    final quickAccess = <(String, IconData, Widget Function())>[
      (
        'Tasks',
        Icons.task_alt,
        () => TaskScreen(date: DateTime.now(), hiveService: service)
      ),
      ('Journal', Icons.edit_note, () => JournalView(hiveService: service)),
      (
        'Add by voice',
        Icons.mic_outlined,
        () => VoiceTasksScreen(hiveService: service)
      ),
      (
        'Settings',
        Icons.settings_outlined,
        () => SettingsView(service: service)
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('More'), actions: [
        IconButton(
            tooltip: 'Open Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openPage(context, SettingsView(service: service))),
      ]),
      body: ListView(key: const PageStorageKey('more-features'), children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: 'Find a feature',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear feature search',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear))),
            )),
        if (query.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Quick access',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final item in quickAccess)
                      ActionChip(
                        avatar: Icon(item.$2, size: 18),
                        label: Text(item.$1),
                        onPressed: () => openPage(context, item.$3()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (filtered.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'No matching features. Try tasks, journal, rewards or settings.')),
        for (final group in filtered.entries) ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Semantics(
                  header: true,
                  child: Text(group.key,
                      style: Theme.of(context).textTheme.titleMedium))),
          for (final item in group.value)
            ListTile(
                minVerticalPadding: 12,
                leading: Icon(item.$3),
                title: Text(item.$1),
                subtitle: Text(item.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openPage(context, item.$4())),
          const Divider(indent: 16, endIndent: 16),
        ],
      ]),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.service});
  final HiveService service;
  Future<void> _save(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save settings. Please retry.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder(
          valueListenable: service.getBoxListenable(),
          builder: (context, _, __) =>
              ListView(padding: const EdgeInsets.all(16), children: [
                SwitchListTile(
                    title: const Text('Use system appearance'),
                    value: service.getFollowSystemTheme(),
                    onChanged: (value) => _save(
                        context, () => service.setFollowSystemTheme(value))),
                if (!service.getFollowSystemTheme())
                  DropdownButtonFormField<DashboardThemeType>(
                      isExpanded: true,
                      initialValue: service.getDashboardTheme(),
                      decoration:
                          const InputDecoration(labelText: 'Appearance'),
                      items: DashboardThemeType.values
                          .map((theme) => DropdownMenuItem(
                              value: theme, child: Text(theme.label)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null)
                          _save(
                              context, () => service.setDashboardTheme(value));
                      }),
                const SizedBox(height: 20),
                DropdownButtonFormField<DashboardPaletteType>(
                    isExpanded: true,
                    initialValue: service.getDashboardPalette(),
                    decoration:
                        const InputDecoration(labelText: 'Accent palette'),
                    items: DashboardPaletteType.values
                        .map((palette) => DropdownMenuItem(
                            value: palette,
                            child: Text(palette.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        _save(
                            context, () => service.setDashboardPalette(value));
                    }),
                const SizedBox(height: 20),
                DropdownButtonFormField<AppFontScale>(
                    isExpanded: true,
                    initialValue: service.getAppFontScale(),
                    decoration: const InputDecoration(labelText: 'Text size'),
                    items: AppFontScale.values
                        .map((scale) => DropdownMenuItem(
                            value: scale, child: Text(scale.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        _save(context, () => service.setAppFontScale(value));
                    }),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: service.getStartScreen(),
                    decoration:
                        const InputDecoration(labelText: 'Open the app on'),
                    items: [
                      for (var i = 0; i < 4; i++)
                        DropdownMenuItem(
                            value: i,
                            child:
                                Text(['Today', 'Plan', 'Progress', 'More'][i]))
                    ],
                    onChanged: (value) {
                      if (value != null)
                        _save(context, () => service.setStartScreen(value));
                    }),
                const SizedBox(height: 24),
                ListTile(
                    title: const Text('Motivation and reminders'),
                    subtitle:
                        const Text('Optional reminders, frequency and quotes'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openPage(context,
                        MotivationMottoDashboardView(hiveService: service))),
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'System text scaling and reduced-motion preferences are respected. Rewards are personal tracking, not a payout service.')),
              ])));
}
