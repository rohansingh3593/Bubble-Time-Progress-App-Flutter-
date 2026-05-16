import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/journey_entry.dart';
import '../models/task_model.dart';
import '../services/hive_service.dart';

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
          final entries = hiveService.getAllJourneyEntries();
          final allTasks = hiveService.getAllTasksByDate().values.expand((tasks) => tasks).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              _JourneyHero(onAdd: () => _showEntryDialog(context, allTasks)),
              const SizedBox(height: 14),
              if (entries.isEmpty)
                const _EmptyJourneyState()
              else
                ...entries.map(
                  (entry) => _JourneyEntryCard(
                    entry: entry,
                    onDelete: () => hiveService.deleteJourneyEntry(entry.id),
                  ),
                ),
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

class _JourneyHero extends StatelessWidget {
  final VoidCallback onAdd;

  const _JourneyHero({required this.onAdd});

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
          const Row(
            children: [
              Icon(Icons.auto_stories, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
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
      case 'Milestone':
        return Icons.flag;
      default:
        return Icons.edit_note;
    }
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
              decoration: InputDecoration(
                labelText: 'Related habit/task',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                const DropdownMenuItem<Task?>(value: null, child: Text('No related task')),
                ...taskOptions.map(
                  (task) => DropdownMenuItem<Task?>(
                    value: task,
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(task.colorValue), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(task.task, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
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
