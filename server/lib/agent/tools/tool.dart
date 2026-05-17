/// Contract every agent tool must satisfy. Tools are pure async functions
/// from a JSON arguments map to a JSON result map; the orchestrator
/// serialises both for storage and for the LLM.
abstract class AgentTool {
  String get name;
  String get description;

  /// JSON-schema parameter description, in Ollama tool format.
  Map<String, Object?> get parametersSchema;

  Future<Map<String, Object?>> call(
    Map<String, Object?> arguments,
    ToolContext ctx,
  );

  Map<String, Object?> toOllamaSpec() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parametersSchema,
        },
      };
}

class ToolContext {
  ToolContext({required this.workItemId, required this.runId});
  final String workItemId;
  final String runId;
}
