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
  final TaskFilter filter;
  final List<String> categories;
  final String? errorMessage;

  const TaskState({
    this.status = TaskStatus.initial,
    this.tasks = const [],
    this.filter = const TaskFilter(),
    this.categories = const [],
    this.errorMessage,
  });

  /// Truly empty: no tasks at all.
  bool get isEmpty =>
      status == TaskStatus.success && tasks.isEmpty && !filter.isActive;

  /// Empty only because of the current search or filters — a different
  /// message, because "add your first task" is unhelpful when the user has
  /// forty tasks and a typo in the search box.
  bool get isFilteredEmpty =>
      status == TaskStatus.success && tasks.isEmpty && filter.isActive;

  TaskState copyWith({
    TaskStatus? status,
    List<Task>? tasks,
    TaskFilter? filter,
    List<String>? categories,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TaskState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, tasks, filter, categories, errorMessage];
}
