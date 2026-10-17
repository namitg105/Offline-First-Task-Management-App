// fpdart exports a `Task` of its own (its lazy-future monad). Our domain
// entity is also called Task, so the name is hidden here rather than
// renaming the entity — Task is the right word for what it models.
import 'package:fpdart/fpdart.dart' hide Task;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/task.dart';
import '../../domain/repository/task_repository.dart';
import '../datasources/task_local_data_source.dart';
import '../models/task_model.dart';

/// Local-first. Every method here touches SQLite and returns; not one of them
/// awaits the network. Pushing to Supabase is the sync engine's job and
/// happens afterwards, on its own schedule.
///
/// That is the whole reason the app feels instant offline: the user is never
/// waiting on a round trip they did not ask for.
class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalDataSource localDataSource;
  final Uuid uuid;

  const TaskRepositoryImpl({
    required this.localDataSource,
    required this.uuid,
  });

  @override
  Stream<List<Task>> watchTasks(String userId) =>
      localDataSource.watchTasks(userId);

  @override
  Future<Either<Failure, Task>> createTask({
    required String userId,
    required String title,
    String description = '',
    TaskPriority priority = TaskPriority.medium,
    String category = '',
    DateTime? dueAt,
  }) async {
    try {
      final now = DateTime.now();
      final task = TaskModel(
        // v4 = random. Generated here, on the device, with no server round
        // trip, so the task has an identity before it has ever been online.
        id: uuid.v4(),
        userId: userId,
        title: title.trim(),
        description: description.trim(),
        priority: priority,
        category: category.trim(),
        dueAt: dueAt,
        createdAt: now,
        updatedAt: now,
        isSynced: false,
      );
      await localDataSource.saveTask(task);
      return right(task);
    } on CacheException catch (e) {
      return left(CacheFailure(e.message));
    } catch (e) {
      return left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Task>> updateTask(Task task) async {
    try {
      // updated_at is stamped in exactly one place. Conflict resolution
      // compares this value, so letting callers set it would be a bug farm.
      final updated = TaskModel.fromEntity(
        task.copyWith(updatedAt: DateTime.now(), isSynced: false),
      );
      await localDataSource.saveTask(updated);
      return right(updated);
    } on CacheException catch (e) {
      return left(CacheFailure(e.message));
    } catch (e) {
      return left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteTask(String taskId) async {
    try {
      await localDataSource.deleteTask(taskId);
      return right(unit);
    } on CacheException catch (e) {
      return left(CacheFailure(e.message));
    } catch (e) {
      return left(CacheFailure(e.toString()));
    }
  }
}
