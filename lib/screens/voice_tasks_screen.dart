import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../models/voice_task_draft.dart';
import '../services/hive_service.dart';
import '../services/offline_voice_service.dart';
import '../services/voice_task_parser.dart';
import '../services/voice_task_service.dart';
import '../widgets/quick_add_task_dialog.dart';
import '../widgets/voice_listening_indicator.dart';

class VoiceTasksScreen extends StatefulWidget {
  final HiveService hiveService;
  final VoiceCapture? capture;
  final VoiceTaskService? taskService;
  const VoiceTasksScreen(
      {super.key, required this.hiveService, this.capture, this.taskService});

  @override
  State<VoiceTasksScreen> createState() => _VoiceTasksScreenState();
}

class _VoiceTasksScreenState extends State<VoiceTasksScreen>
    with WidgetsBindingObserver {
  final _transcript = TextEditingController();
  late final VoiceCapture _capture;
  late final VoiceTaskService _tasks;
  List<VoiceTaskDraft> _drafts = [];
  final _selected = <String, String>{};
  final _saved = <String>{};
  Timer? _limit;
  String _language = '';
  String _state = 'ready';
  String? _error;
  bool _saving = false;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _capture = widget.capture ?? OfflineVoiceService();
    _tasks = widget.taskService ?? VoiceTaskService(widget.hiveService);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_state == 'listening' || _state == 'preparing')) {
      _cancelRecording();
    }
  }

  Future<void> _cancelRecording() async {
    _epoch++;
    _limit?.cancel();
    var message = 'Recording cancelled. Tap the microphone when you are ready.';
    try {
      await _capture.cancel();
    } catch (error) {
      message = _message(error);
    }
    if (mounted) {
      setState(() {
        _state = 'ready';
        _error = message;
      });
    }
  }

  Future<void> _start() async {
    final epoch = ++_epoch;
    setState(() {
      _state = 'preparing';
      _error = null;
    });
    try {
      await _capture.start();
      if (!mounted || epoch != _epoch) return;
      setState(() => _state = 'listening');
      _limit =
          Timer(const Duration(seconds: OfflineVoiceService.maxSeconds), _stop);
    } catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _state = 'ready';
          _error = _message(error);
        });
      }
    }
  }

  Future<void> _stop() async {
    if (_state != 'listening') return;
    final epoch = _epoch;
    _limit?.cancel();
    setState(() => _state = 'transcribing');
    try {
      final text = await _capture.stopAndTranscribe(language: _language);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _state = 'ready';
        _drafts = [];
        _transcript.text = text;
        _error = text.trim().isEmpty
            ? 'No clear speech detected. Try again or type your command.'
            : null;
      });
      if (text.trim().isNotEmpty) {
        _analyse();
        if (_drafts.length == 1 &&
            _drafts.single.action == VoiceTaskAction.add) {
          await _review(_drafts.single);
        }
      }
    } catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _state = 'ready';
          _error = _message(error);
        });
      }
    }
  }

  void _analyse() {
    try {
      final drafts =
          VoiceTaskParser().parse(_transcript.text, now: DateTime.now());
      _selected.clear();
      for (final draft
          in drafts.where((draft) => draft.action != VoiceTaskAction.add)) {
        final matches = _tasks.matches(draft.target);
        if (matches.length == 1) _selected[draft.id] = matches.single.id;
      }
      setState(() {
        _drafts = drafts;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _drafts = [];
        _error = _message(error);
      });
    }
  }

  Future<void> _review(VoiceTaskDraft draft) async {
    if (_saving || _saved.contains(draft.id)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Task? source;
      if (draft.action != VoiceTaskAction.add) {
        final candidates = _tasks.tasks
            .where((task) => task.id == _selected[draft.id])
            .toList();
        if (candidates.length != 1) {
          throw StateError(
              'Select the exact task before reviewing this command.');
        }
        source = candidates.single;
      }
      final fingerprint = source == null ? null : _tasks.fingerprint(source);
      final preview =
          _tasks.preview(draft, source: source, now: DateTime.now());
      Task? reviewed;
      if (source?.repeatTask == true &&
          draft.action == VoiceTaskAction.complete) {
        final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Complete today’s occurrence?'),
                  content: Text(source!.task),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Confirm completion')),
                  ],
                ));
        if (confirm == true) reviewed = preview;
      } else {
        reviewed = await showTaskFormDialog(
          context,
          date: preview.dueDate,
          initialTask: preview,
          title: 'Review voice ${draft.action.name}',
          reviewNotes: draft.notes,
          actionLabel: draft.action == VoiceTaskAction.complete
              ? 'Confirm completion'
              : 'Save task',
        );
      }
      if (reviewed == null || !mounted) return;
      await _tasks.apply(draft, reviewed,
          source: source, expectedFingerprint: fingerprint);
      if (mounted) setState(() => _saved.add(draft.id));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _message(Object error) {
    if (error is FormatException) return error.message;
    if (error is StateError) return error.message;
    return 'Voice input could not finish. Check microphone access and the offline model, or type your command.';
  }

  @override
  void dispose() {
    _epoch++;
    _limit?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_capture.dispose().catchError((Object _) {}));
    _transcript.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _state == 'ready' && !_saving;
    return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('Offline voice tasks')),
          body: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('Say what you need to do',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                  'Hindi, English, or a mix. Audio stays on this device. Review every change before saving.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(
                    labelText: 'Speech language', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: '', child: Text('Hindi + English (automatic)')),
                  DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: ready
                    ? (value) => setState(() => _language = value ?? '')
                    : null,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: Icon(_state == 'listening' ? Icons.stop : Icons.mic),
                onPressed: _state == 'listening'
                    ? _stop
                    : ready
                        ? _start
                        : null,
                label: Text(switch (_state) {
                  'preparing' => 'Preparing offline voice…',
                  'transcribing' => 'Transcribing on this device…',
                  'listening' => 'Stop recording (maximum 30 seconds)',
                  _ => 'Record a command',
                }),
              ),
              if (_state == 'preparing' || _state == 'transcribing')
                const LinearProgressIndicator(),
              if (_state == 'listening')
                VoiceListeningIndicator(
                  level: _capture.level,
                  maxSeconds: OfflineVoiceService.maxSeconds,
                ),
              if (_state == 'listening')
                TextButton(
                    onPressed: _cancelRecording,
                    child: const Text('Cancel recording')),
              const SizedBox(height: 16),
              TextField(
                controller: _transcript,
                enabled: ready,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                    labelText: 'Transcript — edit or type here',
                    border: OutlineInputBorder()),
                onChanged: (_) {
                  if (_drafts.isNotEmpty) setState(() => _drafts = []);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                  'Examples: “Add study Python tomorrow at 6 pm for ten minutes.”\n'
                  '“कल शाम छह बजे Python पढ़ना दस मिनट के लिए जोड़ो।”\n'
                  '“Rename study Python to practise Python.”\n'
                  '“Edit practise Python for twenty five minutes.”\n'
                  '“Complete practise Python” or “Python पढ़ना पूरा कर दो।”\n'
                  'For steps: “Add launch project with steps plan, build, test.”\n'
                  'Use separate lines or semicolons for multiple commands.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: ready ? _analyse : null,
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Analyse command')),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!,
                        key: const ValueKey('voice_error'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              ..._drafts.map((draft) => _draftCard(draft, ready)),
            ]),
          )),
        ));
  }

  Widget _draftCard(VoiceTaskDraft draft, bool ready) {
    final saved = _saved.contains(draft.id);
    final tasks = _tasks.tasks;
    final date = draft.date?.toIso8601String().split('T').first;
    return Card(
      key: ValueKey(draft.id),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${draft.action.name.toUpperCase()}: ${draft.title.isEmpty ? draft.target : draft.title}',
                  style: Theme.of(context).textTheme.titleMedium),
              if (date != null) Text('Date: $date'),
              if (draft.hour != null)
                Text(
                    'Time: ${draft.hour.toString().padLeft(2, '0')}:${draft.minute.toString().padLeft(2, '0')}'),
              if (draft.minutes != null)
                Text('Spoken duration: ${draft.minutes} minutes'),
              for (final step in draft.steps) Text('• $step'),
              for (final note in draft.notes)
                Padding(
                    padding: const EdgeInsets.only(top: 6), child: Text(note)),
              if (draft.action != VoiceTaskAction.add) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('target-${draft.id}'),
                  isExpanded: true,
                  initialValue:
                      tasks.any((task) => task.id == _selected[draft.id])
                          ? _selected[draft.id]
                          : null,
                  decoration: const InputDecoration(
                      labelText: 'Confirm the task to change',
                      border: OutlineInputBorder()),
                  items: tasks
                      .map((task) => DropdownMenuItem(
                            value: task.id,
                            child: Text(
                                '${task.task} • ${task.dueDate.toIso8601String().split('T').first}${task.repeatTask ? ' • Routine' : ''}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: ready && !saved
                      ? (id) => setState(() {
                            if (id != null) _selected[draft.id] = id;
                          })
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: ready && !saved ? () => _review(draft) : null,
                icon: Icon(saved ? Icons.check : Icons.edit_note),
                label: Text(saved ? 'Saved' : 'Review and save'),
              ),
            ],
          )),
    );
  }
}
