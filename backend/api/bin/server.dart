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
