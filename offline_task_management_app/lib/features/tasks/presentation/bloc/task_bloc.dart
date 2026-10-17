import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/task.dart';
import '../../domain/usecases/create_task.dart';
import '../../domain/usecases/delete_task.dart';
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

  TaskBloc({
    required WatchTasks watchTasks,
    required CreateTask createTask,
    required UpdateTask updateTask,
    required ToggleTaskCompletion toggleTaskCompletion,
    required DeleteTask deleteTask,
  })  : _watchTasks = watchTasks,
        _createTask = createTask,
        _updateTask = updateTask,
        _toggleTaskCompletion = toggleTaskCompletion,
        _deleteTask = deleteTask,
        super(const TaskState()) {
    on<TasksSubscriptionRequested>(_onSubscriptionRequested);
    on<TaskCreated>(_onCreated);
    on<TaskEdited>(_onEdited);
    on<TaskCompletionToggled>(_onToggled);
    on<TaskDeleted>(_onDeleted);
    on<TaskErrorDismissed>(
      (_, emit) => emit(state.copyWith(clearError: true)),
    );
  }

  /// Subscribes to the local database once and then never polls again.
  ///
  /// Writes below do NOT emit the new list themselves. They write to SQLite,
  /// the database notifies its listeners, and this subscription emits. One
  /// path in, one path out — the screen can never disagree with the database.
  Future<void> _onSubscriptionRequested(
    TasksSubscriptionRequested event,
    Emitter<TaskState> emit,
  ) async {
    emit(state.copyWith(status: TaskStatus.loading));
    await emit.forEach<List<Task>>(
      _watchTasks(event.userId),
      onData: (tasks) => state.copyWith(
        status: TaskStatus.success,
        tasks: tasks,
        clearError: true,
      ),
      onError: (error, _) => state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Could not read your tasks: $error',
      ),
    );
  }

  Future<void> _onCreated(TaskCreated event, Emitter<TaskState> emit) async {
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
      (_) {}, // the stream will deliver the new list
    );
  }

  Future<void> _onEdited(TaskEdited event, Emitter<TaskState> emit) async {
    final result = await _updateTask(event.task);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {},
    );
  }

  Future<void> _onToggled(
    TaskCompletionToggled event,
    Emitter<TaskState> emit,
  ) async {
    final result = await _toggleTaskCompletion(event.task);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {},
    );
  }

  Future<void> _onDeleted(TaskDeleted event, Emitter<TaskState> emit) async {
    final result = await _deleteTask(event.taskId);
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {},
    );
  }
}
