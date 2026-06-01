import 'package:cloud_firestore/cloud_firestore.dart';

class CustomLayoutAccessData {
  final String role;
  final Map<String, dynamic> permissions;

  const CustomLayoutAccessData({
    required this.role,
    required this.permissions,
  });

  factory CustomLayoutAccessData.empty() {
    return const CustomLayoutAccessData(
      role: '',
      permissions: <String, dynamic>{},
    );
  }
}

class CustomLayoutAccessService {
  const CustomLayoutAccessService._();

  static Future<CustomLayoutAccessData> loadUserAccess(String username) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return CustomLayoutAccessData.empty();
      }

      final data = query.docs.first.data();
      final rawPermissions = data['permissions'];

      return CustomLayoutAccessData(
        role: (data['role'] ?? '').toString(),
        permissions: rawPermissions is Map
            ? Map<String, dynamic>.from(rawPermissions)
            : <String, dynamic>{},
      );
    } catch (_) {
      return CustomLayoutAccessData.empty();
    }
  }
}
