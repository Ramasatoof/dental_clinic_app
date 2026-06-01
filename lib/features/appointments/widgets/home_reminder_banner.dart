import 'dart:math';

import 'package:flutter/material.dart';

class HomeReminderBanner extends StatelessWidget {
  final bool isArabic;
  final String? patientName;
  final BoxConstraints constraints;
  final VoidCallback onClose;

  const HomeReminderBanner({
    super.key,
    required this.isArabic,
    required this.patientName,
    required this.constraints,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (patientName == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      right: 20,
      left: constraints.maxWidth < 500 ? 20 : null,
      child: Container(
        width: constraints.maxWidth < 500
            ? null
            : min(320, constraints.maxWidth - 40),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black26,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isArabic
                    ? "المريض $patientName موعده بعد نص ساعة"
                    : "Patient $patientName has an appt in 30 mins",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}