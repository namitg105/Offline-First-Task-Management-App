import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/task_filter.dart';
import '../bloc/task_bloc.dart';
import 'task_filter_sheet.dart';

class TaskSearchBar extends StatefulWidget {
  const TaskSearchBar({super.key});

  @override
  State<TaskSearchBar> createState() => _TaskSearchBarState();
}

class _TaskSearchBarState extends State<TaskSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Debounced so typing "assignment" runs one query, not ten. Each keystroke
  /// would otherwise cancel and restart a database subscription.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final bloc = context.read<TaskBloc>();
      bloc.add(TaskFilterChanged(bloc.state.filter.copyWith(query: value)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search tasks',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          BlocBuilder<TaskBloc, TaskState>(
            buildWhen: (previous, current) =>
                previous.filter != current.filter ||
                previous.categories != current.categories,
            builder: (context, state) {
              final count = state.filter.activeCount;
              return Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: IconButton.filledTonal(
                  tooltip: 'Filter and sort',
                  icon: const Icon(Icons.tune),
                  onPressed: () => showTaskFilterSheet(context),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
