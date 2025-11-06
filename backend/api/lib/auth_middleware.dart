// backend/api/lib/auth_middleware.dart
import 'package:shelf/shelf.dart';
import 'jwt_service.dart';

Middleware createAuthMiddleware(JwtService jwtService) {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'];
      
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized('Missing or invalid Authorization header.');
      }

      final token = authHeader.substring(7); // Remove "Bearer "
      final jwt = await jwtService.verifyToken(token);

      if (jwt == null) {
        return Response.unauthorized('Invalid or expired token.');
      }

      // Optional: Add the decoded payload to the request context
      // so downstream handlers can access user info.
      final updatedRequest = request.change(context: {
        ...request.context,
        'jwt_payload': jwt.payload,
      });

      return innerHandler(updatedRequest);
    };
  };
}