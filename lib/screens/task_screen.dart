import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../models/task_model.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/task_row.dart';
import '../widgets/recoverable_delete.dart';
import 'voice_tasks_screen.dart';

class TaskScreen extends StatefulWidget {
  final DateTime date;
  final HiveService hiveService;
  final String initialFilter;
  const TaskScreen(
      {super.key,
      required this.date,
      required this.hiveService,
      this.initialFilter = 'Active'});
  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  String _filter = 'Active';
  String _query = '';
  final _search = TextEditingController();
  final _filterScrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  void dispose() {
    _search.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  Future<void> _edit(Task task) async {
    await showTaskFormDialog(context,
        date: task.dueDate,
        initialTask: task,
        title: task.repeatTask ? 'Edit routine' : 'Edit task',
        actionLabel: 'Save task',
        onSave: (updated) => widget.hiveService.saveTaskChanges(task, updated));
  }

  Future<void> _delete(Task task) => recoverableDelete(context,
      label: 'task',
      remove: () => widget.hiveService.deleteTaskByReference(task),
      restore: () => widget.hiveService.addTask(task.dueDate, task));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tasks'), actions: [
          IconButton(
              tooltip: 'Add by voice',
              icon: const Icon(Icons.mic),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      VoiceTasksScreen(hiveService: widget.hiveService))))
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showQuickAddTaskDialog(
                context, DateTime.now(), widget.hiveService),
            icon: const Icon(Icons.add),
            label: const Text('Add task')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                  controller: _search,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                      labelText: 'Search tasks',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear task search',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                    _search.clear();
                                    _query = '';
                                  }))))),
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'Task filters',
            hint: 'Scroll horizontally to see all filters',
            child: Scrollbar(
              controller: _filterScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _filterScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    'Active',
                    'Today',
                    'Overdue',
                    'Upcoming',
                    'All',
                    'Completed',
                    'Routines'
                  ]
                      .map((filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                              label: Text(filter),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter))))
                      .toList(),
                ),
              ),
            ),
          ),
          Expanded(
              child: ValueListenableBuilder(
                  valueListenable: widget.hiveService.getBoxListenable(),
                  builder: (context, _, __) {
                    final tasks = widget.hiveService
                        .getAllTasksByDate()
                        .values
                        .expand((tasks) => tasks)
                        .where((task) {
                      if (widget.hiveService.isDailyJournalTask(task))
                        return false;
                      if (!task.task.toLowerCase().contains(_query))
                        return false;
                      final complete = task.done || task.status == 'Completed';
                      final today = DateUtils.dateOnly(DateTime.now());
                      final due = DateUtils.dateOnly(task.dueDate);
                      final active = !complete &&
                          task.status != 'Cancelled' &&
                          (!task.repeatTask || task.routineEnabled);
                      return switch (_filter) {
                        'Today' => active && due == today,
                        'Overdue' =>
                          active && !task.repeatTask && due.isBefore(today),
                        'Upcoming' => active && due.isAfter(today),
                        'Active' => !complete &&
                            task.status != 'Cancelled' &&
                            (!task.repeatTask || task.routineEnabled),
                        'Completed' => complete,
                        'Routines' => task.repeatTask,
                        _ => true
                      };
                    }).toList()
                      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
                    if (tasks.isEmpty)
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                  'No matching tasks. Change the filter or add a task.')));
                    return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return TaskRow(
                              key: ValueKey(task.id),
                              task: task,
                              date: task.dueDate,
                              service: widget.hiveService,
                              onEdit: () => _edit(task),
                              onDelete:
                                  task.repeatTask ? null : () => _delete(task));
                        });
                  })),
        ]),
      );
}
