import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../lib/auth_middleware.dart';
import '../lib/jwt_service.dart';

// A mock implementation of JwtService to avoid real network calls.
class MockJwtService implements JwtService {
  @override
  final String pocketBaseUrl;
  String? _tokenToAccept;

  MockJwtService({this.pocketBaseUrl = 'mock_url'});

  void setTokenToAccept(String? token) {
    _tokenToAccept = token;
  }

  @override
  Future<JWT?> verifyToken(String token) async {
    if (token == _tokenToAccept) {
      // Return a dummy JWT object for valid tokens
      return JWT({'id': 'test_user_id'});
    }
    // Return null for invalid tokens
    return null;
  }
}

void main() {
  group('Auth Middleware', () {
    late MockJwtService mockJwtService;
    late Middleware authMiddleware;
    late Handler protectedHandler;
    final successResponse = Response.ok('Access granted');

    setUp(() {
      mockJwtService = MockJwtService();
      authMiddleware = createAuthMiddleware(mockJwtService);
      // A simple handler that runs if authentication succeeds
      protectedHandler = authMiddleware((request) => successResponse);
    });

    test('should return 401 if Authorization header is missing', () async {
      final request = Request('GET', Uri.parse('http://localhost/'));
      final response = await protectedHandler(request);

      expect(response.statusCode, 401);
      expect(await response.readAsString(),
          'Missing or invalid Authorization header.');
    });

    test('should return 401 if token is not a Bearer token', () async {
      final request = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'InvalidScheme my-token',
      });
      final response = await protectedHandler(request);

      expect(response.statusCode, 401);
      expect(await response.readAsString(),
          'Missing or invalid Authorization header.');
    });

    test('should return 401 if token is invalid', () async {
      mockJwtService.setTokenToAccept('valid-token');
      final request = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'Bearer invalid-token',
      });
      final response = await protectedHandler(request);

      expect(response.statusCode, 401);
      expect(await response.readAsString(), 'Invalid or expired token.');
    });

    test('should return 200 and pass request if token is valid', () async {
      const validToken = 'my-valid-token';
      mockJwtService.setTokenToAccept(validToken);

      final request = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'Bearer $validToken',
      });
      final response = await protectedHandler(request);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'Access granted');
    });

    test('should add jwt_payload to request context for valid token', () async {
      const validToken = 'my-valid-token';
      mockJwtService.setTokenToAccept(validToken);

      // Create a handler that inspects the context
      final inspectingHandler = authMiddleware((request) {
        final payload = request.context['jwt_payload'] as Map<String, dynamic>?;
        if (payload != null && payload['id'] == 'test_user_id') {
          return Response.ok('Payload correct');
        }
        return Response.internalServerError(
            body: 'Payload incorrect or missing');
      });

      final request = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'Bearer $validToken',
      });

      final response = await inspectingHandler(request);
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'Payload correct');
    });
  });
}
