class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.runId,
    required this.stepId,
    required this.role,
    required this.content,
    required this.toolName,
    required this.createdAt,
  });

  factory AgentMessage.fromJson(Map<String, Object?> j) => AgentMessage(
        id: j['id']! as String,
        runId: j['runId']! as String,
        stepId: j['stepId'] as String?,
        role: j['role']! as String,
        content: j['content']! as String,
        toolName: j['toolName'] as String?,
        createdAt: DateTime.parse(j['createdAt']! as String),
      );

  final String id;
  final String runId;
  final String? stepId;
  final String role;
  final String content;
  final String? toolName;
  final DateTime createdAt;
}
