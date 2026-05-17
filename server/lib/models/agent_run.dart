class AgentRun {
  AgentRun({
    required this.id,
    required this.workItemId,
    required this.model,
    required this.status,
    required this.summary,
    required this.startedAt,
    required this.finishedAt,
    required this.maxSteps,
    required this.error,
  });

  final String id;
  final String workItemId;
  final String model;
  final String status;
  final String? summary;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int maxSteps;
  final String? error;

  factory AgentRun.fromRow(Map<String, Object?> r) => AgentRun(
        id: r['id']!.toString(),
        workItemId: r['work_item_id']!.toString(),
        model: r['model'] as String,
        status: r['status'] as String,
        summary: r['summary'] as String?,
        startedAt: DateTime.parse(r['started_at']!.toString()).toUtc(),
        finishedAt: r['finished_at'] == null
            ? null
            : DateTime.parse(r['finished_at']!.toString()).toUtc(),
        maxSteps: (r['max_steps'] as num).toInt(),
        error: r['error'] as String?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'workItemId': workItemId,
        'model': model,
        'status': status,
        'summary': summary,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'maxSteps': maxSteps,
        'error': error,
      };
}

class PlanStep {
  PlanStep({
    required this.id,
    required this.runId,
    required this.ordinal,
    required this.title,
    required this.rationale,
    required this.status,
    required this.result,
    required this.startedAt,
    required this.finishedAt,
  });

  final String id;
  final String runId;
  final int ordinal;
  final String title;
  final String? rationale;
  final String status;
  final String? result;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  factory PlanStep.fromRow(Map<String, Object?> r) => PlanStep(
        id: r['id']!.toString(),
        runId: r['run_id']!.toString(),
        ordinal: (r['ordinal'] as num).toInt(),
        title: r['title'] as String,
        rationale: r['rationale'] as String?,
        status: r['status'] as String,
        result: r['result'] as String?,
        startedAt: r['started_at'] == null
            ? null
            : DateTime.parse(r['started_at']!.toString()).toUtc(),
        finishedAt: r['finished_at'] == null
            ? null
            : DateTime.parse(r['finished_at']!.toString()).toUtc(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'runId': runId,
        'ordinal': ordinal,
        'title': title,
        'rationale': rationale,
        'status': status,
        'result': result,
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
      };
}

class AgentMessage {
  AgentMessage({
    required this.id,
    required this.runId,
    required this.stepId,
    required this.role,
    required this.content,
    required this.toolName,
    required this.createdAt,
  });

  final String id;
  final String runId;
  final String? stepId;
  final String role;
  final String content;
  final String? toolName;
  final DateTime createdAt;

  factory AgentMessage.fromRow(Map<String, Object?> r) => AgentMessage(
        id: r['id']!.toString(),
        runId: r['run_id']!.toString(),
        stepId: r['step_id']?.toString(),
        role: r['role'] as String,
        content: r['content'] as String,
        toolName: r['tool_name'] as String?,
        createdAt: DateTime.parse(r['created_at']!.toString()).toUtc(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'runId': runId,
        'stepId': stepId,
        'role': role,
        'content': content,
        'toolName': toolName,
        'createdAt': createdAt.toIso8601String(),
      };
}
