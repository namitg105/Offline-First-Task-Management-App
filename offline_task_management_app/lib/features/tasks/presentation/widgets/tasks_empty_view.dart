import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

class TasksEmptyView extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const TasksEmptyView({
    super.key,
    this.title = 'Nothing here yet',
    this.subtitle = 'Tap + to add your first task.\nIt works offline too.',
    this.icon = Icons.check_circle_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppPalette.greyColor),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppPalette.greyColor),
            ),
          ],
        ),
      ),
    );
  }
}
