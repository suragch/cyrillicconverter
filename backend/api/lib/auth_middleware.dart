// backend/api/lib/auth_middleware.dart

import 'package:shelf/shelf.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// Assume you have a way to get your JWT secret
const jwtSecret = 'YOUR_POCKETBASE_JWT_SECRET'; // IMPORTANT: Load from .env

Middleware createAuthMiddleware({String? requiredRole}) {
  return (Handler innerHandler) {
    return (Request request) {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized('Missing or invalid Authorization header.');
      }

      final token = authHeader.substring(7);

      try {
        // Verify the token
        final jwt = JWT.verify(token, SecretKey(jwtSecret));
        final payload = jwt.payload as Map<String, dynamic>;

        // Role check
        if (requiredRole == 'moderator') {
          // PocketBase JWTs often contain custom fields in the payload.
          // We check for the `is_moderator` flag we defined in the spec.
          final isModerator = payload['is_moderator'] as bool? ?? false;
          if (!isModerator) {
            return Response.forbidden('Access denied. Moderator role required.');
          }
        }
        
        // Add user info to the request context to be used by handlers
        final updatedRequest = request.change(context: {
          'user_id': payload['id'],
          'is_moderator': payload['is_moderator'] ?? false,
        });

        return innerHandler(updatedRequest);
      } on JWTExpiredException {
        return Response.unauthorized('Token expired.');
      } on JWTException catch (err) {
        return Response.unauthorized('Invalid token: ${err.message}');
      } catch (e) {
        return Response.internalServerError(body: 'An unexpected error occurred.');
      }
    };
  };
}