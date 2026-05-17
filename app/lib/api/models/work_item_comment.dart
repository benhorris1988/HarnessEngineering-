class WorkItemComment {
  const WorkItemComment({
    required this.id,
    required this.workItemId,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  factory WorkItemComment.fromJson(Map<String, Object?> j) => WorkItemComment(
        id: j['id']! as String,
        workItemId: j['workItemId']! as String,
        author: j['author']! as String,
        body: j['body']! as String,
        createdAt: j['createdAt'] == null
            ? DateTime.now()
            : DateTime.parse(j['createdAt']! as String),
      );

  final String id;
  final String workItemId;
  final String author;
  final String body;
  final DateTime createdAt;
}
