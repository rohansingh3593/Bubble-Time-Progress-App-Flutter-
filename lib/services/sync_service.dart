import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

class SyncService {
  SyncService({
    this.websocketUrl = 'wss://api.momentum.com/ws',
    this.userId = 'dev-user',
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient(userId: userId);

  final String websocketUrl;
  final String userId;
  final ApiClient _apiClient;
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>>? get events => _channel?.stream.map(
        (message) => jsonDecode(message as String) as Map<String, dynamic>,
      );

  void connect(
      {void Function(String event, Map<String, dynamic> data)? onEvent}) {
    final channel = WebSocketChannel.connect(_websocketUri());
    _channel = channel;

    channel.stream.listen((message) {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
      final event = decoded['event'] as String? ?? '';
      final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};

      onEvent?.call(event, data);
    });
  }

  Future<void> updateTaskTime({
    required String taskId,
    required String title,
    required String startTime,
    required String endTime,
  }) async {
    await _apiClient.updateTaskTime(
      taskId: taskId,
      title: title,
      startTime: startTime,
      endTime: endTime,
    );
  }

  Future<void> completeTask(String taskId) async {
    await _apiClient.completeTask(taskId);
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
    _apiClient.close();
  }

  Uri _websocketUri() {
    final uri = Uri.parse(websocketUrl);
    if (uri.queryParameters.containsKey('user_id')) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'user_id': userId,
    });
  }
}
