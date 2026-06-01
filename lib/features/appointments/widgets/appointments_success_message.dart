import 'package:flutter/material.dart';

class AppointmentsSuccessMessage extends StatelessWidget {
  final String? message;
  final BoxConstraints constraints;

  const AppointmentsSuccessMessage({
    super.key,
    required this.message,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    final bool isMobile = constraints.maxWidth < 700;

    return Positioned(
      top: 24,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: isMobile ? double.infinity : 520,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}