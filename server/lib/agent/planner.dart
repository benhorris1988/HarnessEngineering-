import 'dart:convert';

import '../models/work_item.dart';
import '../ollama/ollama_client.dart';

class PlannedStep {
  PlannedStep({required this.title, required this.rationale});
  final String title;
  final String? rationale;
}

class Planner {
  Planner(this._ollama);
  final OllamaClient _ollama;

  static const _systemPrompt = '''
You are the planning module of an agentic DevOps assistant. Given a work
item, produce a SHORT ordered plan of investigative steps a software
engineer should take to triage and resolve it. Steps should be concrete
and verifiable; prefer 3-6 steps.

Respond with STRICT JSON in this shape:
{
  "steps": [
    {"title": "<short imperative title>", "rationale": "<why this step>"}
  ]
}
Do not include any prose outside the JSON object.
''';

  Future<List<PlannedStep>> plan(WorkItem item) async {
    final response = await _ollama.chat(
      messages: [
        OllamaMessage(role: 'system', content: _systemPrompt),
        OllamaMessage(role: 'user', content: _renderItem(item)),
      ],
      format: {'type': 'object'},
      temperature: 0.1,
    );
    return _parse(response.content);
  }

  String _renderItem(WorkItem i) {
    final buf = StringBuffer()
      ..writeln('Work item type: ${i.type}')
      ..writeln('Title: ${i.title}')
      ..writeln('Severity: ${i.severity}  Priority: ${i.priority}')
      ..writeln('State: ${i.state}')
      ..writeln('Area: ${i.areaPath}')
      ..writeln('Tags: ${i.tags ?? "(none)"}');
    if (i.description != null && i.description!.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Description:')
        ..writeln(i.description);
    }
    if (i.reproSteps != null && i.reproSteps!.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Repro steps:')
        ..writeln(i.reproSteps);
    }
    if (i.systemInfo != null && i.systemInfo!.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('System info:')
        ..writeln(i.systemInfo);
    }
    return buf.toString();
  }

  List<PlannedStep> _parse(String raw) {
    final cleaned = _extractJson(raw);
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map || decoded['steps'] is! List) {
      throw FormatException('planner response missing "steps" list: $raw');
    }
    final steps = (decoded['steps'] as List).cast<Object?>();
    return steps.map((s) {
      final m = (s as Map).cast<String, Object?>();
      return PlannedStep(
        title: (m['title'] as String?)?.trim() ?? 'untitled step',
        rationale: (m['rationale'] as String?)?.trim(),
      );
    }).toList(growable: false);
  }

  /// Models sometimes wrap JSON in markdown fences; strip them.
  String _extractJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('```')) {
      final firstNewline = trimmed.indexOf('\n');
      final body = firstNewline == -1 ? trimmed : trimmed.substring(firstNewline + 1);
      final endFence = body.lastIndexOf('```');
      return (endFence == -1 ? body : body.substring(0, endFence)).trim();
    }
    return trimmed;
  }
}
