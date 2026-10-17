import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repository/task_repository.dart';

/// Ticking a checkbox is its own verb, so it gets its own use case rather
/// than the UI hand-building a flipped Task and calling UpdateTask. The rule
/// "completing a task means isCompleted becomes its opposite" now lives in
/// one testable place instead of inside a widget callback.
class ToggleTaskCompletion implements UseCase<Task, Task> {
  final TaskRepository taskRepository;

  const ToggleTaskCompletion(this.taskRepository);

  @override
  Future<Either<Failure, Task>> call(Task task) {
    return taskRepository.updateTask(
      task.copyWith(isCompleted: !task.isCompleted),
    );
  }
}
