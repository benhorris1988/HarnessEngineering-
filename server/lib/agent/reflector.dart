import 'dart:convert';

import '../ollama/ollama_client.dart';

enum ReflectionDecision { continueNext, replan, done, blocked }

class Reflection {
  Reflection({required this.decision, required this.note, required this.summary});
  final ReflectionDecision decision;
  final String note;
  final String? summary;
}

class Reflector {
  Reflector(this._ollama);
  final OllamaClient _ollama;

  static const _systemPrompt = '''
You are the reflection module of an agentic DevOps assistant. Given the
plan so far and the latest step result, decide what to do next.

Choose exactly one decision:
  - "continue" - move on to the next planned step
  - "replan"   - the situation changed; the orchestrator should regenerate the plan
  - "done"     - the work item is resolved or sufficiently triaged; provide a summary
  - "blocked"  - human input is required to proceed

Respond with STRICT JSON:
{
  "decision": "continue" | "replan" | "done" | "blocked",
  "note": "<one sentence justification>",
  "summary": "<final summary if decision is done, else null>"
}
No prose outside the JSON.
''';

  Future<Reflection> reflect({
    required List<OllamaMessage> history,
    required String latestStepTitle,
    required String latestStepOutcome,
  }) async {
    final response = await _ollama.chat(
      messages: [
        OllamaMessage(role: 'system', content: _systemPrompt),
        ...history,
        OllamaMessage(
          role: 'user',
          content: 'Latest step: $latestStepTitle\n'
              'Latest outcome: $latestStepOutcome',
        ),
      ],
      format: {'type': 'object'},
      temperature: 0.1,
    );
    return _parse(response.content);
  }

  Reflection _parse(String raw) {
    final cleaned = _strip(raw);
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map) {
      throw FormatException('reflector returned non-object: $raw');
    }
    final m = decoded.cast<String, Object?>();
    final decision = switch (m['decision']) {
      'continue' => ReflectionDecision.continueNext,
      'replan' => ReflectionDecision.replan,
      'done' => ReflectionDecision.done,
      'blocked' => ReflectionDecision.blocked,
      _ => ReflectionDecision.continueNext,
    };
    return Reflection(
      decision: decision,
      note: (m['note'] as String?) ?? '',
      summary: m['summary'] as String?,
    );
  }

  String _strip(String raw) {
    final t = raw.trim();
    if (!t.startsWith('```')) return t;
    final firstNl = t.indexOf('\n');
    final body = firstNl == -1 ? t : t.substring(firstNl + 1);
    final end = body.lastIndexOf('```');
    return (end == -1 ? body : body.substring(0, end)).trim();
  }
}
