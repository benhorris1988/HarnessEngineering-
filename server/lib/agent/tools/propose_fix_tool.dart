import '../../db/repositories/work_items_repo.dart';
import 'tool.dart';

class ProposeFixTool extends AgentTool {
  ProposeFixTool(this._repo);
  final WorkItemsRepository _repo;

  @override
  String get name => 'propose_fix';

  @override
  String get description =>
      'Record a proposed code or process fix. Stored as a comment tagged '
      '[PROPOSED FIX] so a human reviewer can act on it. Use this once you '
      'have identified the root cause.';

  @override
  Map<String, Object?> get parametersSchema => {
        'type': 'object',
        'properties': {
          'rootCause': {
            'type': 'string',
            'description': 'One-paragraph root cause analysis.',
          },
          'fixSummary': {
            'type': 'string',
            'description': 'What to change, in plain English.',
          },
          'patch': {
            'type': 'string',
            'description': 'Optional unified-diff patch or pseudo-code.',
          },
          'riskNotes': {
            'type': 'string',
            'description': 'Risks, regressions to watch for, rollout notes.',
          },
        },
        'required': ['rootCause', 'fixSummary'],
      };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> arguments,
    ToolContext ctx,
  ) async {
    final rootCause = arguments['rootCause'] as String?;
    final fixSummary = arguments['fixSummary'] as String?;
    if (rootCause == null || fixSummary == null) {
      return {'error': 'rootCause and fixSummary are required'};
    }
    final patch = arguments['patch'] as String?;
    final risk = arguments['riskNotes'] as String?;
    final body = StringBuffer('[PROPOSED FIX]\n\n')
      ..writeln('**Root cause**\n\n$rootCause\n')
      ..writeln('**Fix**\n\n$fixSummary\n');
    if (patch != null && patch.trim().isNotEmpty) {
      body
        ..writeln('**Patch**\n')
        ..writeln('```diff')
        ..writeln(patch)
        ..writeln('```\n');
    }
    if (risk != null && risk.trim().isNotEmpty) {
      body.writeln('**Risk notes**\n\n$risk');
    }
    await _repo.addComment(
      workItemId: ctx.workItemId,
      author: 'agent',
      body: body.toString(),
    );
    return {'ok': true};
  }
}
