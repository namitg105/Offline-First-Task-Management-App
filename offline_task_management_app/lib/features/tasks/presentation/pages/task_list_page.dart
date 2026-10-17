import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/cubits/app_user/app_user_cubit.dart';
import '../../../../core/common/widgets/loader.dart';
import '../../../../core/utils/show_snackbar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/task_bloc.dart';
import '../widgets/task_card.dart';
import '../widgets/tasks_empty_view.dart';
import 'task_editor_page.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  @override
  void initState() {
    super.initState();
    final userState = context.read<AppUserCubit>().state;
    if (userState is AppUserLoggedIn) {
      // Subscribe once. From here on the database pushes updates to us.
      context.read<TaskBloc>().add(TasksSubscriptionRequested(userState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(AuthLogout()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, TaskEditorPage.route()),
        child: const Icon(Icons.add),
      ),
      body: BlocConsumer<TaskBloc, TaskState>(
        listenWhen: (previous, current) =>
            current.errorMessage != null &&
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          showSnackBar(context, state.errorMessage!);
          context.read<TaskBloc>().add(TaskErrorDismissed());
        },
        builder: (context, state) {
          if (state.status == TaskStatus.initial ||
              (state.status == TaskStatus.loading && state.tasks.isEmpty)) {
            return const Loader();
          }

          if (state.status == TaskStatus.failure && state.tasks.isEmpty) {
            return TasksEmptyView(
              icon: Icons.error_outline,
              title: 'Could not load your tasks',
              subtitle: state.errorMessage ?? 'Please restart the app.',
            );
          }

          if (state.isEmpty) return const TasksEmptyView();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
            itemCount: state.tasks.length,
            itemBuilder: (context, index) {
              final task = state.tasks[index];
              return TaskCard(
                task: task,
                onToggle: () =>
                    context.read<TaskBloc>().add(TaskCompletionToggled(task)),
                onTap: () => Navigator.push(
                  context,
                  TaskEditorPage.route(task: task),
                ),
                onDelete: () =>
                    context.read<TaskBloc>().add(TaskDeleted(task.id)),
              );
            },
          );
        },
      ),
    );
  }
}
