import '../../db/repositories/work_items_repo.dart';
import 'tool.dart';

class CommentOnWorkItemTool extends AgentTool {
  CommentOnWorkItemTool(this._repo);
  final WorkItemsRepository _repo;

  @override
  String get name => 'comment_on_work_item';

  @override
  String get description =>
      'Post a comment back to the work item. Use this to record findings '
      'or to communicate with the human owner.';

  @override
  Map<String, Object?> get parametersSchema => {
        'type': 'object',
        'properties': {
          'body': {
            'type': 'string',
            'description': 'Markdown body of the comment.',
          },
        },
        'required': ['body'],
      };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> arguments,
    ToolContext ctx,
  ) async {
    final body = (arguments['body'] as String?)?.trim();
    if (body == null || body.isEmpty) {
      return {'error': 'body is required'};
    }
    await _repo.addComment(
      workItemId: ctx.workItemId,
      author: 'agent',
      body: body,
    );
    return {'ok': true};
  }
}
