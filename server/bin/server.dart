import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:harness_server/agent/orchestrator.dart';
import 'package:harness_server/agent/tool_registry.dart';
import 'package:harness_server/agent/tools/comment_tool.dart';
import 'package:harness_server/agent/tools/get_work_item_tool.dart';
import 'package:harness_server/agent/tools/propose_fix_tool.dart';
import 'package:harness_server/agent/tools/run_tests_tool.dart';
import 'package:harness_server/api/router.dart';
import 'package:harness_server/config.dart';
import 'package:harness_server/db/database.dart';
import 'package:harness_server/db/memory_database.dart';
import 'package:harness_server/db/mssql_database.dart';
import 'package:harness_server/db/repositories/agent_runs_repo.dart';
import 'package:harness_server/db/repositories/work_items_repo.dart';
import 'package:harness_server/ollama/ollama_client.dart';

Future<void> main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    stdout.writeln('${r.time.toIso8601String()} ${r.level.name} '
        '${r.loggerName} ${r.message}'
        '${r.error == null ? '' : ' err=${r.error}'}');
  });
  final log = Logger('main');

  final config = Config.fromEnv();
  final Database db = switch (config.dbDriver) {
    'memory' => MemoryDatabase(),
    _ => MssqlDatabase(config.odbcConnectionString),
  };
  await db.connect();
  log.info(
    'connected to ${config.dbDriver == 'memory' ? 'in-memory store' : 'MSSQL ${config.mssqlHost}:${config.mssqlPort}/${config.mssqlDb}'}',
  );

  final workItems = WorkItemsRepository(db);
  final runs = AgentRunsRepository(db);
  final ollama = OllamaClient(baseUrl: config.ollamaUrl, model: config.ollamaModel);

  final tools = ToolRegistry([
    GetWorkItemTool(workItems),
    CommentOnWorkItemTool(workItems),
    ProposeFixTool(workItems),
    RunTestsTool(),
  ]);

  final orchestrator = Orchestrator(
    workItems: workItems,
    runs: runs,
    tools: tools,
    ollama: ollama,
    maxSteps: config.agentMaxSteps,
  );

  final handler = buildRouter(
    workItems: workItems,
    runs: runs,
    orchestrator: orchestrator,
  );

  final server = await shelf_io.serve(handler, '0.0.0.0', config.port);
  log.info('listening on http://${server.address.host}:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    log.info('shutdown signal received');
    await server.close(force: false);
    await db.close();
    ollama.close();
    exit(0);
  });
}
