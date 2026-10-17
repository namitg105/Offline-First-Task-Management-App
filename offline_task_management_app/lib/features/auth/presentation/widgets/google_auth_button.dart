import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

class GoogleAuthButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleAuthButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.g_mobiledata, size: 32),
      label: const Text(
        'Continue with Google',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        fixedSize: const Size(395, 55),
        foregroundColor: AppPalette.whiteColor,
        side: const BorderSide(color: AppPalette.borderColor, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    );
  }
}
