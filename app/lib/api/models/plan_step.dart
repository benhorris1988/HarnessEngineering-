class PlanStep {
  const PlanStep({
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

  factory PlanStep.fromJson(Map<String, Object?> j) => PlanStep(
        id: j['id']! as String,
        runId: j['runId']! as String,
        ordinal: (j['ordinal']! as num).toInt(),
        title: j['title']! as String,
        rationale: j['rationale'] as String?,
        status: j['status']! as String,
        result: j['result'] as String?,
        startedAt: j['startedAt'] == null
            ? null
            : DateTime.parse(j['startedAt']! as String),
        finishedAt: j['finishedAt'] == null
            ? null
            : DateTime.parse(j['finishedAt']! as String),
      );

  final String id;
  final String runId;
  final int ordinal;
  final String title;
  final String? rationale;
  final String status;
  final String? result;
  final DateTime? startedAt;
  final DateTime? finishedAt;
}
