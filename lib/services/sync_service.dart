import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class SyncService {
  SyncService({this.websocketUrl = 'ws://192.168.1.10:8000/ws'});

  final String websocketUrl;
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>>? get events => _channel?.stream.map(
        (message) => jsonDecode(message as String) as Map<String, dynamic>,
      );

  void connect({void Function(String event, Map<String, dynamic> data)? onEvent}) {
    final channel = WebSocketChannel.connect(Uri.parse(websocketUrl));
    _channel = channel;

    channel.stream.listen((message) {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
      final event = decoded['event'] as String? ?? '';
      final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};

      onEvent?.call(event, data);
    });
  }

  void updateTaskTime({
    required String taskId,
    required String title,
    required String startTime,
    required String endTime,
  }) {
    _send({
      'event': 'task_updated',
      'data': {
        'task_id': taskId,
        'title': title,
        'start_time': startTime,
        'end_time': endTime,
        'status': 'scheduled',
      },
    });
  }

  void completeTask(String taskId) {
    _send({
      'event': 'task_completed',
      'data': {
        'task_id': taskId,
        'status': 'completed',
        'done': true,
      },
    });
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) {
      throw StateError('SyncService.connect() must be called before sending events.');
    }

    channel.sink.add(jsonEncode(message));
  }
}
