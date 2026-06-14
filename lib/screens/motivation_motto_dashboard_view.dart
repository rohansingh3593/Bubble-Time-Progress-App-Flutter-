import 'package:flutter/material.dart';

import '../constants/dashboard_themes.dart';
import '../models/motivation_motto.dart';
import '../services/hive_service.dart';

class MotivationMottoDashboardView extends StatefulWidget {
  final HiveService hiveService;
  const MotivationMottoDashboardView({super.key, required this.hiveService});

  @override
  State<MotivationMottoDashboardView> createState() => _MotivationMottoDashboardViewState();
}

class _MotivationMottoDashboardViewState extends State<MotivationMottoDashboardView> {
  static const categories = ['Focus', 'Discipline', 'Health', 'Study', 'Work', 'Confidence', 'No Smoking', 'Fitness', 'Spiritual', 'Custom'];
  static const frequencies = [0, 15, 30, 60, 120];

  DashboardThemeStyle get style => DashboardThemeStyle.of(widget.hiveService.getDashboardTheme(), palette: widget.hiveService.getDashboardPalette());

  String _frequencyLabel(int minutes) {
    if (minutes <= 0) return '30 sec';
    if (minutes == 60) return '1 hour';
    if (minutes == 120) return '2 hours';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: style.background,
      appBar: AppBar(title: const Text('Motivation Motto Dashboard')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMottoEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Motivation Motto'),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, _) {
          final mottos = widget.hiveService.getMotivationMottos();
          final featured = widget.hiveService.getFeaturedMotivationMotto();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _heroCard(featured),
              const SizedBox(height: 12),
              _settingsCard(),
              const SizedBox(height: 14),
              Text('Quote Cards', style: TextStyle(color: style.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (mottos.isEmpty)
                _emptyCard()
              else
                ...mottos.map(_mottoCard),
            ],
          );
        },
      ),
    );
  }

  Widget _heroCard(MotivationMotto? motto) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: style.primary.withOpacity(0.14), borderRadius: BorderRadius.circular(22), border: Border.all(color: style.primary.withOpacity(0.24))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today’s Motto:', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(motto == null ? 'Add your first motivation motto to pin it here.' : '“${motto.quote}”', style: TextStyle(color: style.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
          if (motto != null && motto.author.isNotEmpty) ...[const SizedBox(height: 6), Text('— ${motto.author}', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700))],
        ]),
      );

  Widget _settingsCard() {
    final settings = widget.hiveService.getMottoReminderSettings();
    final selectedFrequency = frequencies.contains(settings.frequencyMinutes) ? settings.frequencyMinutes : 15;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reminder Settings', style: TextStyle(color: style.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          SwitchListTile(
            value: settings.popupEnabled,
            contentPadding: EdgeInsets.zero,
            title: const Text('Popup Reminder'),
            subtitle: const Text('Show motivation popups while using the app.'),
            onChanged: (value) => widget.hiveService.saveMottoReminderSettings(MottoReminderSettings(popupEnabled: value, frequencyMinutes: settings.frequencyMinutes, activeOnly: settings.activeOnly)),
          ),
          DropdownButtonFormField<int>(
            value: selectedFrequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: frequencies.map((m) => DropdownMenuItem(value: m, child: Text(_frequencyLabel(m)))).toList(),
            onChanged: (value) {
              if (value != null) widget.hiveService.saveMottoReminderSettings(MottoReminderSettings(popupEnabled: settings.popupEnabled, frequencyMinutes: value, activeOnly: settings.activeOnly));
            },
          ),
          SwitchListTile(
            value: settings.activeOnly,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show only while app is active'),
            onChanged: (value) => widget.hiveService.saveMottoReminderSettings(MottoReminderSettings(popupEnabled: settings.popupEnabled, frequencyMinutes: settings.frequencyMinutes, activeOnly: value)),
          ),
        ]),
      ),
    );
  }

  Widget _emptyCard() => Card(child: Padding(padding: const EdgeInsets.all(18), child: Text('No mottos yet. Tap + Add Motivation Motto to save personal quotes offline.', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700))));

  Widget _mottoCard(MotivationMotto motto) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('“${motto.quote}”', style: TextStyle(color: style.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Category: ${motto.category} • Status: ${motto.enabled ? 'Active' : 'Disabled'}', style: TextStyle(color: style.textMuted, fontWeight: FontWeight.w700)),
            if (motto.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(motto.description)),
            Wrap(spacing: 8, children: [
              FilterChip(label: const Text('Favorite'), selected: motto.favorite, onSelected: (_) => widget.hiveService.setMotivationMottoFlag(motto.id, favorite: !motto.favorite)),
              FilterChip(label: const Text('Pinned'), selected: motto.pinned, onSelected: (_) => widget.hiveService.setMotivationMottoFlag(motto.id, pinned: !motto.pinned)),
              FilterChip(label: const Text('Today’s Motto'), selected: motto.todaysMotto, onSelected: (_) => widget.hiveService.setMotivationMottoFlag(motto.id, todaysMotto: !motto.todaysMotto)),
            ]),
            ButtonBar(children: [
              TextButton(onPressed: () => _showMottoEditor(motto: motto), child: const Text('Edit')),
              TextButton(onPressed: () => widget.hiveService.setMotivationMottoFlag(motto.id, enabled: !motto.enabled), child: Text(motto.enabled ? 'Disable' : 'Enable')),
              TextButton(onPressed: () => widget.hiveService.deleteMotivationMotto(motto.id), child: const Text('Delete')),
            ]),
          ]),
        ),
      );

  Future<void> _showMottoEditor({MotivationMotto? motto}) async {
    final quote = TextEditingController(text: motto?.quote ?? '');
    final description = TextEditingController(text: motto?.description ?? '');
    final mood = TextEditingController(text: motto?.mood ?? '');
    final author = TextEditingController(text: motto?.author ?? '');
    var category = categories.contains(motto?.category) ? motto!.category : 'Focus';
    var enabled = motto?.enabled ?? true;
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(motto == null ? 'Add Motivation Motto' : 'Edit Motivation Motto'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: quote, decoration: const InputDecoration(labelText: 'Quote / Motto *')),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Description optional')),
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'), items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setDialogState(() => category = v ?? category)),
        TextField(controller: mood, decoration: const InputDecoration(labelText: 'Mood')),
        TextField(controller: author, decoration: const InputDecoration(labelText: 'Author optional')),
        SwitchListTile(value: enabled, title: const Text('Enable'), onChanged: (v) => setDialogState(() => enabled = v)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () async {
        if (quote.text.trim().isEmpty) return;
        final saved = (motto ?? MotivationMotto.create(quote: quote.text.trim())).copyWith(quote: quote.text.trim(), description: description.text.trim(), category: category, mood: mood.text.trim(), author: author.text.trim(), enabled: enabled);
        await widget.hiveService.saveMotivationMotto(saved);
        if (mounted) Navigator.pop(context);
      }, child: const Text('Save'))],
    )));
  }
}
