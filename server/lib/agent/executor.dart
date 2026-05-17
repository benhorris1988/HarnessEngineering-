import 'dart:convert';

import '../models/work_item.dart';
import '../ollama/ollama_client.dart';
import 'tool_registry.dart';
import 'tools/tool.dart';

class StepOutcome {
  StepOutcome({
    required this.assistantContent,
    required this.toolCalls,
    required this.toolResults,
  });

  /// The model's natural-language reply (may be empty when only tools fired).
  final String assistantContent;
  final List<({String name, Map<String, Object?> arguments})> toolCalls;
  final List<({String name, Map<String, Object?> result, bool success})>
      toolResults;
}

class Executor {
  Executor({
    required OllamaClient ollama,
    required ToolRegistry tools,
  })  : _ollama = ollama,
        _tools = tools;

  final OllamaClient _ollama;
  final ToolRegistry _tools;

  static const _systemPrompt = '''
You are the execution module of an agentic DevOps assistant. You are
working on ONE step of a plan to resolve a work item. You may either:
  - call exactly one tool (preferred when the step needs evidence or an
    action), or
  - reply in natural language summarising what was learned for this step.

Be concise. Do not invent facts. If you do not have enough information,
say so plainly so the reflector can decide what to do next.
''';

  Future<StepOutcome> execute({
    required WorkItem item,
    required String stepTitle,
    required String? stepRationale,
    required List<OllamaMessage> history,
    required ToolContext ctx,
  }) async {
    final messages = <OllamaMessage>[
      OllamaMessage(role: 'system', content: _systemPrompt),
      OllamaMessage(role: 'user', content: _renderWorkItem(item)),
      ...history,
      OllamaMessage(
        role: 'user',
        content: _renderStep(stepTitle, stepRationale),
      ),
    ];

    final response = await _ollama.chat(
      messages: messages,
      tools: _tools.ollamaSpecs(),
      temperature: 0.2,
    );

    final results = <({String name, Map<String, Object?> result, bool success})>[];
    for (final call in response.toolCalls) {
      final tool = _tools[call.name];
      if (tool == null) {
        results.add((
          name: call.name,
          result: {'error': 'unknown tool ${call.name}'},
          success: false,
        ));
        continue;
      }
      try {
        final r = await tool.call(call.arguments, ctx);
        results.add((name: call.name, result: r, success: r['error'] == null));
      } catch (e, st) {
        results.add((
          name: call.name,
          result: {'error': e.toString(), 'stack': st.toString()},
          success: false,
        ));
      }
    }

    return StepOutcome(
      assistantContent: response.content,
      toolCalls: response.toolCalls
          .map((c) => (name: c.name, arguments: c.arguments))
          .toList(),
      toolResults: results,
    );
  }

  String _renderWorkItem(WorkItem i) =>
      'Work item ${i.id} — ${i.type}: ${i.title}\n'
      'Severity ${i.severity}, priority ${i.priority}, state ${i.state}.';

  String _renderStep(String title, String? rationale) {
    final buf = StringBuffer('Current step: $title');
    if (rationale != null && rationale.isNotEmpty) {
      buf
        ..writeln()
        ..write('Rationale: $rationale');
    }
    return buf.toString();
  }

  String encodeToolResult(Map<String, Object?> result) => jsonEncode(result);
}
