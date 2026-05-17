import '../../models/work_item.dart';
import '../database.dart';

class WorkItemsRepository {
  WorkItemsRepository(this._db);
  final Database _db;

  static const _selectAll = '''
    SELECT id, type, title, description, repro_steps, system_info,
           severity, priority, state, area_path, iteration_path,
           tags, assigned_to, created_by, created_at, updated_at
    FROM dbo.work_items
  ''';

  Future<List<WorkItem>> list({String? state, int limit = 100}) async {
    final where = state == null ? '' : 'WHERE state = ?';
    final params = <Object?>[if (state != null) state];
    final rows = await _db.query(
      '$_selectAll $where ORDER BY created_at DESC OFFSET 0 ROWS '
      'FETCH NEXT $limit ROWS ONLY',
      params,
    );
    return rows.map(WorkItem.fromRow).toList(growable: false);
  }

  Future<WorkItem?> get(String id) async {
    final row = await _db.queryOne('$_selectAll WHERE id = ?', [id]);
    return row == null ? null : WorkItem.fromRow(row);
  }

  Future<WorkItem> create({
    required String id,
    required String type,
    required String title,
    String? description,
    String? reproSteps,
    String? systemInfo,
    String severity = '3 - Medium',
    int priority = 2,
    String areaPath = 'Harness',
    String iterationPath = 'Harness\\Current',
    String? tags,
    String createdBy = 'simulated-user',
  }) async {
    await _db.execute(
      '''
      INSERT INTO dbo.work_items
        (id, type, title, description, repro_steps, system_info,
         severity, priority, state, area_path, iteration_path, tags, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'New', ?, ?, ?, ?)
      ''',
      [
        id,
        type,
        title,
        description,
        reproSteps,
        systemInfo,
        severity,
        priority,
        areaPath,
        iterationPath,
        tags,
        createdBy,
      ],
    );
    final created = await get(id);
    if (created == null) {
      throw StateError('Insert succeeded but row $id not found');
    }
    return created;
  }

  Future<void> updateState(String id, String state) async {
    await _db.execute(
      'UPDATE dbo.work_items SET state = ?, updated_at = SYSUTCDATETIME() '
      'WHERE id = ?',
      [state, id],
    );
  }

  Future<void> addComment({
    required String workItemId,
    required String author,
    required String body,
  }) async {
    await _db.execute(
      'INSERT INTO dbo.work_item_comments (work_item_id, author, body) '
      'VALUES (?, ?, ?)',
      [workItemId, author, body],
    );
  }

  Future<List<Map<String, Object?>>> listComments(String workItemId) async {
    return _db.query(
      'SELECT id, work_item_id, author, body, created_at '
      'FROM dbo.work_item_comments WHERE work_item_id = ? '
      'ORDER BY created_at ASC',
      [workItemId],
    );
  }
}
