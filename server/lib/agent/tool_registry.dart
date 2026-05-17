import 'tools/tool.dart';

class ToolRegistry {
  ToolRegistry(Iterable<AgentTool> tools)
      : _tools = {for (final t in tools) t.name: t};

  final Map<String, AgentTool> _tools;

  Iterable<AgentTool> get all => _tools.values;

  AgentTool? operator [](String name) => _tools[name];

  List<Map<String, Object?>> ollamaSpecs() =>
      _tools.values.map((t) => t.toOllamaSpec()).toList(growable: false);
}
