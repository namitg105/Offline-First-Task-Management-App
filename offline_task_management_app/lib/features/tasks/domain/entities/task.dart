import 'package:equatable/equatable.dart';

enum TaskPriority { low, medium, high }

/// A task, as the business cares about it. Pure Dart.
///
/// Deliberately absent: `deletedAt`. A tombstone is a synchronisation detail; the
/// domain only knows tasks that exist.
///
/// Deliberately present: [isSynced]. The user can see it ("not backed up yet"), so
/// it is part of a task's meaning in an offline-first app.
class Task extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String description;
  final bool isCompleted;
  final TaskPriority priority;
  final String category;
  final DateTime? dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    this.category = '',
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  bool get isOverdue =>
      !isCompleted &&
      dueAt != null &&
      dueAt!.isBefore(DateTime.now());

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    bool? isCompleted,
    TaskPriority? priority,
    String? category,
    DateTime? dueAt,
    bool clearDueAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, title, description, isCompleted,
        priority, category, dueAt, createdAt, updatedAt, isSynced,
      ];
}
