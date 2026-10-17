// fpdart exports a `Task` of its own (its lazy-future monad). Our domain
// entity is also called Task, so the name is hidden here rather than
// renaming the entity — Task is the right word for what it models.
import 'package:fpdart/fpdart.dart' hide Task;

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repository/task_repository.dart';

class UpdateTask implements UseCase<Task, Task> {
  final TaskRepository taskRepository;

  const UpdateTask(this.taskRepository);

  @override
  Future<Either<Failure, Task>> call(Task task) =>
      taskRepository.updateTask(task);
}
