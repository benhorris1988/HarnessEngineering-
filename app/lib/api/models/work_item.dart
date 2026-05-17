class WorkItem {
  const WorkItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.reproSteps,
    required this.systemInfo,
    required this.severity,
    required this.priority,
    required this.state,
    required this.areaPath,
    required this.iterationPath,
    required this.tags,
    required this.assignedTo,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkItem.fromJson(Map<String, Object?> j) => WorkItem(
        id: j['id']! as String,
        type: j['type']! as String,
        title: j['title']! as String,
        description: j['description'] as String?,
        reproSteps: j['reproSteps'] as String?,
        systemInfo: j['systemInfo'] as String?,
        severity: j['severity']! as String,
        priority: (j['priority']! as num).toInt(),
        state: j['state']! as String,
        areaPath: j['areaPath']! as String,
        iterationPath: j['iterationPath']! as String,
        tags: j['tags'] as String?,
        assignedTo: j['assignedTo'] as String?,
        createdBy: j['createdBy']! as String,
        createdAt: DateTime.parse(j['createdAt']! as String),
        updatedAt: DateTime.parse(j['updatedAt']! as String),
      );

  final String id;
  final String type;
  final String title;
  final String? description;
  final String? reproSteps;
  final String? systemInfo;
  final String severity;
  final int priority;
  final String state;
  final String areaPath;
  final String iterationPath;
  final String? tags;
  final String? assignedTo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}
