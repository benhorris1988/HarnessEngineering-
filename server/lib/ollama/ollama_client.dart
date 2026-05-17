import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal Ollama HTTP client. Targets the `/api/chat` endpoint, which
/// supports structured tool calls on recent server versions.
class OllamaClient {
  OllamaClient({required Uri baseUrl, required this.model, http.Client? client})
      : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  final Uri _baseUrl;
  final String model;
  final http.Client _client;

  void close() => _client.close();

  /// Non-streaming chat completion. [tools] is the JSON-schema tool list
  /// in Ollama's format; pass `null` to disable tool calling.
  Future<OllamaChatResponse> chat({
    required List<OllamaMessage> messages,
    List<Map<String, Object?>>? tools,
    Map<String, Object?>? format,
    double temperature = 0.2,
  }) async {
    final url = _baseUrl.resolve('/api/chat');
    final body = <String, Object?>{
      'model': model,
      'stream': false,
      'messages': messages.map((m) => m.toJson()).toList(),
      'options': {'temperature': temperature},
      if (tools != null) 'tools': tools,
      if (format != null) 'format': format,
    };
    final resp = await _client.post(
      url,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 400) {
      throw OllamaException(
        'Ollama ${resp.statusCode}: ${resp.body}',
        statusCode: resp.statusCode,
      );
    }
    final json = jsonDecode(resp.body) as Map<String, Object?>;
    return OllamaChatResponse.fromJson(json);
  }
}

class OllamaMessage {
  const OllamaMessage({
    required this.role,
    required this.content,
    this.toolName,
    this.toolCalls,
  });

  final String role; // system | user | assistant | tool
  final String content;
  final String? toolName;
  final List<OllamaToolCall>? toolCalls;

  Map<String, Object?> toJson() => {
        'role': role,
        'content': content,
        if (toolName != null) 'name': toolName,
        if (toolCalls != null)
          'tool_calls': toolCalls!.map((c) => c.toJson()).toList(),
      };
}

class OllamaToolCall {
  const OllamaToolCall({required this.name, required this.arguments});
  final String name;
  final Map<String, Object?> arguments;

  factory OllamaToolCall.fromJson(Map<String, Object?> json) {
    final function = (json['function'] as Map?)?.cast<String, Object?>() ?? {};
    final rawArgs = function['arguments'];
    final Map<String, Object?> args = switch (rawArgs) {
      Map() => rawArgs.cast<String, Object?>(),
      String() => jsonDecode(rawArgs) as Map<String, Object?>,
      _ => <String, Object?>{},
    };
    return OllamaToolCall(
      name: function['name'] as String? ?? '',
      arguments: args,
    );
  }

  Map<String, Object?> toJson() => {
        'function': {'name': name, 'arguments': arguments},
      };
}

class OllamaChatResponse {
  OllamaChatResponse({
    required this.content,
    required this.toolCalls,
    required this.done,
  });

  final String content;
  final List<OllamaToolCall> toolCalls;
  final bool done;

  factory OllamaChatResponse.fromJson(Map<String, Object?> json) {
    final message = (json['message'] as Map?)?.cast<String, Object?>() ?? {};
    final rawCalls = (message['tool_calls'] as List?) ?? const [];
    return OllamaChatResponse(
      content: (message['content'] as String?) ?? '',
      toolCalls: rawCalls
          .cast<Map>()
          .map((m) => OllamaToolCall.fromJson(m.cast<String, Object?>()))
          .toList(),
      done: (json['done'] as bool?) ?? true,
    );
  }
}

class OllamaException implements Exception {
  OllamaException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'OllamaException: $message';
}
