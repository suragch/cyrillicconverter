import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../lib/auth_middleware.dart';

void main() {
  group('Auth Middleware', () {
    late Middleware authMiddleware;
    late Handler protectedHandler;
    final successResponse = Response.ok('Access granted');
    // Must match the secret in auth_middleware.dart
    const secret = 'YOUR_POCKETBASE_JWT_SECRET'; 

    setUp(() {
      authMiddleware = createAuthMiddleware();
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
      final request = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'Bearer invalid-token',
      });
      final response = await protectedHandler(request);

      expect(response.statusCode, 401);
      expect(await response.readAsString(), contains('Invalid token'));
    });

    test('should return 200 and pass request if token is valid', () async {
      final jwt = JWT({'id': 'test_user_id'});
      final token = jwt.sign(SecretKey(secret));

      final request = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'Bearer $token',
      });
      final response = await protectedHandler(request);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'Access granted');
    });

    test('should add user_id to request context for valid token', () async {
      final jwt = JWT({'id': 'test_user_id'});
      final token = jwt.sign(SecretKey(secret));

      // Create a handler that inspects the context
      final inspectingHandler = authMiddleware((request) {
        final userId = request.context['user_id'];
        if (userId == 'test_user_id') {
          return Response.ok('Payload correct');
        }
        return Response.internalServerError(
            body: 'Payload incorrect or missing');
      });

      final request = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'Bearer $token',
      });

      final response = await inspectingHandler(request);
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'Payload correct');
    });

    test('should enforce moderator role if required', () async {
      final moderatorMiddleware = createAuthMiddleware(requiredRole: 'moderator');
      final handler = moderatorMiddleware((request) => successResponse);

      // User without moderator role
      final userJwt = JWT({'id': 'user', 'is_moderator': false});
      final userToken = userJwt.sign(SecretKey(secret));
      
      final userRequest = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'Bearer $userToken',
      });
      final userResponse = await handler(userRequest);
      expect(userResponse.statusCode, 403);

      // User with moderator role
      final modJwt = JWT({'id': 'mod', 'is_moderator': true});
      final modToken = modJwt.sign(SecretKey(secret));

      final modRequest = Request('GET', Uri.parse('http://localhost/'), headers: {
        'authorization': 'Bearer $modToken',
      });
      final modResponse = await handler(modRequest);
      expect(modResponse.statusCode, 200);
    });
  });
}