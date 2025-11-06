import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import '../lib/auth_middleware.dart'; // Adjust import path if needed
import '../lib/jwt_service.dart'; // Adjust import path if needed
import '../lib/database.dart';
import '../lib/models/conversion_model.dart';
import '../lib/services/contribution_service.dart';

void main() async {
  // 1. Initialize Database
  final dbService = DatabaseService();
  await dbService.start();

  // 2. Initialize Services
  final contributionService = ContributionService(dbService.pool);
  final jwtService = JwtService('http://127.0.0.1:8090');

  final app = Router();

  // --- Public route ---
  app.get('/ping', (Request request) {
    return Response.ok('pong');
  });

  // --- New Contribution Endpoint ---
  app.post('/api/conversions', (Request request) async {
    try {
      final bodyString = await request.readAsString();
      final json = jsonDecode(bodyString) as Map<String, dynamic>;
      final contribution = Contribution.fromJson(json);

      await contributionService.createConversion(contribution);

      return Response(
        201, // Created
        body: jsonEncode({'status': 'success', 'message': 'Contribution received.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on FormatException catch (e) {
      return Response.badRequest(body: e.message);
    } catch (e) {
      print('Error processing contribution: $e');
      return Response.internalServerError(body: 'An unexpected error occurred.');
    }
  });

  // --- Protected route setup ---
  // Use the address of your PocketBase instance.
  // If running in Docker later, this will be 'http://auth:8090'

  final authMiddleware = createAuthMiddleware(jwtService);

  final protectedRouter = Router();

  protectedRouter.get('/ping', (Request request) {
    // You can access the payload from the context if needed
    final payload = request.context['jwt_payload'] as Map<String, dynamic>;
    final userId = payload['id'];
    return Response.ok('pong from protected route for user: $userId');
  });

  // Create a pipeline and apply the middleware
  final protectedHandler = const Pipeline().addMiddleware(authMiddleware).addHandler(protectedRouter);

  // Mount the protected router under a specific path
  app.mount('/api/protected/', protectedHandler);

  // --- Start the server ---
  final server = await io.serve(app, '0.0.0.0', 8080);
  print('Server listening on port ${server.port}');
}
