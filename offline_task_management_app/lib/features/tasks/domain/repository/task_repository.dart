// fpdart exports its own `Task`; hide it so the domain `Task` is the one in scope.
import 'package:fpdart/fpdart.dart' hide Task;

import '../../../../core/error/failures.dart';
import '../entities/task.dart';
import '../entities/task_filter.dart';

abstract interface class TaskRepository {
  /// A live view of this user's tasks, straight from the local database.
  ///
  /// A plain Stream rather than `Stream<Either<Failure, T>>`: read errors surface as
  /// stream errors and are handled once, in the bloc, so widgets don't unwrap an
  /// Either that is almost never a failure.
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
