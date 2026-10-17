part of 'task_bloc.dart';

enum TaskStatus { initial, loading, success, failure }

/// One state class with a status field, rather than a sealed hierarchy.
///
/// Reason: a sealed `TaskFailure` state would have to throw away [tasks], so
/// a failed *write* would blank the user's list. Here the list survives every
/// status change, which is what "preserve state during navigation" and
/// "useful loading, empty and error states" actually require.
class TaskState extends Equatable {
  final TaskStatus status;
  final List<Task> tasks;
  final String? errorMessage;

  const TaskState({
    this.status = TaskStatus.initial,
    this.tasks = const [],
    this.errorMessage,
  });

  bool get isEmpty => status == TaskStatus.success && tasks.isEmpty;

  TaskState copyWith({
    TaskStatus? status,
    List<Task>? tasks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TaskState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, tasks, errorMessage];
}
