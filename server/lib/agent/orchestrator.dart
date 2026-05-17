import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../db/repositories/agent_runs_repo.dart';
import '../db/repositories/work_items_repo.dart';
import '../ollama/ollama_client.dart';
import 'executor.dart';
import 'planner.dart';
import 'reflector.dart';
import 'tool_registry.dart';
import 'tools/tool.dart';

class Orchestrator {
  Orchestrator({
    required this.workItems,
    required this.runs,
    required this.tools,
    required this.ollama,
    required this.maxSteps,
  })  : _planner = Planner(ollama),
        _executor = Executor(ollama: ollama, tools: tools),
        _reflector = Reflector(ollama);

  final WorkItemsRepository workItems;
  final AgentRunsRepository runs;
  final ToolRegistry tools;
  final OllamaClient ollama;
  final int maxSteps;

  final Planner _planner;
  final Executor _executor;
  final Reflector _reflector;
  final Logger _log = Logger('Orchestrator');
  final Uuid _uuid = const Uuid();

  /// Kicks off a run. Returns the new run id immediately; the run continues
  /// in the background. Subscribers can poll `/api/runs/<id>`.
  Future<String> startRun(String workItemId) async {
    final item = await workItems.get(workItemId);
    if (item == null) {
      throw ArgumentError('work item $workItemId not found');
    }
    final runId = _uuid.v4();
    await runs.create(
      id: runId,
      workItemId: workItemId,
      model: ollama.model,
      maxSteps: maxSteps,
    );

    // Run async; surface failures into the run record.
    unawaited(_drive(runId, workItemId));
    return runId;
  }

  Future<void> _drive(String runId, String workItemId) async {
    try {
      await runs.setStatus(runId, 'running');
      var item = (await workItems.get(workItemId))!;

      final history = <OllamaMessage>[];

      var plan = await _planner.plan(item);
      await _persistPlan(runId, plan);
      _log.info('run $runId planned ${plan.length} steps');

      var executed = 0;
      var ordinal = 0;
      while (executed < maxSteps && ordinal < plan.length) {
        final stored = await runs.listSteps(runId);
        final pending = stored.firstWhere(
          (s) => s.status == 'pending',
          orElse: () => stored.last,
        );
        await runs.updateStep(id: pending.id, status: 'running', markStarted: true);

        final ctx = ToolContext(workItemId: workItemId, runId: runId);
        final outcome = await _executor.execute(
          item: item,
          stepTitle: pending.title,
          stepRationale: pending.rationale,
          history: history,
          ctx: ctx,
        );

        await _recordOutcome(runId, pending.id, outcome, history);
        await runs.updateStep(
          id: pending.id,
          status: 'done',
          result: _summariseOutcome(outcome),
          markFinished: true,
        );

        executed++;
        ordinal++;

        final reflection = await _reflector.reflect(
          history: history,
          latestStepTitle: pending.title,
          latestStepOutcome: _summariseOutcome(outcome),
        );
        await runs.addMessage(
          id: _uuid.v4(),
          runId: runId,
          stepId: pending.id,
          role: 'system',
          content: 'reflection: ${reflection.decision.name} — ${reflection.note}',
        );

        switch (reflection.decision) {
          case ReflectionDecision.continueNext:
            break;
          case ReflectionDecision.replan:
            item = (await workItems.get(workItemId))!;
            plan = await _planner.plan(item);
            await _persistPlan(runId, plan, replan: true);
            ordinal = 0;
            break;
          case ReflectionDecision.done:
            await runs.setSummary(runId, reflection.summary ?? reflection.note);
            await workItems.updateState(workItemId, 'Resolved');
            await runs.setStatus(runId, 'done');
            return;
          case ReflectionDecision.blocked:
            await runs.setSummary(
              runId,
              'Blocked: ${reflection.note}',
            );
            await runs.setStatus(runId, 'blocked');
            return;
        }
      }

      await runs.setSummary(
        runId,
        'Reached max steps ($maxSteps) without converging.',
      );
      await runs.setStatus(runId, 'blocked');
    } catch (e, st) {
      _log.severe('run $runId failed', e, st);
      await runs.setStatus(runId, 'failed', error: '$e\n$st');
    }
  }

  Future<void> _persistPlan(
    String runId,
    List<PlannedStep> plan, {
    bool replan = false,
  }) async {
    if (replan) {
      // We don't delete prior steps - they remain as history; we just append
      // the new ones after the highest existing ordinal.
      final existing = await runs.listSteps(runId);
      final base = existing.isEmpty ? 0 : existing.last.ordinal + 1;
      for (var i = 0; i < plan.length; i++) {
        await runs.addStep(
          id: _uuid.v4(),
          runId: runId,
          ordinal: base + i,
          title: plan[i].title,
          rationale: plan[i].rationale,
        );
      }
    } else {
      for (var i = 0; i < plan.length; i++) {
        await runs.addStep(
          id: _uuid.v4(),
          runId: runId,
          ordinal: i,
          title: plan[i].title,
          rationale: plan[i].rationale,
        );
      }
    }
  }

  Future<void> _recordOutcome(
    String runId,
    String stepId,
    StepOutcome outcome,
    List<OllamaMessage> history,
  ) async {
    if (outcome.assistantContent.isNotEmpty) {
      await runs.addMessage(
        id: _uuid.v4(),
        runId: runId,
        stepId: stepId,
        role: 'assistant',
        content: outcome.assistantContent,
      );
      history.add(
        OllamaMessage(role: 'assistant', content: outcome.assistantContent),
      );
    }
    for (var i = 0; i < outcome.toolCalls.length; i++) {
      final call = outcome.toolCalls[i];
      final res = outcome.toolResults[i];
      final argsJson = jsonEncode(call.arguments);
      final resJson = jsonEncode(res.result);
      await runs.addMessage(
        id: _uuid.v4(),
        runId: runId,
        stepId: stepId,
        role: 'tool',
        content: 'call ${call.name}($argsJson) -> $resJson',
        toolName: call.name,
      );
      await runs.recordToolCall(
        id: _uuid.v4(),
        runId: runId,
        stepId: stepId,
        toolName: call.name,
        argumentsJson: argsJson,
        resultJson: resJson,
        success: res.success,
      );
      history.add(
        OllamaMessage(
          role: 'tool',
          toolName: call.name,
          content: resJson,
        ),
      );
    }
  }

  String _summariseOutcome(StepOutcome o) {
    if (o.toolResults.isEmpty) return o.assistantContent;
    final parts = <String>[
      if (o.assistantContent.isNotEmpty) o.assistantContent,
      ...o.toolResults.map(
        (r) => 'tool ${r.name}: ${r.success ? 'ok' : 'error'} '
            '${jsonEncode(r.result)}',
      ),
    ];
    return parts.join('\n');
  }
}
