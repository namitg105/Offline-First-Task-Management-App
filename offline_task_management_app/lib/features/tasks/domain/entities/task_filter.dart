import 'package:equatable/equatable.dart';

import 'task.dart';

enum TaskCompletionFilter { all, pending, completed }

enum TaskSort { dueDate, priority, createdAt, title }

/// Everything the list screen can narrow or reorder by, as one value, so adding a
/// filter later changes no method signatures.
class TaskFilter extends Equatable {
  final String query;
  final TaskCompletionFilter completion;
  final TaskPriority? priority;
  final String? category;
  final TaskSort sort;

  const TaskFilter({
    this.query = '',
    this.completion = TaskCompletionFilter.all,
    this.priority,
    this.category,
    this.sort = TaskSort.dueDate,
  });

  bool get isActive =>
      query.isNotEmpty ||
      completion != TaskCompletionFilter.all ||
      priority != null ||
      (category != null && category!.isNotEmpty);

  /// Number of narrowing rules in force, for the badge on the filter button.
  int get activeCount => [
        completion != TaskCompletionFilter.all,
        priority != null,
        category != null && category!.isNotEmpty,
      ].where((active) => active).length;

  TaskFilter copyWith({
    String? query,
    TaskCompletionFilter? completion,
    TaskPriority? priority,
    bool clearPriority = false,
    String? category,
    bool clearCategory = false,
    TaskSort? sort,
  }) {
    return TaskFilter(
      query: query ?? this.query,
      completion: completion ?? this.completion,
      priority: clearPriority ? null : (priority ?? this.priority),
      category: clearCategory ? null : (category ?? this.category),
      sort: sort ?? this.sort,
    );
  }

  @override
  List<Object?> get props => [query, completion, priority, category, sort];
}
