import 'package:flutter/material.dart';

class XRayFindingsOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> findings;
  final double imageWidth;
  final double imageHeight;

  const XRayFindingsOverlay({
    super.key,
    required this.findings,
    required this.imageWidth,
    required this.imageHeight,
  });

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0.0;
  }

  String _safeTrimmedString(dynamic value) {
    try {
      if (value == null) return '';
      final text = value.toString();
      if (text == 'null' || text == 'undefined') return '';
      return text.trim();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: findings.map((finding) {
        final double x = (_toDouble(finding["x"]) / 1000) * imageWidth;
        final double y = (_toDouble(finding["y"]) / 1000) * imageHeight;
        final double width = (_toDouble(finding["width"]) / 1000) * imageWidth;
        final double height = (_toDouble(finding["height"]) / 1000) * imageHeight;
        final String label = _safeTrimmedString(finding["label"]);

        return Positioned(
          left: x.clamp(0, imageWidth),
          top: y.clamp(0, imageHeight),
          child: Container(
            width: width.clamp(24, imageWidth),
            height: height.clamp(24, imageHeight),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.shade700,
                width: 2.2,
              ),
              color: Colors.orange.withOpacity(0.08),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (label.isNotEmpty)
                  Positioned(
                    top: -28,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}