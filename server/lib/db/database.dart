/// Thin async interface so the agent code never touches the driver directly.
/// The MSSQL implementation lives in [mssql_database.dart]; an in-memory
/// fallback for local development lives in [memory_database.dart].
abstract class Database {
  Future<void> connect();
  Future<void> close();

  /// Returns the affected row count.
  Future<int> execute(String sql, [List<Object?> params = const []]);

  /// Returns every row as a `Map<columnName, value>`.
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> params = const [],
  ]);

  Future<Map<String, Object?>?> queryOne(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final rows = await query(sql, params);
    return rows.isEmpty ? null : rows.first;
  }
}
