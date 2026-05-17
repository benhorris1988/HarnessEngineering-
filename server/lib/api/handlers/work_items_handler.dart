import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../../agent/orchestrator.dart';
import '../../db/repositories/work_items_repo.dart';
import '../json.dart';

class WorkItemsHandler {
  WorkItemsHandler({required this.repo, required this.orchestrator});
  final WorkItemsRepository repo;
  final Orchestrator orchestrator;
  final Uuid _uuid = const Uuid();

  Router get router {
    final r = Router();
    r.get('/', _list);
    r.post('/', _create);
    r.get('/<id>', _get);
    r.get('/<id>/comments', _comments);
    r.post('/<id>/comments', _addComment);
    r.post('/<id>/runs', _kickoffRun);
    return r;
  }

  Future<Response> _list(Request req) async {
    final state = req.url.queryParameters['state'];
    final items = await repo.list(state: state);
    return jsonResponse(items.map((i) => i.toJson()).toList());
  }

  Future<Response> _get(Request req, String id) async {
    final item = await repo.get(id);
    if (item == null) return jsonError('not found', status: 404);
    return jsonResponse(item.toJson());
  }

  Future<Response> _create(Request req) async {
    final body = await readJsonBody(req);
    final title = (body['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      return jsonError('title is required');
    }
    final autorun = body['autorun'] != false;
    final id = _uuid.v4();
    final item = await repo.create(
      id: id,
      type: (body['type'] as String?) ?? 'Bug',
      title: title,
      description: body['description'] as String?,
      reproSteps: body['reproSteps'] as String?,
      systemInfo: body['systemInfo'] as String?,
      severity: (body['severity'] as String?) ?? '3 - Medium',
      priority: (body['priority'] as num?)?.toInt() ?? 2,
      areaPath: (body['areaPath'] as String?) ?? 'Harness',
      iterationPath: (body['iterationPath'] as String?) ?? 'Harness\\Current',
      tags: body['tags'] as String?,
      createdBy: (body['createdBy'] as String?) ?? 'simulated-user',
    );
    String? runId;
    if (autorun) {
      runId = await orchestrator.startRun(id);
    }
    return jsonResponse(
      {'workItem': item.toJson(), 'runId': runId},
      status: 201,
    );
  }

  Future<Response> _comments(Request req, String id) async {
    final rows = await repo.listComments(id);
    return jsonResponse(
      rows
          .map((r) => {
                'id': r['id'].toString(),
                'workItemId': r['work_item_id'].toString(),
                'author': r['author'],
                'body': r['body'],
                'createdAt': r['created_at']?.toString(),
              })
          .toList(),
    );
  }

  Future<Response> _addComment(Request req, String id) async {
    final body = await readJsonBody(req);
    final text = (body['body'] as String?)?.trim();
    if (text == null || text.isEmpty) return jsonError('body is required');
    await repo.addComment(
      workItemId: id,
      author: (body['author'] as String?) ?? 'simulated-user',
      body: text,
    );
    return jsonResponse({'ok': true}, status: 201);
  }

  Future<Response> _kickoffRun(Request req, String id) async {
    final runId = await orchestrator.startRun(id);
    return jsonResponse({'runId': runId}, status: 202);
  }
}
