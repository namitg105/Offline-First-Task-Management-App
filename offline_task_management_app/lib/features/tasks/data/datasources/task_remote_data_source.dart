import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../../core/error/exceptions.dart';
import '../models/task_model.dart';

/// Talks to the Postgres replica. Called only by the sync engine — never by
/// the UI, and never on the path of a user action.
abstract interface class TaskRemoteDataSource {
  /// INSERT ... ON CONFLICT (id) DO UPDATE.
  ///
  /// Upsert, not insert, makes a retry safe: the same change sent twice lands on
  /// the same row. A tombstone is just a row with deleted_at set, so deletes use
  /// this method too.
  Future<void> upsertTask(TaskModel task);

  /// Delta pull: only rows this user changed after [since].
  Future<List<TaskModel>> fetchChangedSince(String userId, DateTime? since);
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final SupabaseClient supabaseClient;

  const TaskRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<void> upsertTask(TaskModel task) async {
    try {
      // POST /rest/v1/tasks
      // Prefer: resolution=merge-duplicates
      // Authorization: Bearer <access_token>   <- RLS checks user_id = auth.uid()
      await supabaseClient.from('tasks').upsert(task.toRemoteJson());
    } on PostgrestException catch (e) {
      throw ServerException('${e.code ?? ''} ${e.message}'.trim());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TaskModel>> fetchChangedSince(
    String userId,
    DateTime? since,
  ) async {
    try {
      // GET /rest/v1/tasks?user_id=eq.<id>&updated_at=gt.<iso>
      var query = supabaseClient.from('tasks').select().eq('user_id', userId);

      if (since != null) {
        query = query.gt('updated_at', since.toUtc().toIso8601String());
      }

      final rows = await query.order('updated_at', ascending: true);
      return rows
          .map((row) => TaskModel.fromRemoteJson(row))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException('${e.code ?? ''} ${e.message}'.trim());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
