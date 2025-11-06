// backend/api/lib/jwt_service.dart
import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

class JwtService {
  String? _pocketBasePublicKey;
  final String pocketBaseUrl;

  JwtService(this.pocketBaseUrl);

  Future<void> _fetchPublicKey() async {
    try {
      final response = await http.get(Uri.parse('$pocketBaseUrl/api/settings'));
      if (response.statusCode == 200) {
        final settings = jsonDecode(response.body) as Map<String, dynamic>;
        // The key is nested within the meta object
        _pocketBasePublicKey = settings['meta']['publicKey'] as String;
      } else {
        throw Exception('Failed to fetch PocketBase public key');
      }
    } catch (e) {
      print('Error fetching public key: $e');
      // In a real app, handle this more robustly (e.g., retry logic)
      rethrow;
    }
  }

  Future<JWT?> verifyToken(String token) async {
    if (_pocketBasePublicKey == null) {
      await _fetchPublicKey();
    }

    if (_pocketBasePublicKey == null) {
        throw Exception('Public key is not available for verification.');
    }

    try {
      // Verify the token with the fetched public key
      final jwt = JWT.verify(
        token,
        RSAPublicKey(_pocketBasePublicKey!),
      );
      return jwt;
    } on JWTExpiredException {
      print('JWT expired');
      return null;
    } on JWTException catch (e) {
      print('JWT error: ${e.message}');
      return null;
    }
  }
}