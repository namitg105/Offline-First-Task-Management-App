import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/task.dart';
import '../entities/task_filter.dart';

abstract interface class TaskRepository {
  /// A live view of this user's tasks, straight from the local database.
  ///
  /// Returns a plain Stream rather than Stream<Either<...>>: wrapping every
  /// emission in an Either would make every widget unwrap a value that is
  /// almost never a failure. Read errors are surfaced as stream errors and
  /// handled once, in the bloc.
  Stream<List<Task>> watchTasks(String userId, TaskFilter filter);

  /// Distinct categories this user has used, for the filter sheet.
  Future<List<String>> getCategories(String userId);

  Future<Either<Failure, Task>> createTask({
    required String userId,
    required String title,
    String description,
    TaskPriority priority,
    String category,
    DateTime? dueAt,
  });

  Future<Either<Failure, Task>> updateTask(Task task);

  Future<Either<Failure, Unit>> deleteTask(String taskId);
}
