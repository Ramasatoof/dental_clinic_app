import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class XRayNewAnalysisButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final bool compact;

  const XRayNewAnalysisButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.add_box_outlined,
        color: lapisBlue,
        size: 18,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: lapisBlue,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12.5 : 13,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: 12,
        ),
        side: BorderSide(color: lapisBlue.withOpacity(0.18)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: lapisBlue.withOpacity(0.03),
      ),
    );
  }
}