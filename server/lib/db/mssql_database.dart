import 'database.dart';

/// MSSQL adapter scaffold.
///
/// There is no single canonical "MSSQL for pure Dart" package — common
/// production choices are:
///
///   * `package:odbc` (FFI to unixODBC + Microsoft `msodbcsql18` driver),
///   * `package:tedious_dart` (Dart port of node-mssql's TDS protocol),
///   * Calling `sqlcmd` via [Process] for very simple deployments.
///
/// Pick one, add the dependency to `pubspec.yaml`, and implement the
/// three methods below. The repositories never touch this class
/// directly — they go through [Database] — so the rest of the codebase
/// won't change.
///
/// The parameter style used by the repos is `?` positional placeholders,
/// matching ODBC and most TDS drivers; the order in `params` matches
/// the `?` order in `sql`.
class MssqlDatabase implements Database {
  MssqlDatabase(this._connectionString);

  // ignore: unused_field
  final String _connectionString;

  @override
  Future<void> connect() async {
    throw UnimplementedError(
      'Wire in your MSSQL driver in lib/db/mssql_database.dart, '
      'or run with HARNESS_DB=memory for the in-memory store.',
    );
  }

  @override
  Future<void> close() async {}

  @override
  Future<int> execute(String sql, [List<Object?> params = const []]) {
    throw UnimplementedError('MssqlDatabase.execute not wired up');
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> params = const [],
  ]) {
    throw UnimplementedError('MssqlDatabase.query not wired up');
  }

  @override
  Future<Map<String, Object?>?> queryOne(
    String sql, [
    List<Object?> params = const [],
  ]) async {
    final rows = await query(sql, params);
    return rows.isEmpty ? null : rows.first;
  }
}
