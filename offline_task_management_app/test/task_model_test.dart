import 'package:flutter_test/flutter_test.dart';
import 'package:offline_task_management_app/features/tasks/data/models/task_model.dart';
import 'package:offline_task_management_app/features/tasks/domain/entities/task.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1760000000000);

  TaskModel sample({DateTime? deletedAt}) => TaskModel(
        id: 'b3f1c2d4-0000-4000-8000-000000000001',
        userId: 'user-1',
        title: 'Finish DBMS answer key',
        description: 'Units 3 and 4',
        isCompleted: false,
        priority: TaskPriority.high,
        category: 'college',
        dueAt: now.add(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
        isSynced: false,
        deletedAt: deletedAt,
      );

  group('TaskModel', () {
    test('survives a round trip through a SQLite row', () {
      final restored = TaskModel.fromLocalRow(sample().toLocalRow());

      expect(restored.id, sample().id);
      expect(restored.title, sample().title);
      expect(restored.priority, TaskPriority.high);
      expect(restored.isCompleted, isFalse);
      expect(restored.dueAt, sample().dueAt);
      expect(restored.updatedAt, sample().updatedAt);
    });

    test('survives a round trip through Supabase JSON', () {
      final restored = TaskModel.fromRemoteJson(sample().toRemoteJson());

      expect(restored.id, sample().id);
      expect(restored.category, 'college');
      expect(restored.updatedAt.toUtc(), sample().updatedAt.toUtc());
      // Anything that came back from the server is by definition in sync.
      expect(restored.isSynced, isTrue);
    });

    test('never sends local-only bookkeeping to the server', () {
      expect(sample().toRemoteJson().containsKey('is_synced'), isFalse);
    });

    test('copyWithDeleted produces a tombstone that is out of sync', () {
      final tombstone = sample().copyWithDeleted(now);

      expect(tombstone.isDeleted, isTrue);
      expect(tombstone.deletedAt, now);
      expect(tombstone.updatedAt, now);
      expect(tombstone.isSynced, isFalse);
    });

    test('outbox payload encodes and decodes', () {
      final decoded = TaskModel.decodePayload(sample().encodePayload());
      expect(decoded.id, sample().id);
      expect(decoded.title, sample().title);
    });
  });
}
