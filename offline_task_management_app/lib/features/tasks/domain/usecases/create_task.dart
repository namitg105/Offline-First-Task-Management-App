// fpdart exports a `Task` of its own (its lazy-future monad). Our domain
// entity is also called Task, so the name is hidden here rather than
// renaming the entity — Task is the right word for what it models.
import 'package:fpdart/fpdart.dart' hide Task;

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repository/task_repository.dart';

class CreateTask implements UseCase<Task, CreateTaskParams> {
  final TaskRepository taskRepository;

  const CreateTask(this.taskRepository);

  @override
  Future<Either<Failure, Task>> call(CreateTaskParams params) {
    return taskRepository.createTask(
      userId: params.userId,
      title: params.title,
      description: params.description,
      priority: params.priority,
      category: params.category,
      dueAt: params.dueAt,
    );
  }
}

class CreateTaskParams {
  final String userId;
  final String title;
  final String description;
  final TaskPriority priority;
  final String category;
  final DateTime? dueAt;

  const CreateTaskParams({
    required this.userId,
    required this.title,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.category = '',
    this.dueAt,
  });
}
