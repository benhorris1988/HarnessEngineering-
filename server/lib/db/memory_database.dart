import 'package:uuid/uuid.dart';

import 'database.dart';

/// Zero-dependency in-memory store used when `HARNESS_DB=memory`.
/// Intended for demos and tests; does not parse arbitrary SQL — it
/// understands only the small dialect this app actually issues.
class MemoryDatabase implements Database {
  final List<Map<String, Object?>> _workItems = [];
  final List<Map<String, Object?>> _comments = [];
  final List<Map<String, Object?>> _runs = [];
  final List<Map<String, Object?>> _steps = [];
  final List<Map<String, Object?>> _messages = [];
  final List<Map<String, Object?>> _toolCalls = [];

  final Uuid _uuid = const Uuid();

  @override
  Future<void> connect() async {}

  @override
  Future<void> close() async {}

  DateTime _now() => DateTime.now().toUtc();

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) async {
    final lower = sql.toLowerCase();
    if (lower.contains('insert into dbo.work_items')) {
      _workItems.add(_workItemRow(params));
      return 1;
    }
    if (lower.contains('update dbo.work_items')) {
      final id = params.last as String;
      final row = _workItems.firstWhere((r) => r['id'] == id);
      row['state'] = params[0];
      row['updated_at'] = _now();
      return 1;
    }
    if (lower.contains('insert into dbo.work_item_comments')) {
      _comments.add({
        'id': _uuid.v4(),
        'work_item_id': params[0],
        'author': params[1],
        'body': params[2],
        'created_at': _now(),
      });
      return 1;
    }
    if (lower.contains('insert into dbo.agent_runs')) {
      _runs.add({
        'id': params[0],
        'work_item_id': params[1],
        'model': params[2],
        'status': 'pending',
        'summary': null,
        'started_at': _now(),
        'finished_at': null,
        'max_steps': params[3],
        'error': null,
      });
      return 1;
    }
    if (lower.contains('update dbo.agent_runs set status')) {
      final id = params.last as String;
      final row = _runs.firstWhere((r) => r['id'] == id);
      row['status'] = params[0];
      row['error'] = params[1];
      final s = params[0] as String;
      if (s == 'done' || s == 'failed' || s == 'blocked') {
        row['finished_at'] = _now();
      }
      return 1;
    }
    if (lower.contains('update dbo.agent_runs set summary')) {
      final id = params.last as String;
      final row = _runs.firstWhere((r) => r['id'] == id);
      row['summary'] = params[0];
      return 1;
    }
    if (lower.contains('insert into dbo.plan_steps')) {
      _steps.add({
        'id': params[0],
        'run_id': params[1],
        'ordinal': params[2],
        'title': params[3],
        'rationale': params[4],
        'status': 'pending',
        'result': null,
        'started_at': null,
        'finished_at': null,
      });
      return 1;
    }
    if (lower.contains('update dbo.plan_steps')) {
      final id = params.last as String;
      final row = _steps.firstWhere((r) => r['id'] == id);
      // Parameters were assembled in order: status?, result?, then timestamps
      // are SQL constants in our query — we approximate them here.
      var pi = 0;
      if (lower.contains('status = ?')) row['status'] = params[pi++];
      if (lower.contains('result = ?')) row['result'] = params[pi++];
      if (lower.contains('started_at = sysutcdatetime()')) {
        row['started_at'] = _now();
      }
      if (lower.contains('finished_at = sysutcdatetime()')) {
        row['finished_at'] = _now();
      }
      return 1;
    }
    if (lower.contains('insert into dbo.agent_messages')) {
      _messages.add({
        'id': params[0],
        'run_id': params[1],
        'step_id': params[2],
        'role': params[3],
        'content': params[4],
        'tool_name': params[5],
        'created_at': _now(),
      });
      return 1;
    }
    if (lower.contains('insert into dbo.tool_calls')) {
      _toolCalls.add({
        'id': params[0],
        'run_id': params[1],
        'step_id': params[2],
        'tool_name': params[3],
        'arguments': params[4],
        'result': params[5],
        'success': params[6],
        'started_at': _now(),
        'finished_at': _now(),
      });
      return 1;
    }
    throw UnimplementedError('MemoryDatabase.execute: $sql');
  }

  Map<String, Object?> _workItemRow(List<Object?> params) {
    final now = _now();
    return {
      'id': params[0],
      'type': params[1],
      'title': params[2],
      'description': params[3],
      'repro_steps': params[4],
      'system_info': params[5],
      'severity': params[6],
      'priority': params[7],
      'state': 'New',
      'area_path': params[8],
      'iteration_path': params[9],
      'tags': params[10],
      'assigned_to': null,
      'created_by': params[11],
      'created_at': now,
      'updated_at': now,
    };
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final lower = sql.toLowerCase();
    if (lower.contains('from dbo.work_items where id = ?')) {
      return _workItems.where((r) => r['id'] == params[0]).toList();
    }
    if (lower.contains('from dbo.work_items')) {
      var list = List<Map<String, Object?>>.from(_workItems);
      if (lower.contains('where state = ?')) {
        list = list.where((r) => r['state'] == params[0]).toList();
      }
      list.sort((a, b) =>
          (b['created_at'] as DateTime).compareTo(a['created_at'] as DateTime));
      return list;
    }
    if (lower.contains('from dbo.work_item_comments')) {
      final list = _comments
          .where((r) => r['work_item_id'] == params[0])
          .toList()
        ..sort((a, b) => (a['created_at'] as DateTime)
            .compareTo(b['created_at'] as DateTime));
      return list;
    }
    if (lower.contains('from dbo.agent_runs where id = ?')) {
      return _runs.where((r) => r['id'] == params[0]).toList();
    }
    if (lower.contains('from dbo.agent_runs')) {
      final list = _runs
          .where((r) => r['work_item_id'] == params[0])
          .toList()
        ..sort((a, b) => (b['started_at'] as DateTime)
            .compareTo(a['started_at'] as DateTime));
      return list;
    }
    if (lower.contains('from dbo.plan_steps where id = ?')) {
      return _steps.where((r) => r['id'] == params[0]).toList();
    }
    if (lower.contains('from dbo.plan_steps')) {
      final list = _steps.where((r) => r['run_id'] == params[0]).toList()
        ..sort((a, b) =>
            (a['ordinal'] as num).compareTo(b['ordinal'] as num));
      return list;
    }
    if (lower.contains('from dbo.agent_messages')) {
      final list = _messages
          .where((r) => r['run_id'] == params[0])
          .toList()
        ..sort((a, b) => (a['created_at'] as DateTime)
            .compareTo(b['created_at'] as DateTime));
      return list;
    }
    throw UnimplementedError('MemoryDatabase.query: $sql');
  }

  @override
  Future<Map<String, Object?>?> queryOne(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final rows = await query(sql, params);
    return rows.isEmpty ? null : rows.first;
  }
}
