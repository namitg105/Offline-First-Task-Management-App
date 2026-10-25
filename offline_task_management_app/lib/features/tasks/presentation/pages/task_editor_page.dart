import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/blocs/app_user/app_user_bloc.dart';
import '../../../../core/utils/show_snackbar.dart';
import '../../domain/entities/task.dart';
import '../bloc/task_bloc.dart';
import '../widgets/priority_chip.dart';

/// One page for both "new task" and "edit task": they differ only in whether
/// [task] is null.
class TaskEditorPage extends StatefulWidget {
  final Task? task;
  static Route<void> route({Task? task}) {
    return MaterialPageRoute(builder: (_) => TaskEditorPage(task: task));
  }

  const TaskEditorPage({super.key, this.task});

  bool get isEditing => task != null;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late TaskPriority _priority;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController =
        TextEditingController(text: task?.description ?? '');
    _categoryController = TextEditingController(text: task?.category ?? '');
    _priority = task?.priority ?? TaskPriority.medium;
    _dueAt = task?.dueAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? now),
    );
    if (!mounted) return;

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final userState = context.read<AppUserBloc>().state;
    if (userState is! AppUserLoggedIn) {
      showSnackBar(context, 'You are signed out. Please log in again.');
      return;
    }

    final bloc = context.read<TaskBloc>();
    if (widget.isEditing) {
      bloc.add(TaskEditSubmitted(
        widget.task!.copyWith(
          title: _titleController.text,
          description: _descriptionController.text,
          priority: _priority,
          category: _categoryController.text,
          dueAt: _dueAt,
          clearDueAt: _dueAt == null,
        ),
      ));
    } else {
      bloc.add(TaskCreationSubmitted(
        userId: userState.user.id,
        title: _titleController.text,
        description: _descriptionController.text,
        priority: _priority,
        category: _categoryController.text,
        dueAt: _dueAt,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit task' : 'New task'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: !widget.isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What needs doing?'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'A task needs a title'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(hintText: 'Notes (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                hintText: 'Category or tag, e.g. college (optional)',
              ),
            ),
            const SizedBox(height: 22),
            const Text('Priority',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: TaskPriority.values.map((priority) {
                final selected = priority == _priority;
                return ChoiceChip(
                  label: Text(kPriorityStyles[priority]!.label),
                  selected: selected,
                  selectedColor:
                      kPriorityStyles[priority]!.color.withValues(alpha: 0.3),
                  onSelected: (_) => setState(() => _priority = priority),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            const Text('Deadline',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    onPressed: _pickDueDate,
                    label: Text(
                      _dueAt == null
                          ? 'No deadline'
                          : '${_dueAt!.day}/${_dueAt!.month}/${_dueAt!.year}'
                              '  ${_dueAt!.hour.toString().padLeft(2, '0')}:'
                              '${_dueAt!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                if (_dueAt != null)
                  IconButton(
                    tooltip: 'Clear deadline',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _dueAt = null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
