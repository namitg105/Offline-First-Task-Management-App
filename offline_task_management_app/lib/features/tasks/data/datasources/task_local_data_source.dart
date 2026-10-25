import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/task_filter.dart';
import '../../../../core/error/exceptions.dart';
import '../models/outbox_entry.dart';
import '../models/task_model.dart';

/// Everything that touches the on-device database.
///
/// Tasks and the outbox live behind ONE class on purpose: a task write and its
/// queued change must land in the same SQLite transaction, and a transaction
/// can't span two owners without leaking `Transaction` into both public APIs.
abstract interface class TaskLocalDataSource {
  /// Fires once after every successful local write. The sync engine listens so a
  /// change starts travelling to the server moments after the user makes it,
  /// without the repository knowing a sync engine exists.
  Stream<void> get changes;

  /// Emits the current list immediately, then again after every local write.
  Stream<List<TaskModel>> watchTasks(String userId, TaskFilter filter);

  Future<List<TaskModel>> getTasks(String userId, TaskFilter filter);
  Future<TaskModel?> getTaskById(String id);

  /// Distinct categories in use, to populate the filter sheet.
  Future<List<String>> getCategories(String userId);

  /// Writes the task AND queues it for the server, atomically.
  Future<void> saveTask(TaskModel task);

  /// Marks the task deleted (tombstone) and queues the delete, atomically.
  Future<void> deleteTask(String id);

  /// Applies rows pulled from the server, resolving conflicts.
  Future<void> applyRemoteTasks(List<TaskModel> remoteTasks);

  // --- outbox, used by the sync engine ---
  Future<List<OutboxEntry>> pendingEntries({int limit = 50, DateTime? now});
  Future<int> pendingCount();
  Future<void> markEntrySucceeded(OutboxEntry entry);
  Future<void> markEntryFailed(OutboxEntry entry, String error, DateTime retryAt);

  Future<DateTime?> getLastPulledAt();
  Future<void> setLastPulledAt(DateTime value);

  /// Wipes local data — used on logout so the next user starts clean.
  Future<void> clear();
}

class TaskLocalDataSourceImpl implements TaskLocalDataSource {
  final AppDatabase appDatabase;

  /// Fires after every successful write so open screens re-query.
  /// A tiny hand-rolled version of what Drift's `watch()` gives you.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  TaskLocalDataSourceImpl(this.appDatabase);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<List<TaskModel>> watchTasks(String userId, TaskFilter filter) async* {
    yield await getTasks(userId, filter);
    await for (final _ in _changes.stream) {
      yield await getTasks(userId, filter);
    }
  }

  /// Searching and filtering happen in SQL, not in Dart: pulling every row into
  /// memory and calling `.where()` is fine at twenty tasks and falls over at two
  /// thousand, and the indexes already exist for exactly this.
  @override
  Future<List<TaskModel>> getTasks(String userId, TaskFilter filter) async {
    try {
      final db = await appDatabase.database;

      // deleted_at IS NULL hides tombstones: rows that still exist only so
      // the delete can be replayed to the server.
      final where = StringBuffer('user_id = ? AND deleted_at IS NULL');
      final args = <Object?>[userId];

      if (filter.query.trim().isNotEmpty) {
        // Every user value goes in as a `?` placeholder, never string
        // concatenation. A task titled  '; DROP TABLE tasks; --  is then
        // just an oddly named task instead of an incident.
        where.write(
          ' AND (title LIKE ? OR description LIKE ? OR category LIKE ?)',
        );
        final pattern = '%${filter.query.trim()}%';
        args.addAll([pattern, pattern, pattern]);
      }

      switch (filter.completion) {
        case TaskCompletionFilter.pending:
          where.write(' AND is_completed = 0');
        case TaskCompletionFilter.completed:
          where.write(' AND is_completed = 1');
        case TaskCompletionFilter.all:
          break;
      }

      if (filter.priority != null) {
        where.write(' AND priority = ?');
        args.add(filter.priority!.index);
      }

      if (filter.category != null && filter.category!.isNotEmpty) {
        where.write(' AND category = ?');
        args.add(filter.category);
      }

      final rows = await db.query(
        'tasks',
        where: where.toString(),
        whereArgs: args,
        orderBy: _orderBy(filter.sort),
      );
      return rows.map(TaskModel.fromLocalRow).toList();
    } catch (e) {
      throw CacheException('Could not read tasks: $e');
    }
  }

  /// Built from an enum, never from user text, so ORDER BY can't become an injection
  /// point. `due_at IS NULL` first pushes undated tasks to the bottom: SQLite sorts
  /// NULL before every real date, which would bury urgent tasks under undated ones.
  String _orderBy(TaskSort sort) => switch (sort) {
        TaskSort.dueDate =>
          'is_completed ASC, due_at IS NULL, due_at ASC, created_at DESC',
        TaskSort.priority =>
          'is_completed ASC, priority DESC, due_at IS NULL, due_at ASC',
        TaskSort.createdAt => 'is_completed ASC, created_at DESC',
        TaskSort.title => 'is_completed ASC, title COLLATE NOCASE ASC',
      };

  @override
  Future<List<String>> getCategories(String userId) async {
    final db = await appDatabase.database;
    final rows = await db.rawQuery(
      '''SELECT DISTINCT category FROM tasks
         WHERE user_id = ? AND deleted_at IS NULL AND category <> ''
         ORDER BY category COLLATE NOCASE ASC''',
      [userId],
    );
    return rows.map((row) => row['category'] as String).toList();
  }

  @override
  Future<TaskModel?> getTaskById(String id) async {
    final db = await appDatabase.database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : TaskModel.fromLocalRow(rows.first);
  }

  // Writes: each one is a single transaction

  @override
  Future<void> saveTask(TaskModel task) async {
    try {
      final db = await appDatabase.database;
      await db.transaction((txn) async {
        await txn.insert(
          'tasks',
          task.toLocalRow()..['is_synced'] = 0,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _enqueue(txn, task, OutboxOperation.upsert);
      });
      _notify();
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Could not save task: $e');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      final db = await appDatabase.database;
      await db.transaction((txn) async {
        final rows =
            await txn.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
        if (rows.isEmpty) return;

        final now = DateTime.now();
        final tombstone = TaskModel.fromLocalRow(rows.first).copyWithDeleted(now);

        await txn.update(
          'tasks',
          {
            'deleted_at': now.millisecondsSinceEpoch,
            'updated_at': now.millisecondsSinceEpoch,
            'is_synced': 0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await _enqueue(txn, tombstone, OutboxOperation.delete);
      });
      _notify();
    } catch (e) {
      throw CacheException('Could not delete task: $e');
    }
  }

  /// Appends to the outbox, collapsing changes the server hasn't seen yet: toggling
  /// a checkbox ten times offline sends one final value. Entries already attempted
  /// are left alone, since one may be in flight.
  Future<void> _enqueue(
    DatabaseExecutor txn,
    TaskModel task,
    OutboxOperation operation,
  ) async {
    await txn.delete(
      'outbox',
      where: 'task_id = ? AND attempts = 0',
      whereArgs: [task.id],
    );
    await txn.insert('outbox', {
      'task_id': task.id,
      'operation': operation.name,
      'payload': task.encodePayload(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
      'next_retry_at': 0,
    });
  }

  // Pull side: merging what the server sent us

  @override
  Future<void> applyRemoteTasks(List<TaskModel> remoteTasks) async {
    if (remoteTasks.isEmpty) return;
    final db = await appDatabase.database;

    await db.transaction((txn) async {
      for (final remote in remoteTasks) {
        final rows = await txn.query('tasks',
            where: 'id = ?', whereArgs: [remote.id], limit: 1);

        if (rows.isEmpty) {
          await txn.insert('tasks', remote.toLocalRow()..['is_synced'] = 1,
              conflictAlgorithm: ConflictAlgorithm.replace);
          continue;
        }

        final local = TaskModel.fromLocalRow(rows.first);

        // Rule 1: local edits that have not been pushed always win. They are
        // sitting in the outbox and will overwrite the server shortly, so
        // clobbering them here would silently lose the user's work.
        if (!local.isSynced) continue;

        // Rule 2: otherwise last-write-wins on updated_at.
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          await txn.update('tasks', remote.toLocalRow()..['is_synced'] = 1,
              where: 'id = ?', whereArgs: [remote.id]);
        }
      }
    });
    _notify();
  }

  @override
  Future<List<OutboxEntry>> pendingEntries({int limit = 50, DateTime? now}) async {
    final db = await appDatabase.database;
    final cutoff = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rows = await db.query(
      'outbox',
      where: 'next_retry_at <= ?',
      whereArgs: [cutoff],
      orderBy: 'id ASC', // replay in the order the user made the changes
      limit: limit,
    );
    return rows.map(OutboxEntry.fromRow).toList();
  }

  @override
  Future<int> pendingCount() async {
    final db = await appDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return (result.first['c'] as int?) ?? 0;
  }

  @override
  Future<void> markEntrySucceeded(OutboxEntry entry) async {
    final db = await appDatabase.database;
    await db.transaction((txn) async {
      await txn.delete('outbox', where: 'id = ?', whereArgs: [entry.id]);

      // Only call the task synced once NOTHING is queued for it any more —
      // the user may have edited it again while this entry was in flight.
      final remaining = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM outbox WHERE task_id = ?',
        [entry.taskId],
      )) ?? 0;

      if (remaining > 0) return;

      if (entry.operation == OutboxOperation.delete) {
        // The server has the tombstone now, so the local row has no job left.
        await txn.delete('tasks', where: 'id = ?', whereArgs: [entry.taskId]);
      } else {
        await txn.update('tasks', {'is_synced': 1},
            where: 'id = ?', whereArgs: [entry.taskId]);
      }
    });
    _notify();
  }

  @override
  Future<void> markEntryFailed(
    OutboxEntry entry,
    String error,
    DateTime retryAt,
  ) async {
    final db = await appDatabase.database;
    await db.update(
      'outbox',
      {
        'attempts': entry.attempts + 1,
        'next_retry_at': retryAt.millisecondsSinceEpoch,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    _notify();
  }

  @override
  Future<DateTime?> getLastPulledAt() async {
    final db = await appDatabase.database;
    final rows = await db.query('sync_meta',
        where: 'key = ?', whereArgs: ['last_pulled_at'], limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['value'] as String);
  }

  @override
  Future<void> setLastPulledAt(DateTime value) async {
    final db = await appDatabase.database;
    await db.insert(
      'sync_meta',
      {'key': 'last_pulled_at', 'value': value.toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear() async {
    final db = await appDatabase.database;
    await db.transaction((txn) async {
      await txn.delete('outbox');
      await txn.delete('tasks');
      await txn.delete('sync_meta');
    });
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
