import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppPalette.borderColor, thickness: 1.5)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR', style: TextStyle(color: AppPalette.greyColor)),
        ),
        Expanded(child: Divider(color: AppPalette.borderColor, thickness: 1.5)),
      ],
    );
  }
}
