You are an expert backend developer specializing in Dart. Your task is to complete Step 10 of the project plan by implementing a JWT authentication middleware for the Dart Shelf API.

**Step 10: Implement API JWT Authentication Middleware**

**Task:**
Your goal is to create a middleware that protects specific API endpoints. This middleware will inspect incoming requests for a JWT issued by PocketBase, validate it, and either grant access to the protected endpoint or reject the request with an appropriate error code.

**Instructions:**

1.  **Add Dependencies:**
    *   Open the `backend/api/pubspec.yaml` file.
    *   Add the following dependencies to handle JWT validation and HTTP requests for fetching PocketBase's public key:
        ```yaml
        dependencies:
          # ... other dependencies
          dart_jsonwebtoken: ^2.12.0
          http: ^1.1.0 
        ```
    *   Run `dart pub get` inside the `backend/api` directory to install them.

2.  **Create the JWT Validation Service:**
    *   Create a new file at `backend/api/lib/jwt_service.dart`.
    *   This service will be responsible for fetching PocketBase's public signing key and using it to verify tokens.
    *   **Important:** PocketBase uses RS256 asymmetric encryption. You cannot use a simple secret string; you must use its public key for verification.

    ```dart
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
    ```

3.  **Create the Authentication Middleware:**
    *   Create a new file at `backend/api/lib/auth_middleware.dart`.
    *   This file will contain the Shelf middleware logic. It will extract the token from the header, use the `JwtService` to validate it, and pass the request along if valid.

    ```dart
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
    ```

4.  **Apply the Middleware to a New Protected Route:**
    *   Open `backend/api/bin/server.dart` (or your main router file).
    *   Instantiate the `JwtService`.
    *   Create a `Pipeline` that includes the new authentication middleware.
    *   Create a new, protected route (e.g., `/api/protected/ping`) and apply the middleware to it.

    ```dart
    // backend/api/bin/server.dart
    import 'package:shelf/shelf.dart';
    import 'package:shelf/shelf_io.dart' as io;
    import 'package:shelf_router/shelf_router.dart';

    import '../lib/auth_middleware.dart'; // Adjust import path if needed
    import '../lib/jwt_service.dart';   // Adjust import path if needed

    void main() async {
      final app = Router();

      // --- Public route ---
      app.get('/ping', (Request request) {
        return Response.ok('pong');
      });

      // --- Protected route setup ---
      // Use the address of your PocketBase instance.
      // If running in Docker later, this will be 'http://auth:8090'
      final jwtService = JwtService('http://127.0.0.1:8090');
      
      final authMiddleware = createAuthMiddleware(jwtService);

      final protectedRouter = Router();

      protectedRouter.get('/ping', (Request request) {
        // You can access the payload from the context if needed
        final payload = request.context['jwt_payload'] as Map<String, dynamic>;
        final userId = payload['id'];
        return Response.ok('pong from protected route for user: $userId');
      });

      // Create a pipeline and apply the middleware
      final protectedHandler = const Pipeline()
          .addMiddleware(authMiddleware)
          .addHandler(protectedRouter);

      // Mount the protected router under a specific path
      app.mount('/api/protected/', protectedHandler);

      // --- Start the server ---
      final server = await io.serve(app, '0.0.0.0', 8080);
      print('Server listening on port ${server.port}');
    }
    ```

Execute the plan. After the changes are made, you will need to stop and restart the Dart server for them to take effect.