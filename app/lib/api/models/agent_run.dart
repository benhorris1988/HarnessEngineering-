class AgentRun {
  const AgentRun({
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

  factory AgentRun.fromJson(Map<String, Object?> j) => AgentRun(
        id: j['id']! as String,
        workItemId: j['workItemId']! as String,
        model: j['model']! as String,
        status: j['status']! as String,
        summary: j['summary'] as String?,
        startedAt: DateTime.parse(j['startedAt']! as String),
        finishedAt: j['finishedAt'] == null
            ? null
            : DateTime.parse(j['finishedAt']! as String),
        maxSteps: (j['maxSteps']! as num).toInt(),
        error: j['error'] as String?,
      );

  final String id;
  final String workItemId;
  final String model;
  final String status;
  final String? summary;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int maxSteps;
  final String? error;

  bool get isTerminal =>
      status == 'done' || status == 'blocked' || status == 'failed';
}
