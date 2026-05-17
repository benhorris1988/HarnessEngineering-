import 'tool.dart';

/// Stub test runner. Real deployments would shell out to the actual
/// repository under test; here we return a deterministic envelope so the
/// agent loop can be exercised end-to-end without external dependencies.
class RunTestsTool extends AgentTool {
  @override
  String get name => 'run_tests';

  @override
  String get description =>
      'Run the relevant test suite. Returns pass/fail counts and the '
      'first failing test name if any. (Simulated in this build.)';

  @override
  Map<String, Object?> get parametersSchema => {
        'type': 'object',
        'properties': {
          'suite': {
            'type': 'string',
            'description': 'Suite or path filter, e.g. "auth", "etl".',
          },
        },
        'required': ['suite'],
      };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> arguments,
    ToolContext ctx,
  ) async {
    final suite = (arguments['suite'] as String?)?.toLowerCase() ?? '';
    // Deterministic mock so the agent has something concrete to react to.
    if (suite.contains('auth')) {
      return {
        'passed': 142,
        'failed': 1,
        'firstFailure': 'auth/login_email_with_plus_test',
        'durationMs': 8421,
      };
    }
    if (suite.contains('etl')) {
      return {
        'passed': 38,
        'failed': 0,
        'durationMs': 12044,
        'note': 'job duration exceeded SLA by 2h42m',
      };
    }
    return {'passed': 0, 'failed': 0, 'note': 'no suite matched "$suite"'};
  }
}
