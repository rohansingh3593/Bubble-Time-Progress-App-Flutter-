import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../models/productivity_snapshot.dart';
import '../models/reward_money.dart';
import '../services/hive_service.dart';

class RewardMoneyHistoryView extends StatefulWidget {
  final HiveService hiveService;

  const RewardMoneyHistoryView({super.key, required this.hiveService});

  @override
  State<RewardMoneyHistoryView> createState() => _RewardMoneyHistoryViewState();
}

class _RewardMoneyHistoryViewState extends State<RewardMoneyHistoryView> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Reward Money History', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showWithdrawDialog,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Withdraw / Use Money'),
      ),
      body: ValueListenableBuilder(
        valueListenable: widget.hiveService.getBoxListenable(),
        builder: (context, box, child) {
          final summary = widget.hiveService.getRewardMoneySummary();
          final events = _filteredEvents(_buildRewardEvents(summary));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
            children: [
              _SummaryCards(summary: summary),
              const SizedBox(height: 16),
              _filterChips(),
              const SizedBox(height: 12),
              if (events.isEmpty)
                const _EmptyRewardHistory()
              else
                ...events.map((event) => _RewardHistoryTile(event: event)),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChips() {
    const filters = ['All', 'Earned', 'Withdrawn', 'Goal Added'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final selected = _filter == filter;
        return ChoiceChip(
          selected: selected,
          label: Text(filter),
          onSelected: (_) => setState(() => _filter = filter),
          selectedColor: AppColors.primary.withOpacity(0.18),
          labelStyle: TextStyle(fontWeight: FontWeight.w900, color: selected ? AppColors.primary : AppColors.textPrimary),
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
    final snapshots = widget.hiveService.getProductivitySnapshots();
    for (final snapshot in snapshots) {
      final earnedRupees = snapshot.totalPoints ~/ rewardPointsPerRupee;
      if (earnedRupees <= 0) continue;
      events.add(_RewardHistoryEvent.earned(snapshot: snapshot, earnedRupees: earnedRupees));
    }

    for (final entry in summary.ledger) {
      if (entry.type == RewardLedgerEntry.typeGoalFunding) {
        events.add(_RewardHistoryEvent.goalFunding(entry));
      } else {
        events.add(_RewardHistoryEvent.withdrawal(entry));
      }
    }

    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  Future<void> _showWithdrawDialog() async {
    final summary = widget.hiveService.getRewardMoneySummary();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final goalController = TextEditingController();
    final noteController = TextEditingController();
    final dateController = TextEditingController(text: _formatIsoDate(DateTime.now()));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw / Use Reward Money'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Balance: ${_formatRupees(summary.availableRupees)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
              TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
              TextField(controller: goalController, decoration: const InputDecoration(labelText: 'Goal Linked (Optional)')),
              TextField(controller: noteController, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
              TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save Withdrawal')),
        ],
      ),
    );
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final reason = reasonController.text.trim();
    final goalName = goalController.text.trim();
    final note = noteController.text.trim();
    final date = DateTime.tryParse(dateController.text.trim()) ?? DateTime.now();
    amountController.dispose();
    reasonController.dispose();
    goalController.dispose();
    noteController.dispose();
    dateController.dispose();
    if (saved != true) return;
    try {
      await widget.hiveService.withdrawRewardMoney(
        amountRupees: amount,
        reason: reason,
        goalName: goalName,
        note: note,
        date: date,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reward withdrawal saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _SummaryCards extends StatelessWidget {
  final RewardMoneySummary summary;

  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryCard(label: 'Total Points', value: _formatInt(summary.totalPoints)),
        _SummaryCard(label: 'Total Earned', value: _formatRupees(summary.earnedRupees), color: Colors.green.shade700),
        _SummaryCard(label: 'Available Balance', value: _formatRupees(summary.availableRupees), color: AppColors.primary),
        _SummaryCard(label: 'Total Withdrawn', value: _formatRupees(summary.withdrawnRupees), color: Colors.deepOrange.shade700),
        _SummaryCard(label: 'Goal Saved', value: _formatRupees(summary.goalFundedRupees), color: Colors.blue.shade700),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.14)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _RewardHistoryTile extends StatelessWidget {
  final _RewardHistoryEvent event;

  const _RewardHistoryTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isPositive = event.amountRupees > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: event.color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: event.color.withOpacity(0.12),
            child: Icon(event.icon, color: event.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDate(event.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black45)),
                const SizedBox(height: 4),
                Text(event.title, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(event.subtitle, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isPositive ? '+' : '-'} ${_formatRupees(event.amountRupees.abs())}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: event.color),
          ),
        ],
      ),
    );
  }
}

class _EmptyRewardHistory extends StatelessWidget {
  const _EmptyRewardHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.86), borderRadius: BorderRadius.circular(22)),
      child: const Text('No reward money activity for this filter yet.', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
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

  const _RewardHistoryEvent({
    required this.date,
    required this.filter,
    required this.amountRupees,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  factory _RewardHistoryEvent.earned({required ProductivitySnapshot snapshot, required int earnedRupees}) {
    return _RewardHistoryEvent(
      date: snapshot.date,
      filter: 'Earned',
      amountRupees: earnedRupees,
      title: 'Earned from daily productivity points',
      subtitle: 'Reason: Daily productivity points • Points: ${_formatInt(snapshot.totalPoints)}',
      icon: Icons.add_card_outlined,
      color: Colors.green.shade700,
    );
  }

  factory _RewardHistoryEvent.withdrawal(RewardLedgerEntry entry) {
    return _RewardHistoryEvent(
      date: entry.date,
      filter: 'Withdrawn',
      amountRupees: -entry.amountRupees,
      title: 'Withdrawn / Used',
      subtitle: 'Reason: ${entry.reason}${entry.goalName.isEmpty ? '' : ' • Goal: ${entry.goalName}'} • Balance Left: ${_formatRupees(entry.balanceAfter)}',
      icon: Icons.receipt_long_outlined,
      color: Colors.deepOrange.shade700,
    );
  }

  factory _RewardHistoryEvent.goalFunding(RewardLedgerEntry entry) {
    return _RewardHistoryEvent(
      date: entry.date,
      filter: 'Goal Added',
      amountRupees: -entry.amountRupees,
      title: 'Added to Goal',
      subtitle: 'Goal: ${entry.goalName} • Balance Left: ${_formatRupees(entry.balanceAfter)}${entry.note.isEmpty ? '' : ' • ${entry.note}'}',
      icon: Icons.flag_outlined,
      color: Colors.blue.shade700,
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

String _formatIsoDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[(date.month - 1).clamp(0, 11).toInt()]} ${date.year}';
}
