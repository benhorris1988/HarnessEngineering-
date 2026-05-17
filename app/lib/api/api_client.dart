import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/agent_message.dart';
import 'models/agent_run.dart';
import 'models/plan_step.dart';
import 'models/work_item.dart';
import 'models/work_item_comment.dart';

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = Uri.parse(
          baseUrl ??
              const String.fromEnvironment(
                'API_BASE',
                defaultValue: 'http://localhost:8080',
              ),
        ),
        _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;

  Uri _u(String path, [Map<String, String>? q]) =>
      baseUrl.replace(path: path, queryParameters: q);

  Future<List<WorkItem>> listWorkItems({String? state}) async {
    final resp = await _client.get(_u(
      '/api/work-items',
      state == null ? null : {'state': state},
    ));
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .cast<Map<String, Object?>>()
        .map(WorkItem.fromJson)
        .toList(growable: false);
  }

  Future<WorkItem> getWorkItem(String id) async {
    final resp = await _client.get(_u('/api/work-items/$id'));
    _check(resp);
    return WorkItem.fromJson(jsonDecode(resp.body) as Map<String, Object?>);
  }

  Future<({WorkItem workItem, String? runId})> createWorkItem({
    required String type,
    required String title,
    String? description,
    String? reproSteps,
    String? systemInfo,
    String severity = '3 - Medium',
    int priority = 2,
    String areaPath = 'Harness',
    String iterationPath = 'Harness\\Current',
    String? tags,
    bool autorun = true,
  }) async {
    final resp = await _client.post(
      _u('/api/work-items'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'type': type,
        'title': title,
        'description': description,
        'reproSteps': reproSteps,
        'systemInfo': systemInfo,
        'severity': severity,
        'priority': priority,
        'areaPath': areaPath,
        'iterationPath': iterationPath,
        'tags': tags,
        'autorun': autorun,
      }),
    );
    _check(resp);
    final body = jsonDecode(resp.body) as Map<String, Object?>;
    return (
      workItem: WorkItem.fromJson(body['workItem']! as Map<String, Object?>),
      runId: body['runId'] as String?,
    );
  }

  Future<List<WorkItemComment>> listComments(String workItemId) async {
    final resp =
        await _client.get(_u('/api/work-items/$workItemId/comments'));
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .cast<Map<String, Object?>>()
        .map(WorkItemComment.fromJson)
        .toList(growable: false);
  }

  Future<String> kickoffRun(String workItemId) async {
    final resp = await _client.post(_u('/api/work-items/$workItemId/runs'));
    _check(resp);
    final body = jsonDecode(resp.body) as Map<String, Object?>;
    return body['runId']! as String;
  }

  Future<AgentRun> getRun(String runId) async {
    final resp = await _client.get(_u('/api/runs/$runId'));
    _check(resp);
    return AgentRun.fromJson(jsonDecode(resp.body) as Map<String, Object?>);
  }

  Future<List<PlanStep>> listSteps(String runId) async {
    final resp = await _client.get(_u('/api/runs/$runId/steps'));
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .cast<Map<String, Object?>>()
        .map(PlanStep.fromJson)
        .toList(growable: false);
  }

  Future<List<AgentMessage>> listMessages(String runId) async {
    final resp = await _client.get(_u('/api/runs/$runId/messages'));
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .cast<Map<String, Object?>>()
        .map(AgentMessage.fromJson)
        .toList(growable: false);
  }

  Future<List<AgentRun>> listRunsForWorkItem(String workItemId) async {
    final resp =
        await _client.get(_u('/api/runs/by-work-item/$workItemId'));
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .cast<Map<String, Object?>>()
        .map(AgentRun.fromJson)
        .toList(growable: false);
  }

  void _check(http.Response resp) {
    if (resp.statusCode >= 400) {
      debugPrint('API ${resp.request?.method} ${resp.request?.url} '
          '-> ${resp.statusCode} ${resp.body}');
      throw ApiException(resp.statusCode, resp.body);
    }
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'ApiException($statusCode): $body';
}
