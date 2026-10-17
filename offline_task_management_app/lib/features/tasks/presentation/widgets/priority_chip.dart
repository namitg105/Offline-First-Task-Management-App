import 'package:flutter/material.dart';

import '../../domain/entities/task.dart';

const Map<TaskPriority, ({String label, Color color})> kPriorityStyles = {
  TaskPriority.low: (label: 'Low', color: Color(0xFF6B8AFD)),
  TaskPriority.medium: (label: 'Medium', color: Color(0xFFF0A14B)),
  TaskPriority.high: (label: 'High', color: Color(0xFFF05D5D)),
};

class PriorityChip extends StatelessWidget {
  final TaskPriority priority;

  const PriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final style = kPriorityStyles[priority]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.5)),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
