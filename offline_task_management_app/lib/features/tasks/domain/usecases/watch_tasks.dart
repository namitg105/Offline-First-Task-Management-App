import '../entities/task.dart';
import '../entities/task_filter.dart';
import '../repository/task_repository.dart';

/// Does not implement [UseCase] because that contract returns a Future.
/// Forcing a stream into a Future-shaped interface would be obeying the
/// letter of the architecture while breaking its point.
class WatchTasks {
  final TaskRepository taskRepository;

  const WatchTasks(this.taskRepository);

  Stream<List<Task>> call(String userId, TaskFilter filter) =>
      taskRepository.watchTasks(userId, filter);
}
