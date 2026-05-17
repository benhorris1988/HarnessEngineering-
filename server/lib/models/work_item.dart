class WorkItem {
  WorkItem({
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

  factory WorkItem.fromRow(Map<String, Object?> r) => WorkItem(
        id: r['id']!.toString(),
        type: r['type'] as String,
        title: r['title'] as String,
        description: r['description'] as String?,
        reproSteps: r['repro_steps'] as String?,
        systemInfo: r['system_info'] as String?,
        severity: r['severity'] as String,
        priority: (r['priority'] as num).toInt(),
        state: r['state'] as String,
        areaPath: r['area_path'] as String,
        iterationPath: r['iteration_path'] as String,
        tags: r['tags'] as String?,
        assignedTo: r['assigned_to'] as String?,
        createdBy: r['created_by'] as String,
        createdAt: DateTime.parse(r['created_at']!.toString()).toUtc(),
        updatedAt: DateTime.parse(r['updated_at']!.toString()).toUtc(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'description': description,
        'reproSteps': reproSteps,
        'systemInfo': systemInfo,
        'severity': severity,
        'priority': priority,
        'state': state,
        'areaPath': areaPath,
        'iterationPath': iterationPath,
        'tags': tags,
        'assignedTo': assignedTo,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
