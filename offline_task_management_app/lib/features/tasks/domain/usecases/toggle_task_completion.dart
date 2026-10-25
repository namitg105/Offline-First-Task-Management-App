// fpdart exports its own `Task`; hide it so the domain `Task` is the one in scope.
import 'package:fpdart/fpdart.dart' hide Task;

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repository/task_repository.dart';

/// Ticking a checkbox is its own use case so the rule "completing flips
/// isCompleted" lives in one testable place, not in a widget callback.
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
