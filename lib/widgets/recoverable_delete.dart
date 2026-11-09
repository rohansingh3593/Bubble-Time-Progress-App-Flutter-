import 'package:flutter/material.dart';

Future<bool> recoverableDelete(
  BuildContext context, {
  required String label,
  required Future<void> Function() remove,
  required Future<void> Function() restore,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
            title: Text('Delete $label?'),
            content: const Text(
                'You can undo this deletion using the message below.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Keep')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Delete'))
            ],
          ));
  if (confirmed != true || !context.mounted) return false;
  Future<void> tryRestore() async {
    try {
      await restore();
    } catch (_) {
      if (messenger.mounted)
        messenger.showSnackBar(SnackBar(
          content: const Text('Could not restore. Please retry.'),
          duration: const Duration(days: 1),
          action: SnackBarAction(label: 'Retry', onPressed: tryRestore),
        ));
    }
  }

  try {
    await remove();
    if (messenger.mounted)
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text('$label deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: tryRestore),
      ));
    return true;
  } catch (_) {
    if (messenger.mounted)
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not delete. Please retry.')));
    return false;
  }
}
