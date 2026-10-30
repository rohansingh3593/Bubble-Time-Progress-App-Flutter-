import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task_model.dart';
import '../models/task_step.dart';

class ApiClient {
  ApiClient({
    this.baseUrl = 'https://api.momentum.com',
    this.userId = 'dev-user',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String userId;
  final http.Client _httpClient;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      };

  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/tasks'),
      headers: _headers,
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .cast<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> createTask(Task task) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/tasks'),
      headers: _headers,
      body: jsonEncode(taskToPayload(task)),
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateTask(Task task) async {
    final taskId = taskCloudId(task);
    final response = await _httpClient.put(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: _headers,
      body: jsonEncode(taskToPayload(task)..remove('task_id')),
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<void> deleteTask(Task task) async {
    final response = await _httpClient.delete(
      Uri.parse('$baseUrl/tasks/${taskCloudId(task)}'),
      headers: _headers,
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> updateTaskTime({
    required String taskId,
    required String title,
    required String startTime,
    required String endTime,
  }) async {
    final response = await _httpClient.put(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'start_time': startTime,
        'end_time': endTime,
        'status': 'scheduled',
      }),
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> completeTask(String taskId) async {
    final response = await _httpClient.put(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: _headers,
      body: jsonEncode({
        'status': 'completed',
        'done': true,
      }),
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  void close() {
    _httpClient.close();
  }

  static String taskCloudId(Task task) => task.legacyCloudId ?? task.id;

  static String legacyTaskCloudId(Task task) {
    final date = task.dueDate.toIso8601String().split('T').first;
    final title = _slug(task.task);
    final category = _slug(task.category);
    return '$date-$category-$title';
  }

  static Map<String, dynamic> taskToPayload(Task task) {
    final startTime = _timeFromDate(task.dueDate);
    final endTime = task.estimatedMinutes > 0
        ? _timeFromMinutes((task.dueDate.hour * 60) +
            task.dueDate.minute +
            task.estimatedMinutes)
        : null;

    return {
      'task_id': taskCloudId(task),
      'entity_id': task.id,
      'legacy_cloud_id': task.legacyCloudId,
      'title': task.task,
      'done': task.done,
      'description': task.description,
      'due_date': task.dueDate.toIso8601String(),
      'priority': task.priority,
      'status': task.status,
      'category': task.category,
      'delegated_to': task.delegatedTo,
      'repeat_task': task.repeatTask,
      'repeat_frequency': task.repeatFrequency,
      'urgent': task.urgent,
      'important': task.important,
      'estimated_minutes': task.estimatedMinutes,
      'hour_slot': task.hourSlot,
      'color_value': task.colorValue,
      'routine_enabled': task.routineEnabled,
      if (task.steps != null) 'steps': task.steps!.map((step) => step.toMap()).toList(),
      'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
    }..removeWhere((_, value) => value == null);
  }

  static Task taskFromPayload(Map<String, dynamic> payload) {
    final dueDateText = payload['due_date']?.toString();
    final dueDate = dueDateText == null
        ? DateTime.now()
        : DateTime.tryParse(dueDateText) ?? DateTime.now();
    final title = payload['title']?.toString();

    return Task(
      id: (payload['entity_id'] ?? payload['task_id'])?.toString(),
      legacyCloudId: payload['legacy_cloud_id']?.toString(),
      steps: (payload['steps'] as List?)
          ?.map((step) => TaskStep.fromMap((step as Map).cast<String, dynamic>()))
          .toList(),
      task:
          title == null || title.trim().isEmpty ? 'Synced Task' : title.trim(),
      done: payload['done'] == true,
      description: payload['description']?.toString() ?? '',
      dueDate: dueDate,
      priority: payload['priority']?.toString() ?? 'Medium',
      status: payload['status']?.toString() ?? 'Not Started',
      category: payload['category']?.toString() ?? 'Personal',
      delegatedTo: payload['delegated_to']?.toString(),
      repeatTask: payload['repeat_task'] == true,
      repeatFrequency: payload['repeat_frequency']?.toString(),
      urgent: payload['urgent'] == true,
      important: payload['important'] == true,
      estimatedMinutes: _intFromPayload(payload['estimated_minutes']),
      hourSlot: payload['hour_slot'] == null
          ? null
          : _intFromPayload(payload['hour_slot']),
      colorValue: _intFromPayload(payload['color_value'], fallback: 0xFF1E88E5),
      routineEnabled: payload['routine_enabled'] != false,
    );
  }

  static String _slug(String value) {
    final lower = value.trim().toLowerCase();
    final slug = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'task' : slug;
  }

  static String _timeFromDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static int _intFromPayload(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static String _timeFromMinutes(int minutes) {
    final normalized = minutes.clamp(0, 24 * 60 - 1).toInt();
    return '${(normalized ~/ 60).toString().padLeft(2, '0')}:${(normalized % 60).toString().padLeft(2, '0')}';
  }

  static void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}
