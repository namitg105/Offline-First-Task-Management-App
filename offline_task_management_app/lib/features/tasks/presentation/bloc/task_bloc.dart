import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/task_filter.dart';
import '../../domain/usecases/create_task.dart';
import '../../domain/usecases/delete_task.dart';
import '../../domain/usecases/get_task_categories.dart';
import '../../domain/usecases/toggle_task_completion.dart';
import '../../domain/usecases/update_task.dart';
import '../../domain/usecases/watch_tasks.dart';

part 'task_event.dart';
part 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final WatchTasks _watchTasks;
  final CreateTask _createTask;
  final UpdateTask _updateTask;
  final ToggleTaskCompletion _toggleTaskCompletion;
  final DeleteTask _deleteTask;
  final GetTaskCategories _getTaskCategories;

  StreamSubscription<List<Task>>? _subscription;
  String? _userId;

  TaskBloc({
    required WatchTasks watchTasks,
    required CreateTask createTask,
    required UpdateTask updateTask,
    required ToggleTaskCompletion toggleTaskCompletion,
    required DeleteTask deleteTask,
    required GetTaskCategories getTaskCategories,
  })  : _watchTasks = watchTasks,
        _createTask = createTask,
        _updateTask = updateTask,
        _toggleTaskCompletion = toggleTaskCompletion,
        _deleteTask = deleteTask,
        _getTaskCategories = getTaskCategories,
        super(const TaskState()) {
    on<TasksSubscriptionRequested>(_onTasksSubscriptionRequested);
    on<TaskFilterChanged>(_onTaskFilterChanged);
    on<TaskCategoriesRequested>(_onTaskCategoriesRequested);
    on<TasksUpdated>(_onTasksUpdated);
    on<TasksLoadFailed>(_onTasksLoadFailed);
    on<TaskCreationSubmitted>(_onTaskCreationSubmitted);
    on<TaskEditSubmitted>(_onTaskEditSubmitted);
    on<TaskCompletionToggled>(_onTaskCompletionToggled);
    on<TaskDeletionRequested>(_onTaskDeletionRequested);
    on<TaskErrorDismissed>(_onTaskErrorDismissed);
  }

  void _onTasksSubscriptionRequested(
    TasksSubscriptionRequested event,
    Emitter<TaskState> emit,
  ) {
    _userId = event.userId;
    emit(state.copyWith(status: TaskStatus.loading));
    _resubscribe(state.filter);
    add(const TaskCategoriesRequested());
  }

  void _onTaskFilterChanged(TaskFilterChanged event, Emitter<TaskState> emit) {
    if (event.filter == state.filter) return;
    emit(state.copyWith(filter: event.filter));
    _resubscribe(event.filter);
  }

  /// Tear the old query down and start a new one.
  ///
  /// The subscription is managed by hand rather than with `emit.forEach`
  /// because the query itself changes whenever the filter changes, and
  /// `emit.forEach` owns its handler until the stream ends.
  void _resubscribe(TaskFilter filter) {
    final userId = _userId;
    if (userId == null) return;

    _subscription?.cancel();
    _subscription = _watchTasks(userId, filter).listen(
      (tasks) => add(TasksUpdated(tasks)),
      onError: (Object error) =>
          add(TasksLoadFailed('Could not read your tasks: $error')),
    );
  }

  Future<void> _onTaskCategoriesRequested(
    TaskCategoriesRequested event,
    Emitter<TaskState> emit,
  ) async {
    final userId = _userId;
    if (userId == null) return;
    final result = await _getTaskCategories(userId);
    result.fold(
      (_) {}, // a missing category list is not worth bothering the user with
      (categories) => emit(state.copyWith(categories: categories)),
    );
  }

  // Writes never emit the list themselves. They write to SQLite, the database
  // notifies, the subscription above emits. One path in, one path out — the
  // screen can never disagree with the database.

  Future<void> _onTaskCreationSubmitted(
    TaskCreationSubmitted event,
    Emitter<TaskState> emit,
  ) async {
    final result = await _createTask(CreateTaskParams(
      userId: event.userId,
      title: event.title,
      description: event.description,
      priority: event.priority,
      category: event.category,
      dueAt: event.dueAt,
    ));
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) => add(TaskCategoriesRequested()),
    );
  }

  Future<void> _onTaskEditSubmitted(
    TaskEditSubmitted event,
    Emitter<TaskState> emit,
  ) async {
    final result = await _updateTask(event.task);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) => add(TaskCategoriesRequested()),
    );
  }

  Future<void> _onTaskCompletionToggled(
    TaskCompletionToggled event,
    Emitter<TaskState> emit,
  ) async {
    final result = await _toggleTaskCompletion(event.task);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {},
    );
  }

  Future<void> _onTaskDeletionRequested(
    TaskDeletionRequested event,
    Emitter<TaskState> emit,
  ) async {
    final result = await _deleteTask(event.taskId);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {},
    );
  }

  void _onTasksUpdated(TasksUpdated event, Emitter<TaskState> emit) {
    emit(state.copyWith(
      status: TaskStatus.success,
      tasks: event.tasks,
      clearError: true,
    ));
  }

  void _onTasksLoadFailed(TasksLoadFailed event, Emitter<TaskState> emit) {
    emit(state.copyWith(
      status: TaskStatus.failure,
      errorMessage: event.message,
    ));
  }

  void _onTaskErrorDismissed(
    TaskErrorDismissed event,
    Emitter<TaskState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}