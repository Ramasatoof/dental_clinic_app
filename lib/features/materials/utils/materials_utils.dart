class MaterialsUtils {
  static double safeDouble(dynamic value, [double fallback = 0]) {
    double? parsed;

    if (value is num) {
      parsed = value.toDouble();
    } else if (value != null) {
      parsed = double.tryParse(value.toString().trim());
    }

    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      return fallback;
    }

    return parsed;
  }

  static double safePositiveDimension(dynamic value, double fallback) {
    final parsed = safeDouble(value, fallback);
    if (parsed <= 0) return fallback;
    return parsed;
  }

  static String safeMoney(dynamic value, {int decimals = 2}) {
    return safeDouble(value).toStringAsFixed(decimals);
  }

  static bool isBadNumber(dynamic value) {
    if (value == null) return true;

    if (value is num) {
      final parsed = value.toDouble();
      return parsed.isNaN || parsed.isInfinite || parsed < 0;
    }

    final parsed = double.tryParse(value.toString().trim());
    return parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0;
  }

  static String formatNumber(double value) {
    final safeValue = safeDouble(value);

    if (safeValue == safeValue.roundToDouble()) {
      return safeValue.toStringAsFixed(0);
    }

    return safeValue.toStringAsFixed(2);
  }
}