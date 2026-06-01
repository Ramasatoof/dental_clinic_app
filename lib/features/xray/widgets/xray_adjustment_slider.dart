import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class XRayAdjustmentSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final dynamic value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final bool isArabic;
  final Color softFill;
  final Color borderColor;
  final Color textSecondary;

  const XRayAdjustmentSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.isArabic,
    required this.softFill,
    required this.borderColor,
    required this.textSecondary,
  });

  String _safeFixed(dynamic value, {int fractionDigits = 2}) {
    if (value is num) {
      final parsed = value.toDouble();
      if (parsed.isNaN || parsed.isInfinite) return "0.00";
      return parsed.toStringAsFixed(fractionDigits);
    }
    return "0.00";
  }

  @override
  Widget build(BuildContext context) {
    final double safeValue = value is num ? value.toDouble() : min;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: softFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: lapisBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: lapisBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Text(
                _safeFixed(safeValue),
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: safeValue.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: lapisBlue,
              inactiveColor: lapisBlue.withOpacity(0.15),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}