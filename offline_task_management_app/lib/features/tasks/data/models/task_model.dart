import 'dart:convert';

import '../../domain/entities/task.dart';

/// [Task] plus the two dialects it speaks: SQLite rows (integers for booleans and
/// timestamps) and Supabase JSON (ISO-8601 strings, no local-only columns).
///
/// Also carries [deletedAt], which the domain entity deliberately doesn't know:
/// a tombstone is a sync mechanism, not a business concept.
class TaskModel extends Task {
  final DateTime? deletedAt;

  const TaskModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    super.isCompleted,
    super.priority,
    super.category,
    super.dueAt,
    required super.createdAt,
    required super.updatedAt,
    super.isSynced,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// Returns the same task marked as a tombstone at [when].
  TaskModel copyWithDeleted(DateTime when) => TaskModel(
        id: id,
        userId: userId,
        title: title,
        description: description,
        isCompleted: isCompleted,
        priority: priority,
        category: category,
        dueAt: dueAt,
        createdAt: createdAt,
        updatedAt: when,
        isSynced: false,
        deletedAt: when,
      );

  factory TaskModel.fromEntity(Task task, {DateTime? deletedAt}) {
    return TaskModel(
      id: task.id,
      userId: task.userId,
      title: task.title,
      description: task.description,
      isCompleted: task.isCompleted,
      priority: task.priority,
      category: task.category,
      dueAt: task.dueAt,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      isSynced: task.isSynced,
      deletedAt: deletedAt,
    );
  }

  /// SQLite has no BOOLEAN and no DATETIME: booleans become 0/1 and instants
  /// become epoch milliseconds, which sort and compare correctly as integers.
  Map<String, Object?> toLocalRow() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'is_completed': isCompleted ? 1 : 0,
        'priority': priority.index,
        'category': category,
        'due_at': dueAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'is_synced': isSynced ? 1 : 0,
      };

  factory TaskModel.fromLocalRow(Map<String, Object?> row) {
    return TaskModel(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      description: (row['description'] as String?) ?? '',
      isCompleted: (row['is_completed'] as int? ?? 0) == 1,
      priority: TaskPriority.values[(row['priority'] as int? ?? 1)
          .clamp(0, TaskPriority.values.length - 1)],
      category: (row['category'] as String?) ?? '',
      dueAt: _fromMillis(row['due_at'] as int?),
      createdAt: _fromMillis(row['created_at'] as int?)!,
      updatedAt: _fromMillis(row['updated_at'] as int?)!,
      deletedAt: _fromMillis(row['deleted_at'] as int?),
      isSynced: (row['is_synced'] as int? ?? 0) == 1,
    );
  }

  /// `is_synced` is local bookkeeping and never leaves the device.
  /// Timestamps go up as UTC ISO-8601, which is what `timestamptz` expects.
  Map<String, dynamic> toRemoteJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'is_completed': isCompleted,
        'priority': priority.index,
        'category': category,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  factory TaskModel.fromRemoteJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      isCompleted: (json['is_completed'] as bool?) ?? false,
      priority: TaskPriority.values[((json['priority'] as int?) ?? 1)
          .clamp(0, TaskPriority.values.length - 1)],
      category: (json['category'] as String?) ?? '',
      dueAt: _parseIso(json['due_at']),
      createdAt: _parseIso(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseIso(json['updated_at']) ?? DateTime.now().toUtc(),
      deletedAt: _parseIso(json['deleted_at']),
      // It came from the server, so by definition it is in sync.
      isSynced: true,
    );
  }

  /// What gets frozen into the outbox `payload` column.
  String encodePayload() => jsonEncode(toRemoteJson());

  static TaskModel decodePayload(String payload) =>
      TaskModel.fromRemoteJson(jsonDecode(payload) as Map<String, dynamic>);

  // Equatable only compares what is listed in `props`. Without this override
  // a live task and its tombstone differ only by `deletedAt` and would
  // therefore compare as EQUAL, which would make the conflict merge and any
  // `buildWhen` skip an update they should have made.
  @override
  List<Object?> get props => [...super.props, deletedAt];

  static DateTime? _fromMillis(int? millis) =>
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);

  static DateTime? _parseIso(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
