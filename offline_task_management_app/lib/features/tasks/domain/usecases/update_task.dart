import 'package:fpdart/fpdart.dart';

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
