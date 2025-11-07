import 'package:shelf/shelf_io.dart' as io;

import '../lib/api_router.dart';
import '../lib/database.dart';
import '../lib/moderation_service.dart';
import '../lib/services/contribution_service.dart';

void main() async {
  // 1. Initialize Database
  final dbService = DatabaseService();
  await dbService.start();

  // 2. Initialize Services
  final contributionService = ContributionService(dbService.pool);
  final moderationService = ModerationService(dbService.pool);

  // 3. Initialize Router
  final apiRouter = ApiRouter(moderationService, contributionService);

  // 4. Start the server
  final handler = apiRouter.handler;
  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Server listening on port ${server.port}');
}