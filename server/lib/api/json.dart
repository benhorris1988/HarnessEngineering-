import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonResponse(Object? body, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'access-control-allow-origin': '*',
    },
  );
}

Response jsonError(String message, {int status = 400, Object? details}) {
  return jsonResponse(
    {'error': message, if (details != null) 'details': details},
    status: status,
  );
}

Future<Map<String, Object?>> readJsonBody(Request req) async {
  final raw = await req.readAsString();
  if (raw.isEmpty) return const {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('Request body must be a JSON object');
  }
  return decoded.cast<String, Object?>();
}

Middleware corsHeaders() {
  return (Handler inner) {
    return (Request req) async {
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final resp = await inner(req);
      return resp.change(headers: {...resp.headers, ..._corsHeaders});
    };
  };
}

const _corsHeaders = <String, String>{
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': 'content-type, authorization',
};
