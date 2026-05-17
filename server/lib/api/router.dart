import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../agent/orchestrator.dart';
import '../db/repositories/agent_runs_repo.dart';
import '../db/repositories/work_items_repo.dart';
import 'handlers/agent_handler.dart';
import 'handlers/work_items_handler.dart';
import 'json.dart';

Handler buildRouter({
  required WorkItemsRepository workItems,
  required AgentRunsRepository runs,
  required Orchestrator orchestrator,
}) {
  final root = Router();

  root.get('/api/health', (Request _) => jsonResponse({'status': 'ok'}));

  root.mount(
    '/api/work-items',
    WorkItemsHandler(repo: workItems, orchestrator: orchestrator).router.call,
  );
  root.mount(
    '/api/runs',
    AgentHandler(runs: runs, workItems: workItems).router.call,
  );

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(root.call);
}
