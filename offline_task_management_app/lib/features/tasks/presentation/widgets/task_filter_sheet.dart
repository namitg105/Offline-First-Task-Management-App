import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/task.dart';
import '../../domain/entities/task_filter.dart';
import '../bloc/task_bloc.dart';
import 'priority_chip.dart';

Future<void> showTaskFilterSheet(BuildContext context) {
  final bloc = context.read<TaskBloc>();
  bloc.add(const TaskCategoriesRequested());

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The sheet is opened outside the bloc's widget subtree, so the provider
    // has to be handed across explicitly.
    builder: (_) => BlocProvider.value(value: bloc, child: const _FilterSheet()),
  );
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        final filter = state.filter;

        void apply(TaskFilter next) =>
            context.read<TaskBloc>().add(TaskFilterChanged(next));

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter & sort',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    if (filter.isActive)
                      TextButton(
                        onPressed: () => apply(
                          TaskFilter(query: filter.query, sort: filter.sort),
                        ),
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                const _SectionLabel('Status'),
                Wrap(
                  spacing: 8,
                  children: TaskCompletionFilter.values.map((value) {
                    return ChoiceChip(
                      label: Text(switch (value) {
                        TaskCompletionFilter.all => 'All',
                        TaskCompletionFilter.pending => 'Pending',
                        TaskCompletionFilter.completed => 'Completed',
                      }),
                      selected: filter.completion == value,
                      onSelected: (_) =>
                          apply(filter.copyWith(completion: value)),
                    );
                  }).toList(),
                ),

                const _SectionLabel('Priority'),
                Wrap(
                  spacing: 8,
                  children: TaskPriority.values.map((value) {
                    final selected = filter.priority == value;
                    return ChoiceChip(
                      label: Text(kPriorityStyles[value]!.label),
                      selected: selected,
                      selectedColor:
                          kPriorityStyles[value]!.color.withValues(alpha: 0.3),
                      // Tapping the selected chip clears it, so there is no
                      // separate "any priority" chip to explain.
                      onSelected: (_) => apply(
                        selected
                            ? filter.copyWith(clearPriority: true)
                            : filter.copyWith(priority: value),
                      ),
                    );
                  }).toList(),
                ),

                if (state.categories.isNotEmpty) ...[
                  const _SectionLabel('Category'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: state.categories.map((category) {
                      final selected = filter.category == category;
                      return ChoiceChip(
                        label: Text('#$category'),
                        selected: selected,
                        onSelected: (_) => apply(
                          selected
                              ? filter.copyWith(clearCategory: true)
                              : filter.copyWith(category: category),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const _SectionLabel('Sort by'),
                Wrap(
                  spacing: 8,
                  children: TaskSort.values.map((value) {
                    return ChoiceChip(
                      label: Text(switch (value) {
                        TaskSort.dueDate => 'Deadline',
                        TaskSort.priority => 'Priority',
                        TaskSort.createdAt => 'Newest',
                        TaskSort.title => 'Title',
                      }),
                      selected: filter.sort == value,
                      onSelected: (_) => apply(filter.copyWith(sort: value)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );
}