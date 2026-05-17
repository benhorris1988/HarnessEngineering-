import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../db/repositories/agent_runs_repo.dart';
import '../../db/repositories/work_items_repo.dart';
import '../json.dart';

class AgentHandler {
  AgentHandler({required this.runs, required this.workItems});
  final AgentRunsRepository runs;
  final WorkItemsRepository workItems;

  Router get router {
    final r = Router();
    r.get('/<id>', _get);
    r.get('/<id>/steps', _steps);
    r.get('/<id>/messages', _messages);
    r.get('/by-work-item/<workItemId>', _byWorkItem);
    return r;
  }

  Future<Response> _get(Request req, String id) async {
    final run = await runs.get(id);
    if (run == null) return jsonError('not found', status: 404);
    return jsonResponse(run.toJson());
  }

  Future<Response> _steps(Request req, String id) async {
    final steps = await runs.listSteps(id);
    return jsonResponse(steps.map((s) => s.toJson()).toList());
  }

  Future<Response> _messages(Request req, String id) async {
    final msgs = await runs.listMessages(id);
    return jsonResponse(msgs.map((m) => m.toJson()).toList());
  }

  Future<Response> _byWorkItem(Request req, String workItemId) async {
    final list = await runs.listForWorkItem(workItemId);
    return jsonResponse(list.map((r) => r.toJson()).toList());
  }
}
