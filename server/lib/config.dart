import 'dart:io';

class Config {
  Config({
    required this.port,
    required this.dbDriver,
    required this.mssqlHost,
    required this.mssqlPort,
    required this.mssqlDb,
    required this.mssqlUser,
    required this.mssqlPassword,
    required this.ollamaUrl,
    required this.ollamaModel,
    required this.agentMaxSteps,
  });

  final int port;
  final String dbDriver; // 'mssql' | 'memory'
  final String mssqlHost;
  final int mssqlPort;
  final String mssqlDb;
  final String mssqlUser;
  final String mssqlPassword;
  final Uri ollamaUrl;
  final String ollamaModel;
  final int agentMaxSteps;

  String get odbcConnectionString =>
      'Driver={ODBC Driver 18 for SQL Server};'
      'Server=$mssqlHost,$mssqlPort;'
      'Database=$mssqlDb;'
      'UID=$mssqlUser;PWD=$mssqlPassword;'
      'Encrypt=yes;TrustServerCertificate=yes;';

  static Config fromEnv() {
    final env = Platform.environment;
    return Config(
      port: int.parse(env['HARNESS_PORT'] ?? '8080'),
      dbDriver: env['HARNESS_DB'] ?? 'mssql',
      mssqlHost: env['MSSQL_HOST'] ?? 'localhost',
      mssqlPort: int.parse(env['MSSQL_PORT'] ?? '1433'),
      mssqlDb: env['MSSQL_DB'] ?? 'Harness',
      mssqlUser: env['MSSQL_USER'] ?? 'sa',
      mssqlPassword: env['MSSQL_PASSWORD'] ?? 'Harness!Pass1',
      ollamaUrl: Uri.parse(env['OLLAMA_URL'] ?? 'http://localhost:11434'),
      ollamaModel: env['OLLAMA_MODEL'] ?? 'llama3.1:8b',
      agentMaxSteps: int.parse(env['AGENT_MAX_STEPS'] ?? '12'),
    );
  }
}
