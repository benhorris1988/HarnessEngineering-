import '../../db/repositories/work_items_repo.dart';
import 'tool.dart';

class GetWorkItemTool extends AgentTool {
  GetWorkItemTool(this._repo);
  final WorkItemsRepository _repo;

  @override
  String get name => 'get_work_item';

  @override
  String get description =>
      'Fetch the current work item, its fields, and recent comments.';

  @override
  Map<String, Object?> get parametersSchema => {
        'type': 'object',
        'properties': <String, Object?>{},
        'required': <String>[],
      };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> arguments,
    ToolContext ctx,
  ) async {
    final item = await _repo.get(ctx.workItemId);
    if (item == null) {
      return {'error': 'work item ${ctx.workItemId} not found'};
    }
    final comments = await _repo.listComments(ctx.workItemId);
    return {
      'workItem': item.toJson(),
      'comments': comments
          .map((c) => {
                'author': c['author'],
                'body': c['body'],
                'createdAt': c['created_at']?.toString(),
              })
          .toList(),
    };
  }
}
