import '../entities/task.dart';
import '../entities/task_filter.dart';
import '../repository/task_repository.dart';

/// Doesn't implement [UseCase] because that contract returns a Future, and a
/// stream doesn't fit it.
class WatchTasks {
  final TaskRepository taskRepository;

  const WatchTasks(this.taskRepository);

  Stream<List<Task>> call(String userId, TaskFilter filter) =>
      taskRepository.watchTasks(userId, filter);
}
