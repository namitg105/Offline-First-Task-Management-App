import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/entities/task.dart';
import 'priority_chip.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppPalette.errorColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: onTap,
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (_) => onToggle(),
            shape: const CircleBorder(),
          ),
          title: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? AppPalette.greyColor : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PriorityChip(priority: task.priority),
                if (task.category.isNotEmpty)
                  Text('#${task.category}',
                      style: const TextStyle(
                          fontSize: 11, color: AppPalette.greyColor)),
                if (task.dueAt != null) _DueLabel(task: task),
              ],
            ),
          ),
          // The one bit of sync state the user genuinely benefits from
          // seeing: "this change is still only on this phone".
          trailing: task.isSynced
              ? null
              : const Tooltip(
                  message: 'Saved on this device, not yet synced',
                  child: Icon(Icons.cloud_off_outlined,
                      size: 18, color: AppPalette.greyColor),
                ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed from all your devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete',
                style: TextStyle(color: AppPalette.errorColor)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _DueLabel extends StatelessWidget {
  final Task task;

  const _DueLabel({required this.task});

  @override
  Widget build(BuildContext context) {
    final due = task.dueAt!;
    final text = '${due.day.toString().padLeft(2, '0')}/'
        '${due.month.toString().padLeft(2, '0')} '
        '${due.hour.toString().padLeft(2, '0')}:'
        '${due.minute.toString().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule,
            size: 12,
            color: task.isOverdue ? AppPalette.errorColor : AppPalette.greyColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color:
                task.isOverdue ? AppPalette.errorColor : AppPalette.greyColor,
            fontWeight: task.isOverdue ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
