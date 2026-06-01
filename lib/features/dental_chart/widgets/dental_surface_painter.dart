import 'dart:math' as math;

import 'package:flutter/material.dart';

class DentalSurfacePainter extends CustomPainter {
  final Map<String, bool> surfaces;
  final bool isDark;

  DentalSurfacePainter(this.surfaces, {this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.45;
    final strokeColor = isDark ? Colors.white70 : Colors.black87;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = const Color.fromARGB(255, 128, 0, 128)
      ..style = PaintingStyle.fill;

    Path buildPath(double startAngle, double sweepAngle) {
      final path = Path();
      path.arcTo(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false);
      path.arcTo(Rect.fromCircle(center: center, radius: innerRadius), startAngle + sweepAngle, -sweepAngle, false);
      path.close();
      return path;
    }

    final paths = {
      'right': buildPath(-math.pi / 4, math.pi / 2),
      'bottom': buildPath(math.pi / 4, math.pi / 2),
      'left': buildPath(math.pi * 3 / 4, math.pi / 2),
      'top': buildPath(math.pi * 5 / 4, math.pi / 2),
    };

    paths.forEach((key, path) {
      if (surfaces[key] == true) canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    });

    final centerPath = Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    if (surfaces['center'] == true) canvas.drawPath(centerPath, fillPaint);
    canvas.drawPath(centerPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
