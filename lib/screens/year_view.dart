import 'package:flutter/material.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../utils/grid_utils.dart';
import '../services/hive_service.dart';
import '../constants/colors.dart';
import 'task_screen.dart';

class YearView extends StatefulWidget {
  final HiveService hiveService;

  const YearView({super.key, required this.hiveService});

  @override
  State<YearView> createState() => _YearViewState();
}

class _YearViewState extends State<YearView> {
  late DateTime _currentYear;

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now();
  }

  void _showTaskScreen(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: TaskScreen(
            date: date,
            hiveService: widget.hiveService,
          ),
        ),
      ),
    );
  }

  Color _getBubbleColor(DateTime date, Map<String, int> summary, DateTime today) {
    final isPassed = date.isBefore(today);
    if (isPassed) {
      return AppColors.passed;
    }

    if (summary['completed']! > 0 && summary['pending']! == 0) {
      return AppColors.taskCompleted;
    } else if (summary['pending']! > 0) {
      return AppColors.taskPending;
    } else {
      return AppColors.taskNone;
    }
  }


  Map<String, int> _getSummaryByRepeatType(DateTime date, String repeatFrequency) {
    final tasks = widget.hiveService.getTasksForDate(date).where((task) {
      return !task.repeatTask || task.repeatFrequency == repeatFrequency;
    }).toList();

    final completed = tasks.where((task) => task.status == 'Completed').length;
    return {
      'completed': completed,
      'pending': tasks.length - completed,
    };
  }


  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentYear = _currentYear.year == now.year;
    final daysInYear = DateTime(_currentYear.year + 1, 1, 1)
        .difference(DateTime(_currentYear.year, 1, 1))
        .inDays;
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentYear.year} Progress'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Prev Year'),
                    onPressed: () {
                      setState(() {
                        _currentYear = DateTime(_currentYear.year - 1);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('Next Year'),
                    onPressed: () {
                      setState(() {
                        _currentYear = DateTime(_currentYear.year + 1);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final gridDims = calculateGridDimensions(
                daysInYear,
                constraints.maxWidth,
                constraints.maxHeight,
                viewType: 'year',
              );

              return GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridDims['columns'],
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4.0,
                  mainAxisSpacing: 4.0,
                ),
                itemCount: daysInYear,
                itemBuilder: (context, index) {
                  final date = DateTime(_currentYear.year, 1, index + 1);
                  final summary = _getSummaryByRepeatType(date, 'Yearly');
                  final isToday = isCurrentYear && date.day == now.day && date.month == now.month;

                  return BubbleWidget(
                    color: _getBubbleColor(date, summary, todayStart),
                    isHighlighted: isToday,
                    onTap: () => _showTaskScreen(date),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: isCurrentYear
          ? FloatingActionButton(
              onPressed: () async {
                await showQuickAddTaskDialog(context, todayStart, widget.hiveService);
              },
              tooltip: 'Add task for today',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}