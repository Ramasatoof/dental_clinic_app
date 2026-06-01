class StatsUtils {
  static double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0.0;
  }

  static double sumField(
    Iterable<dynamic> docs,
    String fieldName,
  ) {
    double total = 0.0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += toDouble(data[fieldName]);
    }

    return total;
  }

  static double calculateInventoryValue(Iterable<dynamic> materialDocs) {
    double inventoryValue = 0.0;

    for (final doc in materialDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final qty = toDouble(data['quantity']);
      final price = toDouble(data['price']);
      inventoryValue += qty * price;
    }

    return inventoryValue;
  }

  static int countLowStockMaterials(Iterable<dynamic> materialDocs) {
    int lowStock = 0;

    for (final doc in materialDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final qty = toDouble(data['quantity']);
      final minQty = toDouble(data['min_quantity']);

      if (qty <= minQty) lowStock++;
    }

    return lowStock;
  }
}