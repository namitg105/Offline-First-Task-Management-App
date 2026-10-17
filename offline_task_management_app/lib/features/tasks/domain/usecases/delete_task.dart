import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repository/task_repository.dart';

class DeleteTask implements UseCase<Unit, String> {
  final TaskRepository taskRepository;

  const DeleteTask(this.taskRepository);

  @override
  Future<Either<Failure, Unit>> call(String taskId) =>
      taskRepository.deleteTask(taskId);
}
