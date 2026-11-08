import 'package:flutter/material.dart';

import '../models/productivity_snapshot.dart';
import '../models/reward_money.dart';
import '../services/hive_service.dart';

class RewardMoneyHistoryView extends StatefulWidget {
  final HiveService hiveService;

  RewardMoneyHistoryView({super.key, required this.hiveService});

  @override
  State<RewardMoneyHistoryView> createState() => _RewardMoneyHistoryViewState();
}

class _RewardMoneyHistoryViewState extends State<RewardMoneyHistoryView> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text('Reward Money History',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final summary = widget.hiveService.getRewardMoneySummary();
          final events = _filteredEvents(_buildRewardEvents(summary));
          final recentEvents = events.take(3).toList();
          final earlierEvents = events.skip(recentEvents.length);
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 96),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available balance',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRupees(summary.availableRupees),
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Personal tracking only. Recording spending does not transfer money or provide a payout.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showWithdrawDialog,
                  icon: Icon(Icons.payments_outlined),
                  label: Text('Record spending'),
                ),
              ),
              SizedBox(height: 12),
              _filterChips(),
              SizedBox(height: 8),
              Text('Recent activity',
                  style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 8),
              if (recentEvents.isEmpty)
                _EmptyRewardHistory()
              else
                ...recentEvents
                    .map((event) => _RewardHistoryTile(event: event)),
              SizedBox(height: 16),
              _SummaryCards(summary: summary, includeAvailable: false),
              if (earlierEvents.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Earlier activity',
                    style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 8),
                ...earlierEvents
                    .map((event) => _RewardHistoryTile(event: event)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _filterChips() {
    const filters = ['All', 'Earned', 'Spending', 'Goal Added'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final selected = _filter == filter;
        return ChoiceChip(
          selected: selected,
          label: Text(filter),
          onSelected: (_) => setState(() => _filter = filter),
          selectedColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.18),
          labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface),
        );
      }).toList(),
    );
  }

  List<_RewardHistoryEvent> _filteredEvents(List<_RewardHistoryEvent> events) {
    if (_filter == 'All') return events;
    return events.where((event) => event.filter == _filter).toList();
  }

  List<_RewardHistoryEvent> _buildRewardEvents(RewardMoneySummary summary) {
    final events = <_RewardHistoryEvent>[];
    final colors = Theme.of(context).colorScheme;
    final snapshots = widget.hiveService.getProductivitySnapshots();
    for (final snapshot in snapshots) {
      final earnedRupees = snapshot.totalPoints ~/ rewardPointsPerRupee;
      if (earnedRupees <= 0) continue;
      events.add(_RewardHistoryEvent.earned(
        snapshot: snapshot,
        earnedRupees: earnedRupees,
        color: colors.primary,
      ));
    }

    for (final entry in summary.ledger) {
      if (entry.type == RewardLedgerEntry.typeGoalFunding) {
        events.add(_RewardHistoryEvent.goalFunding(entry, colors.tertiary));
      } else {
        events.add(_RewardHistoryEvent.withdrawal(entry, colors.error));
      }
    }

    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  Future<void> _showWithdrawDialog() async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    var date = DateUtils.dateOnly(DateTime.now());
    var saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
            builder: (dialog, update) => AlertDialog(
                  title: Text('Record spending'),
                  content: Form(
                      key: form,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            'Personal tracking only. Recording spending does not transfer money or provide a payout.'),
                        SizedBox(height: 16),
                        TextFormField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            decoration:
                                InputDecoration(labelText: 'Amount (INR)'),
                            validator: (value) {
                              final parsed = int.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed <= 0)
                                return 'Enter a whole amount greater than zero';
                              if (parsed >
                                  widget.hiveService
                                      .getRewardMoneySummary()
                                      .availableRupees)
                                return 'Amount exceeds your available reward budget';
                              return null;
                            }),
                        SizedBox(height: 12),
                        TextFormField(
                            controller: reason,
                            decoration: InputDecoration(labelText: 'Reason')),
                        ListTile(
                            title: Text(MaterialLocalizations.of(dialog)
                                .formatMediumDate(date)),
                            trailing: Icon(Icons.calendar_today),
                            onTap: saving
                                ? null
                                : () async {
                                    final picked = await showDatePicker(
                                        context: dialog,
                                        initialDate: date,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime.now());
                                    if (picked != null && dialog.mounted)
                                      update(() => date = picked);
                                  }),
                        if (error != null)
                          Text(error!,
                              style: TextStyle(
                                  color: Theme.of(dialog).colorScheme.error)),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(dialog),
                        child: Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                update(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  await widget.hiveService.withdrawRewardMoney(
                                      amountRupees:
                                          int.parse(amount.text.trim()),
                                      reason: reason.text.trim(),
                                      goalName: '',
                                      note: '',
                                      date: date);
                                  if (dialog.mounted) Navigator.pop(dialog);
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Spending recorded')));
                                } catch (_) {
                                  if (dialog.mounted)
                                    update(() {
                                      saving = false;
                                      error = 'Could not save. Please retry.';
                                    });
                                }
                              },
                        child: Text(saving ? 'Saving...' : 'Save spending'))
                  ],
                )));
    await Future<void>.delayed(Duration(milliseconds: 350));
    amount.dispose();
    reason.dispose();
  }
}

class _SummaryCards extends StatelessWidget {
  final RewardMoneySummary summary;
  final bool includeAvailable;

  _SummaryCards({required this.summary, this.includeAvailable = true});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (includeAvailable)
          _SummaryCard(
              label: 'Available Balance',
              value: _formatRupees(summary.availableRupees),
              color: Theme.of(context).colorScheme.primary),
        _SummaryCard(
            label: 'Total Points', value: _formatInt(summary.totalPoints)),
        _SummaryCard(
            label: 'Earned (personal tracking)',
            value: _formatRupees(summary.earnedRupees),
            color: Theme.of(context).colorScheme.primary),
        _SummaryCard(
            label: 'Recorded spending',
            value: _formatRupees(summary.withdrawnRupees),
            color: Theme.of(context).colorScheme.error),
        _SummaryCard(
            label: 'Goal Saved',
            value: _formatRupees(summary.goalFundedRupees),
            color: Theme.of(context).colorScheme.tertiary),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  _SummaryCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color ?? Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}

class _RewardHistoryTile extends StatelessWidget {
  final _RewardHistoryEvent event;

  _RewardHistoryTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isPositive = event.amountRupees > 0;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: event.color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: event.color.withOpacity(0.12),
            child: Icon(event.icon, color: event.color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDate(event.date),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                SizedBox(height: 4),
                Text(event.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: 3),
                Text(event.subtitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${isPositive ? '+' : '-'} ${_formatRupees(event.amountRupees.abs())}',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: event.color),
          ),
        ],
      ),
    );
  }
}

class _EmptyRewardHistory extends StatelessWidget {
  _EmptyRewardHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.86),
          borderRadius: BorderRadius.circular(22)),
      child: Text('No reward money activity for this filter yet.',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _RewardHistoryEvent {
  final DateTime date;
  final String filter;
  final int amountRupees;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _RewardHistoryEvent({
    required this.date,
    required this.filter,
    required this.amountRupees,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  factory _RewardHistoryEvent.earned(
      {required ProductivitySnapshot snapshot,
      required int earnedRupees,
      required Color color}) {
    return _RewardHistoryEvent(
      date: snapshot.date,
      filter: 'Earned',
      amountRupees: earnedRupees,
      title: 'Earned from daily productivity points',
      subtitle:
          'Reason: Daily productivity points • Points: ${_formatInt(snapshot.totalPoints)}',
      icon: Icons.add_card_outlined,
      color: color,
    );
  }

  factory _RewardHistoryEvent.withdrawal(RewardLedgerEntry entry, Color color) {
    return _RewardHistoryEvent(
      date: entry.date,
      filter: 'Spending',
      amountRupees: -entry.amountRupees,
      title: 'Spending recorded',
      subtitle:
          'Reason: ${entry.reason}${entry.goalName.isEmpty ? '' : ' • Goal: ${entry.goalName}'} • Balance Left: ${_formatRupees(entry.balanceAfter)}',
      icon: Icons.receipt_long_outlined,
      color: color,
    );
  }

  factory _RewardHistoryEvent.goalFunding(
      RewardLedgerEntry entry, Color color) {
    return _RewardHistoryEvent(
      date: entry.date,
      filter: 'Goal Added',
      amountRupees: -entry.amountRupees,
      title: 'Added to Goal',
      subtitle:
          'Goal: ${entry.goalName} • Balance Left: ${_formatRupees(entry.balanceAfter)}${entry.note.isEmpty ? '' : ' • ${entry.note}'}',
      icon: Icons.flag_outlined,
      color: color,
    );
  }
}

String _formatRupees(int value) => '₹${_formatInt(value)}';

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _formatIsoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime date) {
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
    'Dec'
  ];
  return '${date.day} ${months[(date.month - 1).clamp(0, 11).toInt()]} ${date.year}';
}
