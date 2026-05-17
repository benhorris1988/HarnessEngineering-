import '../../models/agent_run.dart';
import '../database.dart';

class AgentRunsRepository {
  AgentRunsRepository(this._db);
  final Database _db;

  Future<AgentRun> create({
    required String id,
    required String workItemId,
    required String model,
    required int maxSteps,
  }) async {
    await _db.execute(
      '''
      INSERT INTO dbo.agent_runs (id, work_item_id, model, status, max_steps)
      VALUES (?, ?, ?, 'pending', ?)
      ''',
      [id, workItemId, model, maxSteps],
    );
    return (await get(id))!;
  }

  Future<AgentRun?> get(String id) async {
    final row = await _db.queryOne(
      'SELECT id, work_item_id, model, status, summary, started_at, '
      'finished_at, max_steps, error FROM dbo.agent_runs WHERE id = ?',
      [id],
    );
    return row == null ? null : AgentRun.fromRow(row);
  }

  Future<List<AgentRun>> listForWorkItem(String workItemId) async {
    final rows = await _db.query(
      'SELECT id, work_item_id, model, status, summary, started_at, '
      'finished_at, max_steps, error FROM dbo.agent_runs '
      'WHERE work_item_id = ? ORDER BY started_at DESC',
      [workItemId],
    );
    return rows.map(AgentRun.fromRow).toList(growable: false);
  }

  Future<void> setStatus(String id, String status, {String? error}) async {
    final finished =
        status == 'done' || status == 'failed' || status == 'blocked';
    await _db.execute(
      'UPDATE dbo.agent_runs SET status = ?, error = ?, '
      'finished_at = ${finished ? 'SYSUTCDATETIME()' : 'finished_at'} '
      'WHERE id = ?',
      [status, error, id],
    );
  }

  Future<void> setSummary(String id, String summary) async {
    await _db.execute(
      'UPDATE dbo.agent_runs SET summary = ? WHERE id = ?',
      [summary, id],
    );
  }

  Future<PlanStep> addStep({
    required String id,
    required String runId,
    required int ordinal,
    required String title,
    String? rationale,
  }) async {
    await _db.execute(
      'INSERT INTO dbo.plan_steps (id, run_id, ordinal, title, rationale, status) '
      "VALUES (?, ?, ?, ?, ?, 'pending')",
      [id, runId, ordinal, title, rationale],
    );
    return (await getStep(id))!;
  }

  Future<PlanStep?> getStep(String id) async {
    final row = await _db.queryOne(
      'SELECT id, run_id, ordinal, title, rationale, status, result, '
      'started_at, finished_at FROM dbo.plan_steps WHERE id = ?',
      [id],
    );
    return row == null ? null : PlanStep.fromRow(row);
  }

  Future<List<PlanStep>> listSteps(String runId) async {
    final rows = await _db.query(
      'SELECT id, run_id, ordinal, title, rationale, status, result, '
      'started_at, finished_at FROM dbo.plan_steps '
      'WHERE run_id = ? ORDER BY ordinal ASC',
      [runId],
    );
    return rows.map(PlanStep.fromRow).toList(growable: false);
  }

  Future<void> updateStep({
    required String id,
    String? status,
    String? result,
    bool markStarted = false,
    bool markFinished = false,
  }) async {
    final sets = <String>[];
    final params = <Object?>[];
    if (status != null) {
      sets.add('status = ?');
      params.add(status);
    }
    if (result != null) {
      sets.add('result = ?');
      params.add(result);
    }
    if (markStarted) sets.add('started_at = SYSUTCDATETIME()');
    if (markFinished) sets.add('finished_at = SYSUTCDATETIME()');
    if (sets.isEmpty) return;
    params.add(id);
    await _db.execute(
      'UPDATE dbo.plan_steps SET ${sets.join(', ')} WHERE id = ?',
      params,
    );
  }

  Future<void> addMessage({
    required String id,
    required String runId,
    String? stepId,
    required String role,
    required String content,
    String? toolName,
  }) async {
    await _db.execute(
      'INSERT INTO dbo.agent_messages '
      '(id, run_id, step_id, role, content, tool_name) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [id, runId, stepId, role, content, toolName],
    );
  }

  Future<List<AgentMessage>> listMessages(String runId) async {
    final rows = await _db.query(
      'SELECT id, run_id, step_id, role, content, tool_name, created_at '
      'FROM dbo.agent_messages WHERE run_id = ? ORDER BY created_at ASC',
      [runId],
    );
    return rows.map(AgentMessage.fromRow).toList(growable: false);
  }

  Future<void> recordToolCall({
    required String id,
    required String runId,
    String? stepId,
    required String toolName,
    required String argumentsJson,
    required String resultJson,
    required bool success,
  }) async {
    await _db.execute(
      'INSERT INTO dbo.tool_calls '
      '(id, run_id, step_id, tool_name, arguments, result, success, finished_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, SYSUTCDATETIME())',
      [id, runId, stepId, toolName, argumentsJson, resultJson, success ? 1 : 0],
    );
  }
}
